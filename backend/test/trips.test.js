const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const PORT = 5198;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-trips-test-${Date.now()}.db`);

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
  console.log('Starting trip API tests on port', PORT);

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

  // --- Login as drivers & customer
  const tokenA = await register(randomEmail('drivera'), 'DRIVER');
  const tokenB = await register(randomEmail('driverb'), 'DRIVER');
  const tokenC = await register(randomEmail('customer'), 'CUSTOMER');
  report('register drivers & customer', tokenA && tokenB && tokenC);

  const truckData = {
    truck_type: 'TARP',
    brand: 'Volvo',
    model: 'FH16',
    max_weight: 25000,
    max_volume: 120,
    registration_number: 'DZ-1234-A',
  };

  // --- Select a truck (login -> select truck -> create return trip)
  let res = await api('POST', '/trucks', tokenA, truckData);
  report('driver selects truck for trip publishing', res.status === 201 && res.data.truck.id);
  const truckA = res.data.truck;

  res = await api('POST', '/trucks', tokenB, truckData);
  report('second driver selects truck', res.status === 201 && res.data.truck.id);
  const truckB = res.data.truck;

  const baseTrip = {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2026-09-15',
    available_weight: 5000,
    available_volume: 40,
    description: 'Retour à vide vers Sétif',
  };

  // --- Unauthenticated access denied
  res = await api('GET', '/trips/my');
  report('GET /trips/my requires auth', res.status === 401);

  res = await api('POST', '/trips', null, baseTrip);
  report('POST /trips requires auth', res.status === 401);

  res = await api('GET', '/trips/1');
  report('GET /trips/:id requires auth', res.status === 401);

  // --- Customer cannot manage trips
  res = await api('POST', '/trips', tokenC, baseTrip);
  report('customer cannot create a trip', res.status === 403);

  res = await api('GET', '/trips/my', tokenC);
  report('customer cannot list own trips', res.status === 403);

  res = await api('GET', '/trips/1', tokenC);
  report('customer cannot get a trip', res.status === 403);

  // --- Validation
  res = await api('POST', '/trips', tokenA, {});
  report('missing origin rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    destination_name: 'Sétif',
    departure_date: '2026-09-15',
    available_weight: 5000,
  });
  report('missing origin rejected (partial)', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    departure_date: '2026-09-15',
    available_weight: 5000,
  });
  report('missing destination rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'alger',
    departure_date: '2026-09-15',
    available_weight: 5000,
  });
  report('origin equal to destination rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    available_weight: 5000,
  });
  report('missing date rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2026/09/15',
    available_weight: 5000,
  });
  report('invalid date format rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2026-09-15',
    available_weight: 0,
  });
  report('zero available weight rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2026-09-15',
    available_weight: -5,
  });
  report('negative available weight rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2026-09-15',
    available_weight: 5000,
  });
  report('missing truck rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    ...baseTrip,
    truck_id: 99999,
  });
  report('non-existent truck rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    ...baseTrip,
    truck_id: truckB.id,
  });
  report('truck owned by another driver rejected', res.status === 403);

  res = await api('POST', '/trips', tokenA, {
    ...baseTrip,
    trip_type: 'OUTBOUND',
  });
  report('invalid trip type rejected', res.status === 400);

  res = await api('POST', '/trips', tokenA, {
    ...baseTrip,
    available_weight: truckData.max_weight + 1,
  });
  report('available weight cannot exceed truck capacity', res.status === 400);

  // --- Create a return trip (publish)
  res = await api('POST', '/trips', tokenA, baseTrip);
  report(
    'driver creates return trip (published)',
    res.status === 201 &&
      res.data.trip.id &&
      res.data.trip.trip_type === 'RETURN' &&
      res.data.trip.status === 'PUBLISHED' &&
      res.data.trip.origin_name === 'Alger' &&
      res.data.trip.destination_name === 'Sétif' &&
      res.data.trip.available_weight === 5000
  );
  const trip1Id = res.data.trip.id;

  // --- View the trip
  res = await api('GET', `/trips/${trip1Id}`, tokenA);
  report(
    'driver views own trip',
    res.status === 200 &&
      res.data.trip.id === trip1Id &&
      res.data.trip.driver_id &&
      res.data.trip.truck_id === truckA.id
  );

  // --- Another driver cannot access driver A's trip
  res = await api('GET', `/trips/${trip1Id}`, tokenB);
  report('driver B cannot view driver A trip', res.status === 403);

  res = await api('PUT', `/trips/${trip1Id}`, tokenB, baseTrip);
  report('driver B cannot update driver A trip', res.status === 403);

  res = await api('DELETE', `/trips/${trip1Id}`, tokenB);
  report('driver B cannot delete driver A trip', res.status === 403);

  res = await api('POST', `/trips/${trip1Id}/cancel`, tokenB);
  report('driver B cannot cancel driver A trip', res.status === 403);

  // --- Edit the trip
  res = await api('PUT', `/trips/${trip1Id}`, tokenA, {
    truck_id: truckA.id,
    origin_name: 'Blida',
    destination_name: 'Sétif',
    departure_date: '2026-09-20',
    available_weight: 4000,
    available_volume: 30,
    description: 'Retour à vide modifié',
  });
  report(
    'driver edits own trip',
    res.status === 200 &&
      res.data.trip.origin_name === 'Blida' &&
      res.data.trip.available_weight === 4000 &&
      res.data.trip.departure_date === '2026-09-20' &&
      res.data.trip.status === 'PUBLISHED'
  );

  res = await api('PUT', `/trips/${trip1Id}`, tokenA, {
    ...baseTrip,
    available_weight: truckData.max_weight + 1,
  });
  report('updated available weight cannot exceed truck capacity', res.status === 400);

  // --- List trips
  res = await api('GET', '/trips/my', tokenA);
  report(
    'driver lists own trips',
    res.status === 200 &&
      Array.isArray(res.data.trips) &&
      res.data.trips.length === 1 &&
      res.data.trips[0].id === trip1Id
  );

  // --- Cancel flow
  res = await api('POST', `/trips/${trip1Id}/cancel`, tokenA);
  report('driver cancels own trip', res.status === 200 && res.data.trip.status === 'CANCELLED');

  res = await api('POST', `/trips/${trip1Id}/cancel`, tokenA);
  report('cancelling a cancelled trip rejected', res.status === 400);

  res = await api('POST', `/trips/${trip1Id}/start`, tokenA);
  report('starting a cancelled trip rejected', res.status === 400);

  res = await api('POST', `/trips/${trip1Id}/complete`, tokenA);
  report('completing a cancelled trip rejected', res.status === 400);

  // --- Start -> Complete flow on a second trip
  res = await api('POST', '/trips', tokenA, {
    truck_id: truckA.id,
    origin_name: 'Tizi Ouzou',
    destination_name: 'Alger',
    departure_date: '2026-09-22',
    available_weight: 3000,
  });
  report('driver creates second return trip', res.status === 201);
  const trip2Id = res.data.trip.id;

  res = await api('POST', `/trips/${trip2Id}/complete`, tokenA);
  report('completing a published trip (not started) rejected', res.status === 400);

  res = await api('POST', `/trips/${trip2Id}/start`, tokenA);
  report('driver starts trip', res.status === 200 && res.data.trip.status === 'IN_PROGRESS');

  res = await api('POST', `/trips/${trip2Id}/start`, tokenA);
  report('starting an in-progress trip rejected', res.status === 400);

  res = await api('POST', `/trips/${trip2Id}/complete`, tokenA);
  report('driver completes trip', res.status === 200 && res.data.trip.status === 'COMPLETED');

  res = await api('POST', `/trips/${trip2Id}/cancel`, tokenA);
  report('cancelling a completed trip rejected', res.status === 400);

  // --- Delete a trip
  res = await api('DELETE', `/trips/${trip1Id}`, tokenA);
  report('driver deletes own trip', res.status === 200);

  res = await api('GET', `/trips/${trip1Id}`, tokenA);
  report('deleted trip returns 404', res.status === 404);

  res = await api('DELETE', '/trips/99999', tokenA);
  report('delete missing trip returns 404', res.status === 404);

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