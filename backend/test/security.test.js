const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const { once } = require('node:events');
const { randomBytes } = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const port = 5297;
const base = `http://127.0.0.1:${port}`;
const secret = randomBytes(48).toString('hex');
const dbPath = path.join(os.tmpdir(), `camoins-security-${randomBytes(8).toString('hex')}.db`);
const sockets = [];
let server;

async function waitFor(predicate) {
  for (let i = 0; i < 100; i++) {
    if (await predicate()) return;
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error('Timed out waiting for security test condition');
}
async function start(extraEnv = {}) {
  server = spawn(process.execPath, ['server.js'], {
    cwd: path.resolve(__dirname, '..'), windowsHide: true, stdio: 'ignore',
    env: { ...process.env, PORT: String(port), DB_PATH: dbPath, NODE_ENV: 'test', JWT_SECRET: secret, TRUST_PROXY: 'false', ...extraEnv },
  });
  await waitFor(async () => {
    try { return (await fetch(base + '/api/health')).ok; } catch { return false; }
  });
}
async function stop() {
  if (server && server.exitCode === null) {
    const closed = once(server, 'exit');
    server.kill();
    await closed;
  }
}
async function api(method, route, token, body, extraHeaders = {}) {
  const response = await fetch(base + '/api' + route, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...extraHeaders },
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(5000),
  });
  return { status: response.status, data: await response.json(), headers: response.headers };
}
async function connect(token, origin) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}/socket.io/?EIO=4&transport=websocket`);
  sockets.push(ws);
  const packets = [];
  ws.addEventListener('error', () => {});
  ws.addEventListener('message', event => {
    const packet = String(event.data);
    packets.push(packet);
    if (packet.startsWith('0')) ws.send('40' + JSON.stringify({ token }));
    if (packet === '2') ws.send('3');
  });
  await waitFor(() => packets.some(p => p.startsWith('40') || p.startsWith('44')));
  return { ws, packets };
}
let ackId = 0;
async function send(socket, event, data) {
  const id = ++ackId;
  socket.ws.send(`42${id}` + JSON.stringify([event, data]));
  await waitFor(() => socket.packets.some(p => p.startsWith(`43${id}[`)));
  return JSON.parse(socket.packets.find(p => p.startsWith(`43${id}[`)).slice(`43${id}`.length))[0];
}

async function run() {
  for (const badSecret of ['', 'short', 'backhaul-secret-key-change-in-production']) {
    const result = spawnSync(process.execPath, ['-e', "require('./auth')"], {
      cwd: path.resolve(__dirname, '..'), env: { ...process.env, DB_PATH: ':memory:', JWT_SECRET: badSecret },
      encoding: 'utf8', windowsHide: true,
    });
    assert.notEqual(result.status, 0, 'unsafe signing keys must fail closed');
  }
  await start();
  const registration = role => ({ email: `${role}@audit.invalid`, password: 'test-password-123', full_name: 'Audit', role });
  for (const password of ['short', 'x'.repeat(73), 'é'.repeat(37), 123456789012]) {
    assert.equal((await api('POST', '/auth/register', null, { ...registration('CUSTOMER'), password })).status, 400);
  }
  const driver = (await api('POST', '/auth/register', null, registration('DRIVER'))).data;
  const customer = (await api('POST', '/auth/register', null, registration('CUSTOMER'))).data;
  assert.ok(driver.token && customer.token);
  const claims = jwt.decode(customer.token);
  assert.equal(claims.exp - claims.iat, 12 * 3600);
  assert.equal((await api('GET', '/auth/me', jwt.sign({ id: customer.user.id }, secret))).status, 401, 'tokens need expiry');
  assert.equal((await api('GET', '/auth/me', jwt.sign({ id: customer.user.id }, secret, { algorithm: 'HS384', expiresIn: '1h' }))).status, 401);
  const truck = await api('POST', '/trucks', driver.token, { truck_type: 'VAN', max_weight: 1000, registration_number: 'PRIVATE' });
  const trip = await api('POST', '/trips', driver.token, { truck_id: truck.data.truck.id, origin_name: 'Alger', destination_name: 'Oran', departure_date: '2035-06-10', available_weight: 1000, trip_type: 'RETURN' });
  const search = await api('GET', '/search/trips');
  assert.equal(search.status, 200);
  assert.equal(Object.hasOwn(search.data.trips[0].driver, 'email'), false);
  assert.equal(Object.hasOwn(search.data.trips[0].truck, 'registration_number'), false);
  const request = await api('POST', '/requests', customer.token, { trip_id: trip.data.trip.id, requested_weight: 10 });
  const conversation = await api('POST', '/conversations', customer.token, { request_id: request.data.request.id });
  const id = conversation.data.conversation.id;
  const route = `/conversations/${id}/messages`;
  for (const query of ['limit=-1', 'limit=101', 'limit=0', 'limit=1.5', 'limit[]=2', 'offset=-1', 'offset=100001']) {
    for (const endpoint of [route, '/notifications']) assert.equal((await api('GET', `${endpoint}?${query}`, customer.token)).status, 400);
  }
  for (const message of ['', ' ', 'x'.repeat(4001), { text: 'invalid' }]) {
    assert.equal((await api('POST', route, customer.token, { message })).status, 400);
  }
  const live = await connect(customer.token);
  assert.equal((await send(live, 'send-message', { conversationId: id, message: 'x'.repeat(4001) })).success, false);
  assert.equal((await send(live, 'send-message', { conversationId: id, message: { text: 'invalid' } })).success, false);
  assert.equal((await send(live, 'send-message', { conversationId: id, message: 'x'.repeat(4000) })).success, true);
  for (let i = 0; i < 29; i++) assert.equal((await api('POST', route, customer.token, { message: `test ${i}` })).status, 201);
  assert.equal((await api('POST', route, customer.token, { message: 'limited' })).status, 429);
  assert.equal((await send(live, 'send-message', { conversationId: id, message: 'limited' })).success, false);
  const reconnected = await connect(customer.token);
  assert.equal((await send(reconnected, 'send-message', { conversationId: id, message: 'still limited' })).success, false);
  const history = await api('GET', route + '?limit=1', driver.token);
  assert.equal(history.data.messages.length, 1);
  assert.equal(history.headers.get('cache-control'), 'no-store');
  assert.equal(history.headers.get('x-content-type-options'), 'nosniff');
  console.log('PASS public data minimization, password validation, bounded pagination, and shared REST/socket message limits');

  const shortToken = jwt.sign({ id: driver.user.id }, secret, { expiresIn: 2 });
  const expiring = await connect(shortToken);
  await waitFor(() => expiring.ws.readyState === WebSocket.CLOSED);
  assert.equal((await api('GET', '/auth/me', shortToken)).status, 401);
  const expiredConnection = await connect(shortToken);
  assert.ok(expiredConnection.packets.some(p => p.startsWith('44')), 'expired tokens cannot reconnect');
  const otherSession = (await api('POST', '/auth/login', null, { email: 'CUSTOMER@audit.invalid', password: 'test-password-123' })).data.token;
  assert.ok(otherSession && otherSession !== customer.token);
  assert.equal((await api('POST', '/auth/logout', customer.token)).status, 200);
  await waitFor(() => live.ws.readyState === WebSocket.CLOSED && reconnected.ws.readyState === WebSocket.CLOSED);
  assert.equal((await api('GET', '/auth/me', customer.token)).status, 401);
  assert.equal((await api('GET', '/auth/me', otherSession)).status, 200);
  const revokedConnection = await connect(customer.token);
  assert.ok(revokedConnection.packets.some(p => p.startsWith('44')));
  for (const socket of sockets) socket.close();
  await stop();
  await start();
  assert.equal((await api('GET', '/auth/me', customer.token)).status, 401, 'revocation survives restart');
  assert.equal((await api('GET', '/auth/me', otherSession)).status, 200);
  console.log('PASS socket expiry, logout disconnects copied sessions, persistent revocation, and independent login sessions');
  for (let i = 0; i < 60; i++) assert.equal((await fetch(base + '/api/search/trips')).status, 200);
  assert.equal((await fetch(base + '/api/search/trips')).status, 429);
  await stop();
  await start({ NODE_ENV: 'production', TRUST_PROXY: 'false' });
  assert.equal((await api('GET', '/auth/me', otherSession)).status, 400);
  assert.equal((await api('GET', '/auth/me', otherSession, undefined, { 'X-Forwarded-Proto': 'https' })).status, 400);
  await stop();
  await start({ NODE_ENV: 'production', TRUST_PROXY: 'true' });
  assert.equal((await api('GET', '/auth/me', otherSession, undefined, { 'X-Forwarded-Proto': 'https' })).status, 200);
  console.log('PASS search abuse limit and production HTTPS enforcement with explicit proxy trust');
}
run().catch(error => { console.error(error); process.exitCode = 1; }).finally(async () => {
  for (const socket of sockets) socket.close();
  await stop();
  for (const suffix of ['', '-wal', '-shm', '-journal']) {
    if (fs.existsSync(dbPath + suffix)) fs.unlinkSync(dbPath + suffix);
  }
});
