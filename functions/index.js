const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

/**
 * Convierte recursivamente cualquier Timestamp de Firestore encontrado
 * (en cualquier nivel de anidamiento) a milisegundos -- las funciones
 * `asTimestamp`/`asProximoPagoFecha`/`asTimestampFlexible` del lado
 * Flutter (core/utils/firestore_parse.dart) YA aceptan un int de
 * milisegundos ademas de un Timestamp real, asi que este es el unico
 * cambio de formato que hace falta para que `PrestamoModel.fromMap`/
 * `PagoModel.fromMap` (lib/core/models) puedan leer esta respuesta sin
 * ningun parseo especial nuevo del lado Dart.
 */
function serializar(valor) {
  if (valor === null || valor === undefined) return valor;
  if (typeof valor.toMillis === "function") return valor.toMillis();
  if (Array.isArray(valor)) return valor.map(serializar);
  if (typeof valor === "object") {
    const out = {};
    for (const k of Object.keys(valor)) out[k] = serializar(valor[k]);
    return out;
  }
  return valor;
}

function docAJson(doc) {
  return { id: doc.id, ...serializar(doc.data()) };
}

/** Igual que PrestamoRepository.obtenerTodos en Dart. */
async function obtenerTodosPrestamos(db, cobradorUid) {
  let query = db.collection("prestamos").where("eliminado", "==", false);
  if (cobradorUid) query = query.where("cobradoresAsignados", "array-contains", cobradorUid);
  const snap = await query.get();
  return snap.docs.map(docAJson);
}

/** Igual que PrestamoRepository.obtenerParaNotificaciones en Dart. */
async function obtenerParaNotificaciones(db, cobradorUid) {
  if (!cobradorUid) return obtenerTodosPrestamos(db, null);

  const porPrestamo = await obtenerTodosPrestamos(db, cobradorUid);

  const clientesSnap = await db
    .collection("clientes")
    .where("cobradoresAsignados", "array-contains", cobradorUid)
    .get();
  const clienteIds = clientesSnap.docs.map((d) => d.id);

  const lotes = [];
  for (let i = 0; i < clienteIds.length; i += 10) lotes.push(clienteIds.slice(i, i + 10));

  const snaps = await Promise.all(lotes.map((lote) =>
    db.collection("prestamos").where("clienteId", "in", lote).where("eliminado", "==", false).get()
  ));
  const porCliente = [];
  for (const snap of snaps) {
    for (const doc of snap.docs) porCliente.push(docAJson(doc));
  }

  const combinados = new Map();
  for (const p of porPrestamo) combinados.set(p.id, p);
  for (const p of porCliente) combinados.set(p.id, p);
  return [...combinados.values()];
}

/** Igual que PagoRepository.obtenerPorPrestamos en Dart. */
async function obtenerPagosPorPrestamos(db, prestamoIds) {
  if (prestamoIds.length === 0) return [];
  const lotes = [];
  for (let i = 0; i < prestamoIds.length; i += 10) lotes.push(prestamoIds.slice(i, i + 10));
  const snaps = await Promise.all(lotes.map((lote) =>
    db.collection("pagos").where("prestamoId", "in", lote).get()
  ));
  const pagos = [];
  for (const snap of snaps) {
    for (const doc of snap.docs) pagos.push(docAJson(doc));
  }
  return pagos;
}

// Mismo set que _estadosExcluidos en cobros_screen.dart.
const ESTADOS_EXCLUIDOS_COBROS = new Set([
  "saldado", "completado", "cancelado", "eliminado", "rechazado", "pendiente",
]);

/**
 * Agrupa, DENTRO del centro de datos de Google, las mismas consultas
 * que hoy hace cobros_screen.dart en varios viajes seguidos desde el
 * celular (prestamos + pagos por lotes) -- el calculo real (fechas,
 * mora, clasificacion vencido/hoy/proximo) se sigue haciendo en Dart,
 * esto SOLO agrupa las lecturas para que el celular pague un solo
 * viaje largo en vez de varios. Ver el mismo filtro de candidatos
 * (`_estadosExcluidos`) que ya usa cobros_screen.dart, replicado aca
 * para no bajar pagos de prestamos que la pantalla igual va a
 * descartar.
 */
// Mismo criterio que Roles.esAdminOEquivalente en lib/core/constants/roles.dart.
const ROLES_ADMIN = new Set(["admin", "desarrollador"]);

exports.obtenerDatosCobros = onCall(async (request) => {
  // Esta app no usa Firebase Auth (login propio por codigo+password
  // contra la coleccion `usuarios`, ver AuthRepository), asi que
  // `request.auth` nunca existe -- NO se puede confiar en un
  // `cobradorUid`/"soy admin" que mande el celular sin mas: cualquiera
  // podia mandar `cobradorUid: null` y llevarse los prestamos y pagos
  // de TODOS los clientes. En cambio, se pide el uid de QUIEN llama y
  // se verifica su rol REAL contra Firestore -- mismo nivel de
  // confianza que ya usa el resto de la app (todo pasa por lo que dice
  // el doc de `usuarios`, no hay tokens firmados), pero ya no le cree
  // ciegamente al cliente si dice ser admin.
  const usuarioUid = request.data && request.data.usuarioUid;
  if (!usuarioUid) {
    throw new HttpsError("invalid-argument", "Falta usuarioUid.");
  }

  const db = getFirestore();
  const usuarioDoc = await db.collection("usuarios").doc(usuarioUid).get();
  const usuario = usuarioDoc.data();
  // Mismo default que UsuarioModel.fromDoc en Dart (data['estado'] ??
  // 'activo'): varios usuarios reales (ej. el cobrador que mas usa la
  // app hoy) nunca tienen este campo guardado -- si aca se exige
  // "activo" a secas, se le niega el acceso a gente que la app SI deja
  // entrar.
  if (!usuario || (usuario.estado !== undefined && usuario.estado !== "activo")) {
    throw new HttpsError("permission-denied", "Usuario inválido o inactivo.");
  }

  const cobradorUid = ROLES_ADMIN.has(usuario.rol) ? null : usuarioUid;

  const todos = await obtenerParaNotificaciones(db, cobradorUid);
  const candidatos = todos.filter((p) => !ESTADOS_EXCLUIDOS_COBROS.has(String(p.estado || "").toLowerCase()));
  const pagos = await obtenerPagosPorPrestamos(db, candidatos.map((p) => p.id));

  return { prestamos: candidatos, pagos };
});
