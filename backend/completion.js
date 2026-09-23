const db = require('./database');
const { ConversationModel, MessageModel, NotificationModel } = require('./models');

function fail(status, message) { throw Object.assign(new Error(message), { status }); }

function transition(request, driverId, confirm) {
  const conversation = ConversationModel.findOrCreateByRequestId(request.id);
  const status = confirm ? 'COMPLETED' : 'AWAITING_CUSTOMER_CONFIRMATION';
  const timestamp = confirm ? 'customer_confirmed_at' : 'driver_finished_at';
  db.prepare(`UPDATE transport_requests SET status = ?, ${timestamp} = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP WHERE id = ?`).run(status, request.id);
  const body = confirm
    ? 'Le client a confirmé la réception. Le transport est terminé.'
    : 'Le chauffeur a terminé le trajet. Veuillez confirmer la réception de votre marchandise.';
  const senderId = confirm ? request.customer_id : driverId;
  const messageId = db.prepare(`INSERT INTO messages (conversation_id, sender_id, message, is_system)
    VALUES (?, ?, ?, 1)`).run(conversation.id, senderId, body).lastInsertRowid;
  const notificationId = NotificationModel.create(confirm ? driverId : request.customer_id, {
    title: confirm ? 'Réception confirmée' : 'Confirmation de réception', body,
    type: confirm ? 'delivery_confirmed' : 'delivery_confirmation_requested',
    related_id: request.id, request_id: request.id, trip_id: request.trip_id,
    conversation_id: conversation.id,
  });
  return { message: MessageModel.findById(messageId), notification: NotificationModel.findById(notificationId) };
}

// BEGIN IMMEDIATE serializes competing writers. Retries see the persisted status
// and return successfully without writing a second message or notification.
function finishTrip(tripId, user) {
  return db.transaction(() => {
    const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(tripId);
    if (!trip) fail(404, 'Trajet introuvable');
    if (user.role !== 'DRIVER' || trip.driver_id !== user.id) fail(403, 'Accès interdit');
    if (trip.status === 'COMPLETED') return [];
    if (trip.status !== 'IN_PROGRESS') fail(400, 'Le trajet doit être en cours');
    const requests = db.prepare("SELECT * FROM transport_requests WHERE trip_id = ? AND status = 'ACCEPTED'").all(tripId);
    const events = requests.map(request => transition(request, user.id, false));
    db.prepare("UPDATE trips SET status = 'COMPLETED', updated_at = CURRENT_TIMESTAMP WHERE id = ?").run(tripId);
    // Preserve the existing closure of unanswered bookings; never confirm them.
    for (const request of db.prepare("SELECT * FROM transport_requests WHERE trip_id = ? AND status = 'PENDING'").all(tripId)) {
      const id = NotificationModel.create(request.customer_id, {
        title: 'Demande annulée', body: 'Le trajet est terminé sans acceptation de votre demande.',
        type: 'request_cancelled', related_id: request.id, request_id: request.id, trip_id: tripId,
      });
      events.push({ notification: NotificationModel.findById(id) });
    }
    db.prepare("UPDATE transport_requests SET status = 'CANCELLED', updated_at = CURRENT_TIMESTAMP WHERE trip_id = ? AND status = 'PENDING'").run(tripId);
    return events;
  }).immediate();
}

function finishRequest(requestId, user, confirm = false) {
  return db.transaction(() => {
    const request = db.prepare('SELECT * FROM transport_requests WHERE id = ?').get(requestId);
    if (!request) fail(404, 'Demande introuvable');
    const trip = db.prepare('SELECT * FROM trips WHERE id = ?').get(request.trip_id);
    if (confirm ? user.role !== 'CUSTOMER' || request.customer_id !== user.id
      : user.role !== 'DRIVER' || trip.driver_id !== user.id) fail(403, 'Accès interdit');
    if (request.status === 'COMPLETED' || (!confirm && request.status === 'AWAITING_CUSTOMER_CONFIRMATION')) return [];
    if (request.status !== (confirm ? 'AWAITING_CUSTOMER_CONFIRMATION' : 'ACCEPTED') ||
        (!confirm && trip.status === 'CANCELLED')) {
      fail(409, 'Cette demande ne peut pas être finalisée dans son état actuel');
    }
    return [transition(request, trip.driver_id, confirm)];
  }).immediate();
}

module.exports = { finishTrip, finishRequest };
