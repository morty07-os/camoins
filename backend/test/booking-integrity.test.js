const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const path = require('node:path');

// All regression data lives in memory, never in the application's database.
process.env.DB_PATH = ':memory:';
const db = require('../database');
const { TripModel, TransportRequestModel } = require('../models');
const port = 5204;
let server;
let output = '';

async function api(method, route, token, body) {
  const response = await fetch(`http://127.0.0.1:${port}/api${route}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(5000),
  });
  return { status: response.status, data: await response.json() };
}

async function run() {
  // The transaction itself must reject stale/invalid inputs, even if a caller
  // forgets a route-level check or legacy rows contain invalid volume.
  db.exec(`INSERT INTO users (id,email,password_hash,role) VALUES
    (1,'driver','unused','DRIVER'), (2,'customer','unused','CUSTOMER');
    INSERT INTO trucks (id,driver_id,truck_type,max_weight) VALUES (1,1,'VAN',100);
    INSERT INTO trips (id,driver_id,truck_id,origin_name,destination_name,departure_date,
      available_weight,available_volume,trip_type) VALUES (1,1,1,'A','B','2030-01-01',100,20,'RETURN');`);
  const id = TransportRequestModel.create(2, 1, { requested_weight: 10, requested_volume: 5 });
  for (const status of ['CANCELLED', 'COMPLETED', 'IN_PROGRESS']) {
    TripModel.updateStatus(1, status);
    assert.throws(() => TransportRequestModel.acceptWithCapacityUpdate(id, 1), /published trips/);
    assert.equal(TransportRequestModel.findById(id).status, 'PENDING');
    assert.equal(TripModel.findById(1).available_weight, 100);
  }
  TripModel.updateStatus(1, 'PUBLISHED');
  db.prepare('UPDATE transport_requests SET requested_volume = -5 WHERE id = ?').run(id);
  assert.throws(() => TransportRequestModel.acceptWithCapacityUpdate(id, 1), /positive finite/);
  assert.equal(TripModel.findById(1).available_volume, 20);
  db.prepare('UPDATE transport_requests SET requested_volume = 5 WHERE id = ?').run(id);
  TransportRequestModel.acceptWithCapacityUpdate(id, 1);
  assert.throws(() => TransportRequestModel.acceptWithCapacityUpdate(id, 1), /pending requests/);
  assert.equal(TripModel.findById(1).available_weight, 90);
  // Force a failure halfway through finishing; both records must roll back.
  db.exec(`CREATE TRIGGER fail_finish BEFORE UPDATE OF status ON trips
    WHEN NEW.status = 'CANCELLED' BEGIN SELECT RAISE(ABORT, 'forced failure'); END;`);
  assert.throws(() => TripModel.finishWithRequests(1, 'CANCELLED'), /forced failure/);
  assert.equal(TransportRequestModel.findById(id).status, 'ACCEPTED');
  assert.equal(TripModel.findById(1).status, 'PUBLISHED');
  db.exec('DROP TRIGGER fail_finish');
  console.log('PASS transaction guards, capacity integrity, and rollback');

  server = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(port), DB_PATH: ':memory:', JWT_SECRET: 'booking-regression-test' },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  server.stdout.on('data', data => { output += data; });
  server.stderr.on('data', data => { output += data; });
  let ready = false;
  for (let i = 0; i < 50; i++) {
    if (server.exitCode !== null) throw new Error(output);
    try { ready = (await api('GET', '/health')).status === 200; } catch (_) {}
    if (ready) break;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  assert.ok(ready, `Server did not start: ${output}`);
  async function register(role) {
    const result = await api('POST', '/auth/register', null, {
      email: `${role.toLowerCase()}@test.example`, password: 'password123',
      full_name: role, phone: '0555123456', role,
    });
    assert.equal(result.status, 201);
    return result.data.token;
  }
  const driver = await register('DRIVER');
  const customer = await register('CUSTOMER');
  const truck = await api('POST', '/trucks', driver, { truck_type: 'VAN', max_weight: 100, max_volume: 20 });
  assert.equal(truck.status, 201);
  const truckId = truck.data.truck.id;
  async function trip() {
    const result = await api('POST', '/trips', driver, {
      truck_id: truckId, origin_name: 'Alger', destination_name: 'Oran',
      departure_date: '2030-01-01', available_weight: 100, available_volume: 20,
    });
    assert.equal(result.status, 201);
    return result.data.trip.id;
  }
  async function request(tripId) {
    const result = await api('POST', '/requests', customer, {
      trip_id: tripId, requested_weight: 10, requested_volume: 5,
    });
    assert.equal(result.status, 201);
    return result.data.request.id;
  }
  async function requestStatus(requestId) {
    return (await api('GET', `/requests/${requestId}`, customer)).data.request.status;
  }

  const cancelledTrip = await trip();
  for (const field of ['requested_weight', 'requested_volume']) {
    for (const value of [-5, 0, '5junk', 'Infinity', true, {}, '']) {
      const result = await api('POST', '/requests', customer, {
        trip_id: cancelledTrip, requested_weight: 10, [field]: value,
      });
      assert.equal(result.status, 400, `${field} must reject ${JSON.stringify(value)}`);
    }
  }
  const pending = await request(cancelledTrip);
  const accepted = await request(cancelledTrip);
  const acceptance = await api('POST', `/requests/${accepted}/accept`, driver);
  assert.equal(acceptance.status, 200);
  const conversationId = acceptance.data.conversation.id;
  assert.equal((await api('POST', `/conversations/${conversationId}/messages`, customer, { message: 'Keep this history' })).status, 201);
  assert.equal((await api('POST', `/trips/${cancelledTrip}/cancel`, driver)).status, 200);
  assert.equal(await requestStatus(pending), 'CANCELLED');
  assert.equal(await requestStatus(accepted), 'CANCELLED');
  assert.equal((await api('POST', `/requests/${pending}/accept`, driver)).status, 400);
  assert.equal((await api('DELETE', `/trips/${cancelledTrip}`, driver)).status, 409);
  assert.equal((await api('DELETE', `/trucks/${truckId}`, driver)).status, 409);
  const messages = await api('GET', `/conversations/${conversationId}/messages`, customer);
  assert.equal(messages.status, 200);
  assert.equal(messages.data.messages.length, 1);
  console.log('PASS invalid inputs, cancellation, and preserved booking/chat history');

  const completedTrip = await trip();
  const completedRequest = await request(completedTrip);
  const unanswered = await request(completedTrip);
  assert.equal((await api('POST', `/requests/${completedRequest}/accept`, driver)).status, 200);
  assert.equal((await api('POST', `/trips/${completedTrip}/start`, driver)).status, 200);
  assert.equal((await api('POST', `/requests/${unanswered}/accept`, driver)).status, 409);
  assert.equal((await api('POST', `/trips/${completedTrip}/complete`, driver)).status, 200);
  assert.equal(await requestStatus(completedRequest), 'COMPLETED');
  assert.equal(await requestStatus(unanswered), 'CANCELLED');
  assert.equal((await api('POST', `/requests/${completedRequest}/cancel`, customer)).status, 400);
  assert.equal((await api('DELETE', `/trips/${completedTrip}`, driver)).status, 409);
  const emptyTrip = await trip();
  assert.equal((await api('DELETE', `/trips/${emptyTrip}`, driver)).status, 200);
  console.log('PASS completion synchronizes requests and empty trips remain deletable');
}

run().catch(error => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  db.close();
  if (server && server.exitCode === null) {
    const exited = once(server, 'exit');
    server.kill();
    await exited;
  }
});
