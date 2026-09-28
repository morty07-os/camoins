const db = require('./database');

const COMMISSION_RATE_BPS = 900;

function calculateSplit(amountMinor) {
  if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) {
    const error = new Error('The agreed price must be a positive amount in DZD minor units');
    error.status = 400;
    throw error;
  }
  // Integer half-up rounding. The two resulting amounts always add to gross.
  const platformFeeMinor = Math.floor((amountMinor * COMMISSION_RATE_BPS + 5000) / 10000);
  return {
    amountMinor,
    platformFeeMinor,
    driverNetMinor: amountMinor - platformFeeMinor,
  };
}

function findById(id) {
  return db.prepare('SELECT * FROM payments WHERE id = ?').get(id);
}

function findByRequestId(requestId) {
  return db.prepare('SELECT * FROM payments WHERE request_id = ?').get(requestId);
}

function createForAcceptedRequest(requestId, amountMinor) {
  const split = calculateSplit(amountMinor);
  const result = db.prepare(`
    INSERT INTO payments
      (request_id, amount_minor, platform_fee_minor, driver_net_minor)
    VALUES (?, ?, ?, ?)
  `).run(requestId, split.amountMinor, split.platformFeeMinor, split.driverNetMinor);
  return findById(result.lastInsertRowid);
}

function markCashReceived(paymentId, driverId) {
  return db.transaction(() => {
    const payment = db.prepare(`
      SELECT p.*, t.driver_id, r.status AS request_status
      FROM payments p
      JOIN transport_requests r ON r.id = p.request_id
      JOIN trips t ON t.id = r.trip_id
      WHERE p.id = ?
    `).get(paymentId);
    if (!payment) throw Object.assign(new Error('Payment not found'), { status: 404 });
    if (payment.driver_id !== driverId) throw Object.assign(new Error('Access denied'), { status: 403 });
    if (payment.status === 'PAID') return findById(paymentId);
    if (payment.request_status !== 'AWAITING_CUSTOMER_CONFIRMATION') {
      throw Object.assign(new Error('Cash is recorded after the driver finishes the delivery'), { status: 409 });
    }
    if (payment.status !== 'PENDING_COLLECTION') {
      throw Object.assign(new Error('Cash cannot be collected in the current payment state'), { status: 409 });
    }
    db.prepare(`
      UPDATE payments SET status = 'PAID', cash_received_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP WHERE id = ?
    `).run(paymentId);
    return findById(paymentId);
  }).immediate();
}

function cancelForRequest(requestId) {
  db.prepare(`
    UPDATE payments SET status = 'CANCELLED', commission_status = 'CANCELLED',
      updated_at = CURRENT_TIMESTAMP
    WHERE request_id = ? AND status = 'PENDING_COLLECTION'
  `).run(requestId);
}

function listAcceptedRides() {
  return db.prepare(`
    SELECT r.id AS request_id, r.status AS request_status, r.agreed_amount_minor,
           r.currency, r.created_at AS request_created_at,
           t.id AS trip_id, t.origin_name, t.destination_name, t.departure_date,
           t.status AS trip_status, t.driver_id, r.customer_id,
           dp.full_name AS driver_name, cp.full_name AS customer_name,
           p.id AS payment_id, p.method AS payment_method, p.status AS payment_status,
           p.amount_minor, p.platform_fee_minor, p.driver_net_minor,
           p.commission_rate_bps, p.commission_status, p.cash_received_at,
           p.commission_collected_at
    FROM transport_requests r
    JOIN trips t ON t.id = r.trip_id
    JOIN profiles dp ON dp.user_id = t.driver_id
    JOIN profiles cp ON cp.user_id = r.customer_id
    LEFT JOIN payments p ON p.request_id = r.id
    WHERE r.status IN ('ACCEPTED', 'AWAITING_CUSTOMER_CONFIRMATION', 'COMPLETED')
    ORDER BY r.created_at DESC, r.id DESC
  `).all();
}

function getAdminSummary() {
  return db.prepare(`
    SELECT COUNT(*) AS accepted_rides,
      COALESCE(SUM(amount_minor), 0) AS gross_minor,
      COALESCE(SUM(platform_fee_minor), 0) AS total_commission_minor,
      COALESCE(SUM(CASE WHEN commission_status = 'COLLECTED' THEN platform_fee_minor ELSE 0 END), 0)
        AS collected_commission_minor,
      COALESCE(SUM(CASE WHEN commission_status = 'DUE' AND status = 'PAID' THEN platform_fee_minor ELSE 0 END), 0)
        AS due_commission_minor
    FROM payments
    WHERE status != 'CANCELLED'
  `).get();
}

function collectCommission(paymentId, adminId, reason) {
  if (!reason || !String(reason).trim()) {
    throw Object.assign(new Error('A reason or collection reference is required'), { status: 400 });
  }
  return db.transaction(() => {
    const payment = findById(paymentId);
    if (!payment) throw Object.assign(new Error('Payment not found'), { status: 404 });
    if (payment.status !== 'PAID') {
      throw Object.assign(new Error('Commission can only be collected after cash payment'), { status: 409 });
    }
    if (payment.commission_status === 'COLLECTED') return payment;
    if (payment.commission_status !== 'DUE') {
      throw Object.assign(new Error('Commission is not due'), { status: 409 });
    }
    db.prepare(`
      UPDATE payments SET commission_status = 'COLLECTED',
        commission_collected_at = CURRENT_TIMESTAMP, commission_collected_by = ?,
        updated_at = CURRENT_TIMESTAMP WHERE id = ?
    `).run(adminId, paymentId);
    db.prepare(`
      INSERT INTO admin_audit_logs
        (admin_id, action, target_type, target_id, reason, metadata_json)
      VALUES (?, 'COMMISSION_COLLECTED', 'PAYMENT', ?, ?, ?)
    `).run(adminId, paymentId, String(reason).trim(), JSON.stringify({
      amount_minor: payment.platform_fee_minor,
      currency: payment.currency,
    }));
    return findById(paymentId);
  }).immediate();
}

module.exports = {
  COMMISSION_RATE_BPS,
  calculateSplit,
  findById,
  findByRequestId,
  createForAcceptedRequest,
  markCashReceived,
  cancelForRequest,
  listAcceptedRides,
  getAdminSummary,
  collectCommission,
};
