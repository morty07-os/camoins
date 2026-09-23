const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'backhaul-completion-'));
process.env.DB_PATH = path.join(directory, 'test.db');
process.env.JWT_SECRET = 'completion-test-secret';
const db = require('../database');
const { generateToken } = require('../auth');
const Completion = require('../completion');
const port = 5210;
let server;
let output = '';
let socket;
const socketEvents = [];
async function until(predicate) {
  for (let i = 0; i < 100; i++) {
    if (predicate()) return;
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  throw new Error('Socket event timed out');
}
async function listen(user, conversationId) {
  socket = new WebSocket(`ws://127.0.0.1:${port}/socket.io/?EIO=4&transport=websocket`);
  socket.addEventListener('message', event => {
    const packet = String(event.data);
    if (packet.startsWith('0')) socket.send('40' + JSON.stringify({ token: generateToken(user) }));
    if (packet.startsWith('40')) socket.send('42' + JSON.stringify(['join-conversation', conversationId]));
    if (packet === '2') socket.send('3');
    if (packet.startsWith('42')) socketEvents.push(JSON.parse(packet.slice(2)));
  });
  await until(() => socketEvents.some(([type]) => type === 'joined-conversation'));
}
const driver = { id: 1, role: 'DRIVER' };
const customer = { id: 2, role: 'CUSTOMER' };
const other = { id: 3, role: 'CUSTOMER' };
const stranger = { id: 4, role: 'DRIVER' };
async function api(method, route, user) {
  const response = await fetch(`http://127.0.0.1:${port}/api${route}`, {
    method, headers: user ? { Authorization: `Bearer ${generateToken(user)}` } : {},
    signal: AbortSignal.timeout(5000),
  });
  return { status: response.status, data: await response.json() };
}
async function start() {
  server = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(port) }, stdio: ['ignore', 'pipe', 'pipe'],
  });
  server.stdout.on('data', data => output += data);
  server.stderr.on('data', data => output += data);
  for (let i = 0; i < 300; i++) {
    if (server.exitCode !== null) throw new Error(output);
    try { if ((await api('GET', '/health')).status === 200) return; } catch (_) {}
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(output);
}
async function stop() {
  if (server && server.exitCode === null) { server.kill(); await once(server, 'exit'); }
}
const status = id => db.prepare('SELECT * FROM transport_requests WHERE id = ?').get(id);
const counts = () => ['messages', 'notifications'].map(table => db.prepare(`SELECT count(*) n FROM ${table}`).get().n);

async function run() {
  db.exec(`INSERT INTO users (id,email,password_hash,role) VALUES
    (1,'driver','unused','DRIVER'),(2,'client','unused','CUSTOMER'),
    (3,'other','unused','CUSTOMER'),(4,'stranger','unused','DRIVER');
    INSERT INTO profiles (user_id,full_name) VALUES (1,'Chauffeur'),(2,'Client'),(3,'Autre');
    INSERT INTO trucks (id,driver_id,truck_type,max_weight) VALUES (1,1,'VAN',100);
    INSERT INTO trips (id,driver_id,truck_id,origin_name,destination_name,departure_date,
      available_weight,trip_type,status) VALUES (1,1,1,'Alger','Oran','2030-01-01',50,'RETURN','IN_PROGRESS');
    INSERT INTO transport_requests (id,trip_id,customer_id,requested_weight,status) VALUES
      (1,1,2,10,'ACCEPTED'),(2,1,3,10,'ACCEPTED'),(3,1,2,10,'ACCEPTED'),
      (4,1,2,10,'COMPLETED'),(5,1,2,10,'CANCELLED'),(6,1,2,10,'REJECTED'),(7,1,2,10,'PENDING');
    INSERT INTO conversations (id,request_id,driver_id,customer_id) VALUES (20,4,1,2);
    INSERT INTO messages (conversation_id,sender_id,message) VALUES (20,1,'Historique conservé');
    INSERT INTO ratings (trip_id,request_id,reviewer_id,reviewed_user_id,rating) VALUES (1,4,2,1,5);`);

  // Downgrade only this disposable fixture to the old schema, then exercise
  // startup migration against real completed rows and dependent records.
  const schema = db.prepare("SELECT sql FROM sqlite_master WHERE name = 'transport_requests'").get().sql;
  const columns = db.pragma('table_info(transport_requests)').map(c => c.name)
    .filter(name => !['driver_finished_at', 'customer_confirmed_at'].includes(name));
  const triggers = db.prepare("SELECT name,sql FROM sqlite_master WHERE type='trigger'").all();
  db.pragma('foreign_keys = OFF');
  db.transaction(() => {
    for (const trigger of triggers) db.exec(`DROP TRIGGER ${trigger.name}`);
    db.exec(schema.replace('transport_requests', 'legacy_requests')
      .replace("'AWAITING_CUSTOMER_CONFIRMATION',", '')
      .replace(/,\s*driver_finished_at TEXT/g, '').replace(/,\s*customer_confirmed_at TEXT/g, ''));
    db.exec(`INSERT INTO legacy_requests (${columns}) SELECT ${columns} FROM transport_requests;
      DROP TABLE transport_requests; ALTER TABLE legacy_requests RENAME TO transport_requests;`);
    for (const trigger of triggers) db.exec(trigger.sql);
  })();
  db.pragma('foreign_keys = ON');
  await start();
  assert.equal(status(4).status, 'COMPLETED');
  assert.equal(status(4).customer_confirmed_at, null);
  assert.equal(db.prepare('SELECT count(*) n FROM ratings').get().n, 1);
  assert.deepEqual(db.pragma('foreign_key_check'), []);
  assert.equal((await api('GET', '/trips/history', customer)).data.history[0].request_id, 4);
  assert.deepEqual((await api('GET', '/trips/history', other)).data.history, []);
  assert.equal((await api('POST', '/trips/1/complete')).status, 401);
  assert.equal((await api('POST', '/trips/1/complete', stranger)).status, 403);
  assert.equal((await api('POST', '/requests/1/confirm', other)).status, 403);
  assert.equal((await api('POST', '/requests/1/confirm', customer)).status, 409);
  for (const id of [5,6,7]) {
    assert.equal((await api('POST', `/requests/${id}/complete`, driver)).status, 409);
    assert.equal((await api('POST', `/requests/${id}/confirm`, customer)).status, 409);
  }
  // Fail the last write: status, conversation and system message must roll back.
  db.exec(`CREATE TRIGGER fail_notice BEFORE INSERT ON notifications
    BEGIN SELECT RAISE(ABORT, 'forced notification failure'); END;`);
  assert.throws(() => Completion.finishRequest(1, driver), /forced notification/);
  assert.equal(status(1).status, 'ACCEPTED');
  assert.deepEqual(counts(), [1,0]);
  db.exec('DROP TRIGGER fail_notice');
  const liveConversation = require('../models').ConversationModel.findOrCreateByRequestId(1);
  await listen(customer, liveConversation.id);

  // Individual completion must not affect another request or physical trip.
  assert.equal((await api('POST', '/requests/1/complete', driver)).status, 200);
  await until(() => socketEvents.some(([type]) => type === 'notification') &&
    socketEvents.some(([type]) => type === 'message-received'));
  const liveMessage = socketEvents.find(([type]) => type === 'message-received')[1];
  assert.equal(liveMessage.conversation_id, liveConversation.id);
  assert.equal(liveMessage.is_system, 1);
  assert.equal(db.prepare('SELECT message FROM messages WHERE id = ?').get(liveMessage.id).message, liveMessage.message);
  socket.close();
  assert.equal(status(1).status, 'AWAITING_CUSTOMER_CONFIRMATION');
  assert.equal(status(2).status, 'ACCEPTED');
  assert.equal(db.prepare('SELECT status FROM trips WHERE id=1').get().status, 'IN_PROGRESS');
  const completed = await Promise.all(Array.from({ length: 4 }, () => api('POST', '/trips/1/complete', driver)));
  assert.ok(completed.every(result => result.status === 200));
  assert.deepEqual(counts(), [4,4]);
  assert.equal(status(7).status, 'CANCELLED');
  assert.equal(status(5).status, 'CANCELLED');
  assert.equal(status(6).status, 'REJECTED');
  assert.equal(status(4).status, 'COMPLETED');
  const conversations = db.prepare('SELECT * FROM conversations WHERE request_id IN (1,2,3)').all();
  assert.equal(new Set(conversations.map(c => c.id)).size, 3);
  const notification = (await api('GET', '/notifications', customer)).data.notifications
    .find(n => n.request_id === 1);
  assert.equal(notification.trip_id, 1);
  const cid = notification.conversation_id;
  assert.equal((await api('GET', `/conversations/${cid}`, other)).status, 403);
  const messages = (await api('GET', `/conversations/${cid}/messages`, customer)).data.messages;
  assert.equal(messages[0].message, 'Le chauffeur a terminé le trajet. Veuillez confirmer la réception de votre marchandise.');
  assert.equal(messages[0].is_system, 1);
  assert.equal((await api('GET', '/trips/history', customer)).data.history.length, 1);
  await stop(); await start();
  assert.equal((await api('GET', `/conversations/${cid}`, customer)).data.conversation.request_status, 'AWAITING_CUSTOMER_CONFIRMATION');
  assert.equal((await api('POST', '/requests/1/confirm', driver)).status, 403);
  const confirmations = await Promise.all(Array.from({ length: 5 }, () => api('POST', '/requests/1/confirm', customer)));
  assert.ok(confirmations.every(result => result.status === 200));
  assert.deepEqual(counts(), [5,5]);
  assert.equal(status(1).status, 'COMPLETED');
  assert.match(status(1).customer_confirmed_at, /^\d{4}-\d{2}-\d{2} /);
  assert.ok(status(1).driver_finished_at);
  assert.equal(status(2).status, 'AWAITING_CUSTOMER_CONFIRMATION');
  assert.equal(status(3).status, 'AWAITING_CUSTOMER_CONFIRMATION');
  assert.equal((await api('GET', '/trips/history', customer)).data.history.length, 2);
  assert.equal((await api('GET', '/trips/history', driver)).status, 200);
  assert.equal((await api('POST', '/requests/1/cancel', customer)).status, 400);
  assert.equal((await api('POST', '/requests/2/cancel', other)).status, 400);
  assert.equal(db.prepare('SELECT available_weight FROM trips WHERE id=1').get().available_weight, 50);
  await stop(); await start();
  assert.equal((await api('GET', `/conversations/${cid}`, customer)).data.conversation.request_status, 'COMPLETED');
  assert.deepEqual(counts(), [5,5]);
  // Cancelling the remainder of a shared trip must not strand a delivery
  // already physically finished and awaiting its customer's confirmation.
  db.exec(`INSERT INTO trips (id,driver_id,truck_id,origin_name,destination_name,departure_date,
    available_weight,trip_type,status) VALUES (2,1,1,'Alger','Oran','2030-01-01',50,'RETURN','IN_PROGRESS');
    INSERT INTO transport_requests (id,trip_id,customer_id,requested_weight,status)
    VALUES (8,2,2,10,'ACCEPTED');`);
  assert.equal((await api('POST', '/requests/8/complete', driver)).status, 200);
  assert.equal((await api('POST', '/trips/2/cancel', driver)).status, 200);
  assert.equal((await api('POST', '/requests/8/confirm', customer)).status, 200);
  assert.equal(status(8).status, 'COMPLETED');
  console.log('PASS legacy migration/history, rollback, ownership, independent deliveries, concurrent retries, persistence/restart, messages/notification identifiers, unchanged capacity');
}
run().catch(error => { console.error(error, output); process.exitCode = 1; }).finally(async () => {
  socket?.close();
  await stop(); db.close();
  // This exact temp directory was created by this test, never the app database.
  fs.rmSync(directory, { recursive: true, force: true });
});
