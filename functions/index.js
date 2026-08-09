const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const TIPO_TEXTO = {
  problema: "Problema",
  nuevo: "Algo nuevo",
};

/**
 * Avisa por notificacion push a todos los tokens registrados en
 * `fcmTokens` (solo se guardan ahi tokens de usuarios admin, ver
 * lib/core/services/push_notifications_service.dart) cada vez que se
 * crea un ticket nuevo en la coleccion `tickets`.
 */
exports.avisarTicketNuevo = onDocumentCreated("tickets/{ticketId}", async (event) => {
  const ticket = event.data?.data();
  if (!ticket) return;

  const db = getFirestore();
  const tokensSnap = await db.collection("fcmTokens").get();
  const tokens = tokensSnap.docs.map((doc) => doc.id).filter(Boolean);
  if (tokens.length === 0) return;

  const tipoTexto = TIPO_TEXTO[ticket.tipo] || "Ticket";
  const mensaje = {
    notification: {
      title: `${tipoTexto}: ${ticket.titulo || "Nuevo ticket"}`,
      body: `${ticket.creadoPorNombre || "Alguien"} - ${(ticket.descripcion || "").slice(0, 120)}`,
    },
    data: {
      tipo: "ticket_nuevo",
      ticketId: event.params.ticketId,
    },
    tokens,
  };

  const respuesta = await getMessaging().sendEachForMulticast(mensaje);

  // Limpia tokens invalidos/expirados (dispositivo desinstalo la app,
  // token vencido, etc.) para no seguir intentando mandarles push.
  const tokensAEliminar = [];
  respuesta.responses.forEach((r, i) => {
    if (!r.success && (r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token")) {
      tokensAEliminar.push(tokens[i]);
    }
  });
  await Promise.all(tokensAEliminar.map((t) => db.collection("fcmTokens").doc(t).delete()));
});
