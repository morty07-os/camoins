const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'camoins-payments-'));
process.env.DB_PATH = path.join(directory, 'payments.db');

const db = require('../database');
const Payments = require('../payments');
const { TransportRequestModel } = require('../models');

try {
  db.exec(`
    INSERT INTO users (id,email,password_hash,role) VALUES
      (1,'driver@test.local','x','DRIVER'),
      (2,'customer@test.local','x','CUSTOMER'),
      (3,'admin@test.local','x','ADMIN'),
      (4,'other-driver@test.local','x','DRIVER');
    INSERT INTO profiles (user_id,full_name) VALUES
      (1,'Driver'),(2,'Customer'),(3,'Admin'),(4,'Other Driver');
    INSERT INTO trucks (id,driver_id,truck_type,max_weight) VALUES (1,1,'VAN',1000);
    INSERT INTO trips
      (id,driver_id,truck_id,origin_name,destination_name,departure_date,
       available_weight,trip_type,status)
      VALUES (1,1,1,'Alger','Oran','2026-10-01',1000,'RETURN','PUBLISHED');
    INSERT INTO transport_requests
      (id,trip_id,customer_id,requested_weight,agreed_price,status)
      VALUES (1,1,2,100,'Prix à convenir','PENDING');
  `);

  assert.deepEqual(Payments.calculateSplit(10000), {
    amountMinor: 10000,
    platformFeeMinor: 900,
    driverNetMinor: 9100,
  });
  assert.throws(() => Payments.calculateSplit(1.5), /positive amount/);

  const proposed = TransportRequestModel.proposePrice(1, 1, 12345);
  assert.equal(proposed.status, 'PRICE_PROPOSED');
  assert.equal(Payments.findByRequestId(1), undefined);
  assert.equal(db.prepare('SELECT available_weight FROM trips WHERE id = 1').get().available_weight, 1000);
  assert.throws(() => TransportRequestModel.confirmProposedPrice(1, 4), /Access denied/);
  const accepted = TransportRequestModel.confirmProposedPrice(1, 2);
  assert.equal(accepted.status, 'ACCEPTED');
  const payment = Payments.findByRequestId(1);
  assert.equal(payment.amount_minor, 12345);
  assert.equal(payment.platform_fee_minor, 1111);
  assert.equal(payment.driver_net_minor, 11234);
  assert.equal(payment.status, 'PENDING_COLLECTION');
  assert.equal(payment.commission_status, 'DUE');
  assert.equal(payment.platform_fee_minor + payment.driver_net_minor, payment.amount_minor);
  assert.throws(() => Payments.markCashReceived(payment.id, 4), /Access denied/);
  assert.throws(() => Payments.markCashReceived(payment.id, 1), /after the driver finishes/);

  db.prepare("UPDATE transport_requests SET status = 'AWAITING_CUSTOMER_CONFIRMATION' WHERE id = 1").run();
  const paid = Payments.markCashReceived(payment.id, 1);
  assert.equal(paid.status, 'PAID');
  assert.ok(paid.cash_received_at);
  assert.equal(Payments.getAdminSummary().due_commission_minor, 1111);

  assert.throws(() => Payments.collectCommission(payment.id, 3, ''), /reason/);
  const collected = Payments.collectCommission(payment.id, 3, 'Driver cash settlement');
  assert.equal(collected.commission_status, 'COLLECTED');
  assert.equal(Payments.getAdminSummary().collected_commission_minor, 1111);
  assert.equal(db.prepare('SELECT COUNT(*) count FROM admin_audit_logs').get().count, 1);
  assert.equal(Payments.listAcceptedRides()[0].driver_name, 'Driver');

  console.log('PASS cash payment, 9% split, driver ownership, admin collection, and audit log');
} finally {
  db.close();
  fs.rmSync(directory, { recursive: true, force: true });
}
