const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const nodemailer = require("nodemailer");

initializeApp();

const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");
const CORREO_ENVIA = "henryviera2003@gmail.com";
const CORREO_RECIBE = "qualitysports730@gmail.com";

const TIPO_TICKET_TEXTO = {
  problema: "Problema",
  nuevo: "Algo nuevo",
};

/**
 * Manda un push a todos los tokens en `fcmTokens` cuyo campo `tipos`
 * (array) contenga `tipoAviso` -- ver
 * lib/core/services/push_notifications_service.dart, que es quien
 * decide que tipos le corresponden a cada dispositivo segun el rol
 * (desarrollador: tickets+solicitudes; admin: solo solicitudes, y
 * solo en Android). Limpia tokens invalidos/expirados de paso.
 */
async function avisarATokens(tipoAviso, mensajeSinTokens) {
  const db = getFirestore();
  const tokensSnap = await db.collection("fcmTokens").where("tipos", "array-contains", tipoAviso).get();
  const tokens = tokensSnap.docs.map((doc) => doc.id).filter(Boolean);
  if (tokens.length === 0) return;

  const respuesta = await getMessaging().sendEachForMulticast({ ...mensajeSinTokens, tokens });

  const tokensAEliminar = [];
  respuesta.responses.forEach((r, i) => {
    if (!r.success && (r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token")) {
      tokensAEliminar.push(tokens[i]);
    }
  });
  await Promise.all(tokensAEliminar.map((t) => db.collection("fcmTokens").doc(t).delete()));
}

/**
 * Respaldo por correo para tickets nuevos -- el push en Web movil
 * (iOS Safari sobre todo) es el canal menos confiable de los tres
 * (Android/Web escritorio/Web movil), asi que ademas del push se
 * manda SIEMPRE un correo, para no depender de un solo canal. Un
 * fallo mandando el correo no debe tumbar el resto de la funcion (el
 * push ya se mando aparte).
 */
async function mandarCorreoTicket(ticket, ticketId) {
  try {
    const transportador = nodemailer.createTransport({
      service: "gmail",
      auth: { user: CORREO_ENVIA, pass: GMAIL_APP_PASSWORD.value() },
    });
    const tipoTexto = TIPO_TICKET_TEXTO[ticket.tipo] || "Ticket";
    await transportador.sendMail({
      from: `SIEG S. de R.L. de C.V. <${CORREO_ENVIA}>`,
      to: CORREO_RECIBE,
      subject: `[SIEG] ${tipoTexto}: ${ticket.titulo || "Nuevo ticket"}`,
      text: `${ticket.creadoPorNombre || "Alguien"} (${ticket.creadoPorRol || ""}) reportó:\n\n` +
        `${ticket.descripcion || ""}\n\n` +
        `Ticket ID: ${ticketId}`,
    });
  } catch (e) {
    console.error("No se pudo mandar el correo de respaldo del ticket:", e);
  }
}

/** Ticket nuevo (problema o pedido) -- ver features/tickets. */
exports.avisarTicketNuevo = onDocumentCreated(
  { document: "tickets/{ticketId}", secrets: [GMAIL_APP_PASSWORD] },
  async (event) => {
    const ticket = event.data?.data();
    if (!ticket) return;

    const tipoTexto = TIPO_TICKET_TEXTO[ticket.tipo] || "Ticket";
    await Promise.all([
      avisarATokens("tickets", {
        notification: {
          title: `${tipoTexto}: ${ticket.titulo || "Nuevo ticket"}`,
          body: `${ticket.creadoPorNombre || "Alguien"} - ${(ticket.descripcion || "").slice(0, 120)}`,
        },
        data: { tipo: "ticket_nuevo", ticketId: event.params.ticketId },
      }),
      mandarCorreoTicket(ticket, event.params.ticketId),
    ]);
  }
);

/** Solicitud de prestamo nueva (necesita aprobacion de un admin). */
exports.avisarSolicitudNueva = onDocumentCreated("solicitudes_prestamo/{solicitudId}", async (event) => {
  const solicitud = event.data?.data();
  if (!solicitud) return;

  await avisarATokens("solicitudes", {
    notification: {
      title: "Nueva solicitud de préstamo",
      body: `${solicitud.cliente || "Cliente"} - L.${solicitud.monto || 0} (${solicitud.cobrador || "cobrador"})`,
    },
    data: { tipo: "solicitud_nueva", solicitudId: event.params.solicitudId },
  });
});

/**
 * Manda un push a los dispositivos de los `usuarioUid` dados (a
 * diferencia de avisarATokens, que es broadcast por `tipos`) -- ver
 * lib/core/services/push_notifications_service.dart, que guarda
 * `usuarioUid` en cada doc de `fcmTokens` desde que TODOS los roles
 * (incluido cobrador) registran token para 'permisos_edicion'.
 * `whereIn` soporta hasta 10 valores, mas que suficiente aca (siempre
 * son 2: el solicitante y quien aprobo).
 */
async function avisarAUsuarios(uids, mensajeSinTokens) {
  const uidsValidos = [...new Set(uids.filter(Boolean))];
  if (uidsValidos.length === 0) return;

  const db = getFirestore();
  const tokensSnap = await db.collection("fcmTokens").where("usuarioUid", "in", uidsValidos).get();
  const tokens = tokensSnap.docs.map((doc) => doc.id).filter(Boolean);
  if (tokens.length === 0) return;

  const respuesta = await getMessaging().sendEachForMulticast({ ...mensajeSinTokens, tokens });

  const tokensAEliminar = [];
  respuesta.responses.forEach((r, i) => {
    if (!r.success && (r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token")) {
      tokensAEliminar.push(tokens[i]);
    }
  });
  await Promise.all(tokensAEliminar.map((t) => db.collection("fcmTokens").doc(t).delete()));
}

/**
 * Al aprobar una solicitud de edicion, avisa al cobrador que la mando
 * que ya puede editar (con la hora limite) -- sin esto no tenia forma
 * de enterarse salvo que volviera a intentar entrar o el admin le
 * avisara a mano. Dispara solo en la transicion a 'aprobada' (no en
 * cualquier otro update del doc, como marcarAplicada).
 */
exports.avisarSolicitudEdicionAprobada = onDocumentUpdated("solicitudes_edicion/{solicitudId}", async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (!antes || !despues) return;
  if (antes.estado === despues.estado || despues.estado !== "aprobada") return;

  await avisarAUsuarios([despues.solicitanteUid], {
    notification: {
      title: "Solicitud de edición aprobada",
      body: `Ya podés editar "${despues.entidadNombre || "el registro"}" -- tenés 1 hora.`,
    },
    data: { tipo: "solicitud_edicion_aprobada", solicitudId: event.params.solicitudId },
  });
});

/**
 * Cada 10 minutos, revisa si algun permiso de edicion otorgado
 * (`solicitudes_edicion` con estado 'aprobada') ya paso su hora sin
 * usarse -- si es asi, lo marca 'vencida' y avisa por push al
 * cobrador que lo pidio y al admin que lo aprobo. Ver
 * SolicitudEdicionRepository.aprobar (quien fija fechaExpiraPermiso) y
 * .marcarAplicada (quien deja el doc en 'aplicada' ANTES de que esto
 * lo alcance a marcar 'vencida', si se llega a usar a tiempo).
 */
exports.vencerPermisosEdicion = onSchedule("every 10 minutes", async () => {
  const db = getFirestore();
  const ahora = Timestamp.now();
  const snap = await db
    .collection("solicitudes_edicion")
    .where("estado", "==", "aprobada")
    .where("fechaExpiraPermiso", "<=", ahora)
    .get();
  if (snap.empty) return;

  await Promise.all(snap.docs.map(async (doc) => {
    const s = doc.data();
    await doc.ref.update({ estado: "vencida" });
    await avisarAUsuarios([s.solicitanteUid, s.aprobadaPorUid], {
      notification: {
        title: "Permiso de edición vencido",
        body: `El permiso para editar "${s.entidadNombre || "un registro"}" ya venció sin usarse.`,
      },
      data: { tipo: "permiso_edicion_vencido", solicitudId: doc.id },
    });
  }));
});
