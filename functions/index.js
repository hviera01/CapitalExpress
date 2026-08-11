const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
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
