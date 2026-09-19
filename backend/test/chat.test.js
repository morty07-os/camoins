const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const PORT = 5200;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-chat-test-${Date.now()}.db`);

let server;
let passed = 0;
let failed = 0;

const results = [];

function report(name, ok, detail = '') {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}${detail ? ` - ${detail}` : ''}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` - ${detail}` : ''}`);
    results.push({ name, detail });
  }
}

async function api(method, url, token, body) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${BASE}${url}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let data = null;
  try {
    data = await res.json();
  } catch (_) {
    /* no body */
  }
  return { status: res.status, data };
}

async function register(email, role) {
  const res = await api('POST', '/auth/register', null, {
    email,
    password: 'password123',
    full_name: email.split('@')[0],
    phone: '0555123456',
    role,
  });
  return res.data.token;
}

function randomEmail(prefix) {
  return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 10000)}@test.com`;
}

async function run() {
  console.log('Starting chat API tests on port', PORT);

  server = spawn('node', [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(PORT), DB_PATH },
    stdio: 'ignore',
  });

  // Wait for the server to come up
  let up = false;
  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 250));
    try {
      const res = await fetch(`${BASE}/health`);
      if (res.ok) {
        up = true;
        break;
      }
    } catch (_) {}
  }

  if (!up) {
    console.error('Server failed to start');
    process.exit(1);
  }

  const driver = await register(randomEmail('driver'), 'DRIVER');
  const customer = await register(randomEmail('customer'), 'CUSTOMER');
  const outsider = await register(randomEmail('outsider'), 'CUSTOMER');
  report('register driver & customers', !!(driver && customer && outsider));

  // --- Driver publishes a trip that the customer can request
  let res = await api('POST', '/trucks', driver, {
    truck_type: 'TARP',
    brand: 'Volvo',
    model: 'FH16',
    max_weight: 25000,
    max_volume: 120,
    registration_number: 'DZ-7777-CHAT',
  });
  report('driver creates truck for chat', res.status === 201);
  const truckId = res.data.truck.id;

  res = await api('POST', '/trips', driver, {
    truck_id: truckId,
    origin_name: 'Alger',
    destination_name: 'Oran',
    departure_date: '2026-09-25',
    available_weight: 5000,
    available_volume: 40,
  });
  report('driver publishes trip for chat', res.status === 201);
  const tripId = res.data.trip.id;

  res = await api('POST', '/requests', customer, {
    trip_id: tripId,
    requested_weight: 1000,
    cargo_description: 'Chat test cargo',
    pickup_location: 'Alger',
    delivery_location: 'Oran',
  });
  report('customer sends transport request', res.status === 201);
  const requestId = res.data.request.id;

  res = await api('POST', `/requests/${requestId}/accept`, driver);
  report('accepting request creates a conversation', res.status === 200 && !!res.data.conversation);
  const conversationId = res.data.conversation.id;

  res = await api('GET', `/conversations/${conversationId}/messages`, driver);
  report('conversation starts empty', res.status === 200 && res.data.messages.length === 0);

  // --- The core regression: a single REST send must persist exactly one row
  res = await api('POST', `/conversations/${conversationId}/messages`, customer, {
    message: 'Hello from customer',
  });
  report(
    'customer sends a message',
    res.status === 201 && res.data.data.message === 'Hello from customer',
  );
  const messageId = res.data.data.id;

  res = await api('GET', `/conversations/${conversationId}/messages`, driver);
  const firstSend = res.data.messages.filter((m) => m.message === 'Hello from customer');
  report(
    'REST send persists exactly one message (no duplicate)',
    res.status === 200 && firstSend.length === 1,
    `found ${firstSend.length}`,
  );

  res = await api('POST', `/conversations/${conversationId}/messages`, customer, {
    message: 'Second message',
  });
  report('customer sends a second message', res.status === 201);

  res = await api('GET', `/conversations/${conversationId}/messages`, driver);
  report(
    'two sends persist exactly two messages',
    res.status === 200 && res.data.messages.length === 2,
    `found ${res.data.messages.length}`,
  );
  report(
    'messages carry sender_name for the UI',
    res.data.messages.every(
      (m) => typeof m.sender_name === 'string' && m.sender_name.length > 0,
    ),
  );

  // --- Read receipts
  res = await api('PATCH', `/messages/${messageId}/read`, driver);
  report('recipient marks a message as read', res.status === 200 && res.data.data.read_at !== null);

  res = await api('GET', '/conversations', driver);
  const driverConversation = res.data.conversations.find((c) => c.id === conversationId);
  report(
    'conversation lists last message for driver',
    !!driverConversation && !!driverConversation.last_message,
  );
  report(
    'unread count clears once messages are read',
    !!driverConversation && driverConversation.unread_count === 0,
    `unread=${driverConversation && driverConversation.unread_count}`,
  );

  // --- Access control
  res = await api('GET', `/conversations/${conversationId}/messages`, outsider);
  report('outsider cannot read conversation messages', res.status === 403);

  res = await api('POST', `/conversations/${conversationId}/messages`, outsider, {
    message: 'intrude',
  });
  report('outsider cannot post to a conversation', res.status === 403);

  // --- Validation
  res = await api('POST', `/conversations/${conversationId}/messages`, customer, { message: '   ' });
  report('empty message is rejected', res.status === 400);

  res = await api('GET', '/conversations/999999/messages', customer);
  report('missing conversation returns 404', res.status === 404);

  res = await api('GET', '/conversations', null);
  report('GET /conversations requires auth', res.status === 401);

  res = await api('POST', `/conversations/${conversationId}/messages`, null, { message: 'hi' });
  report('POST message requires auth', res.status === 401);

  console.log(`\n${passed} passed, ${failed} failed`);
  if (failed > 0) {
    console.error('Failures:', results);
  }
}

run()
  .catch((e) => {
    console.error('Test run error:', e);
    failed++;
  })
  .finally(() => {
    if (server) {
      server.kill();
      setTimeout(() => {
        try {
          fs.unlinkSync(DB_PATH);
        } catch (_) {}
        process.exit(failed === 0 ? 0 : 1);
      }, 300);
    } else {
      process.exit(failed === 0 ? 0 : 1);
    }
  });