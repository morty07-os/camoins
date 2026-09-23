const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const path = require('node:path');

// All regression data lives in memory, never in the application's database.
process.env.DB_PATH = ':memory:';
const db = require('../database');
const { TripModel, TransportRequestModel } = require('../models');
const port = 5205;
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
  db.exec(`INSERT INTO users (id,email,password_hash,role) VALUES
    (1,'d','unused','DRIVER'), (2,'c','unused','CUSTOMER'), (3,'x','unused','CUSTOMER');
    INSERT INTO profiles (user_id,full_name) VALUES (1,'Driver'),(2,'Customer');
    INSERT INTO trucks (id,driver_id,truck_type,max_weight) VALUES (1,1,'VAN',100);
    INSERT INTO trips (id,driver_id,truck_id,origin_name,destination_name,departure_date,
      available_weight,trip_type) VALUES (1,1,1,'A','B','2030-01-01',100,'RETURN');`);
  const rid = TransportRequestModel.create(2, 1, { requested_weight: 10 });
  const insert = db.prepare('INSERT INTO ratings (trip_id,request_id,reviewer_id,reviewed_user_id,rating) VALUES (1,?,?,?,?)');
  assert.throws(() => insert.run(rid,2,1,5), /completed transport/);
  db.prepare("UPDATE transport_requests SET status = 'COMPLETED' WHERE id = ?").run(rid);
  assert.throws(() => insert.run(rid,2,2,5), /participants/);
  assert.throws(() => insert.run(rid,3,1,5), /participants/);
  assert.throws(() => insert.run(rid,2,1,3.5), /integer/);
  db.exec(`CREATE TRIGGER fail_rating_summary BEFORE UPDATE OF rating ON profiles
    BEGIN SELECT RAISE(ABORT, 'forced failure'); END;`);
  const { RatingModel } = require('../models');
  assert.throws(() => RatingModel.create({trip_id:1,request_id:rid,reviewer_id:2,reviewed_user_id:1,rating:5}), /forced failure/);
  assert.equal(db.prepare('SELECT COUNT(*) AS count FROM ratings').get().count,0);
  db.exec('DROP TRIGGER fail_rating_summary');
  insert.run(rid,2,1,5);
  assert.throws(() => insert.run(rid,2,1,4), /UNIQUE/);
  assert.throws(() => db.prepare('UPDATE ratings SET rating = 1').run(), /cannot be edited/);
  console.log('PASS database constraints and atomic rating rollback');

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


  const tripId = await trip();
  const requestId = await request(tripId);
  const driverId = (await api('GET', '/auth/me', driver)).data.user.id;
  const customerId = (await api('GET', '/auth/me', customer)).data.user.id;
  const body = { trip_id: tripId, request_id: requestId, reviewed_user_id: driverId, rating: 5 };
  assert.equal((await api('POST', '/ratings', null, body)).status, 401);
  assert.equal((await api('GET', '/trips/history')).status, 401);
  assert.equal((await api('GET', '/users/' + driverId + '/ratings')).status, 401);
  assert.equal((await api('POST', '/ratings', customer, body)).status, 403);
  assert.equal((await api('POST', '/requests/' + requestId + '/accept', driver)).status, 200);
  assert.equal((await api('POST', '/trips/' + tripId + '/start', driver)).status, 200);
  assert.equal((await api('POST', '/ratings', customer, body)).status, 403);
  assert.equal((await api('POST', '/trips/' + tripId + '/complete', driver)).status, 200);
  assert.equal((await api('POST', '/requests/' + requestId + '/confirm', customer)).status, 200);
  const stranger = await api('POST', '/auth/register', null, {
    email: 'stranger@test.example', password: 'password123', full_name: 'Stranger', role: 'CUSTOMER'
  });
  assert.equal((await api('POST', '/ratings', stranger.data.token, body)).status, 403);
  assert.deepEqual((await api('GET', '/trips/history', stranger.data.token)).data.history, []);
  for (const rating of [0, 6, 3.5, '5', '5junk', true, null, {}]) {
    assert.equal((await api('POST', '/ratings', customer, { ...body, rating })).status, 400);
  }
  for (const comment of [{}, 123, 'a'.repeat(501)]) {
    assert.equal((await api('POST', '/ratings', customer, { ...body, comment })).status, 400);
  }
  assert.equal((await api('POST', '/ratings', customer, { ...body, trip_id: await trip() })).status, 400);
  assert.equal((await api('POST', '/ratings', customer, { ...body, reviewed_user_id: customerId })).status, 400);
  assert.equal((await api('POST', '/ratings', customer, { ...body, reviewed_user_id: stranger.data.user.id })).status, 400);
  const results = await Promise.all([1, 2].map(() => api('POST', '/ratings', customer, {
    ...body, reviewer_id: driverId, comment: '  Excellent  '
  })));
  assert.equal(results.filter(r => r.status === 201).length, 1);
  const saved = results.find(r => r.status === 201).data.rating;
  assert.equal(saved.reviewer_id, customerId);
  assert.equal(saved.comment, 'Excellent');
  assert.equal((await api('POST', '/ratings', driver, { ...body, reviewed_user_id: customerId, rating: 4 })).status, 201);
  for (const method of ['PUT', 'PATCH', 'DELETE']) {
    const response = await fetch('http://127.0.0.1:' + port + '/api/ratings/' + saved.id, {
      method, headers: { Authorization: 'Bearer ' + driver, 'Content-Type': 'application/json' },
      body: JSON.stringify({ rating: 1 })
    });
    assert.equal(response.status, 404);
  }
  const summary = (await api('GET', '/users/' + driverId + '/ratings', customer)).data;
  assert.equal(summary.average_rating, 5);
  assert.equal(summary.rating_count, 1);
  const profile = (await api('GET', '/auth/me', driver)).data.user.profile;
  assert.equal(profile.rating, 5);
  assert.equal(profile.rating_count, 1);
  assert.equal(profile.full_name, 'DRIVER');
  for (const [token, otherId, score] of [[customer, driverId, 5], [driver, customerId, 4]]) {
    const history = (await api('GET', '/trips/history', token)).data.history;
    assert.equal(history.length, 1);
    assert.equal(history[0].request_id, requestId);
    assert.equal(history[0].trip_id, tripId);
    assert.equal(history[0].otherParty.id, otherId);
    assert.equal(history[0].myRating.rating, score);
    assert.equal(history[0].status, 'COMPLETED');
    assert.equal(history[0].origin, 'Alger');
    assert.equal(history[0].destination, 'Oran');
    assert.equal(history[0].truck.type, 'VAN');
  }
  const secondTrip = await trip();
  const secondRequest = await request(secondTrip);
  await api('POST', '/requests/' + secondRequest + '/accept', driver);
  await api('POST', '/trips/' + secondTrip + '/start', driver);
  await api('POST', '/trips/' + secondTrip + '/complete', driver);
  assert.equal((await api('POST', '/requests/' + secondRequest + '/confirm', customer)).status, 200);
  assert.equal((await api('POST', '/ratings', customer, { ...body, trip_id: secondTrip, request_id: secondRequest, rating: 4 })).status, 201);
  const updated = (await api('GET', '/auth/me', driver)).data.user.profile;
  assert.equal(updated.rating, 4.5);
  assert.equal(updated.rating_count, 2);
  console.log('PASS rating security, two-way reviews, duplicate race, profile averages, and private history');
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
