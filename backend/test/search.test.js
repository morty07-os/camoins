const { spawn } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');

const PORT = 5204;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-search-test-${Date.now()}.db`);
let server;

async function api(method, route, token, body) {
  const response = await fetch(`${BASE}${route}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}

async function register(prefix, role) {
  const response = await api('POST', '/auth/register', null, {
    email: `${prefix}-${Date.now()}@test.example`,
    password: 'password123',
    full_name: prefix,
    phone: '0555000000',
    role,
  });
  assert.equal(response.status, 201);
  return response.data.token;
}

async function search(params = {}) {
  const query = new URLSearchParams(params).toString();
  return api('GET', `/search/trips${query ? `?${query}` : ''}`);
}

async function createTrip(token, truckId, overrides) {
  const response = await api('POST', '/trips', token, {
    truck_id: truckId,
    origin_name: 'Alger',
    destination_name: 'Sétif',
    departure_date: '2035-06-10',
    available_weight: 1000,
    available_volume: 10,
    ...overrides,
  });
  assert.equal(response.status, 201, JSON.stringify(response.data));
  return response.data.trip;
}

async function run() {
  server = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(PORT), DB_PATH },
    stdio: 'ignore',
  });

  for (let attempt = 0; attempt < 40; attempt++) {
    await new Promise(resolve => setTimeout(resolve, 250));
    try {
      if ((await fetch(`${BASE}/health`)).ok) break;
    } catch (_) {
      // Server is still starting.
    }
    if (attempt === 39) throw new Error('Server failed to start');
  }

  const driver = await register('search-driver', 'DRIVER');
  const customer = await register('search-customer', 'CUSTOMER');
  const tarpResponse = await api('POST', '/trucks', driver, {
    truck_type: 'TARP',
    brand: 'Volvo',
    model: 'FH',
    max_weight: 5000,
    max_volume: 100,
    registration_number: 'SEARCH-TARP',
  });
  const vanResponse = await api('POST', '/trucks', driver, {
    truck_type: 'VAN',
    brand: 'Iveco',
    model: 'Daily',
    max_weight: 5000,
    max_volume: 100,
    registration_number: 'SEARCH-VAN',
  });
  const tarpId = tarpResponse.data.truck.id;
  const vanId = vanResponse.data.truck.id;

  const exact = await createTrip(driver, tarpId, {});
  const oran = await createTrip(driver, vanId, {
    destination_name: 'Oran',
    available_weight: 1500,
    available_volume: null,
  });
  const reverse = await createTrip(driver, tarpId, {
    origin_name: 'Sétif',
    destination_name: 'Alger',
    available_weight: 900,
    available_volume: 20,
  });
  const later = await createTrip(driver, tarpId, {
    departure_date: '2035-06-11',
    available_weight: 2000,
    available_volume: 30,
  });
  const booked = await createTrip(driver, tarpId, {
    available_weight: 1200,
    available_volume: 15,
  });

  const booking = await api('POST', '/requests', customer, {
    trip_id: booked.id,
    requested_weight: 200,
    requested_volume: 5,
    cargo_description: 'Capacity verification',
  });
  assert.equal(booking.status, 201);
  const accepted = await api('POST', `/requests/${booking.data.request.id}/accept`, driver);
  assert.equal(accepted.status, 200);

  let response = await search();
  assert.equal(response.status, 200);
  assert.equal(response.data.count, 5, 'no filters returns every eligible trip');

  response = await search({ origin_name: '', destination_name: '', date: '', truck_type: '' });
  assert.equal(response.status, 200);
  assert.equal(response.data.count, 5, 'blank optional filters impose no restriction');

  response = await search({ origin_name: '  ALGER  ' });
  assert.deepEqual(new Set(response.data.trips.map(item => item.trip.id)), new Set([exact.id, oran.id, later.id, booked.id]));

  response = await search({ destination_name: ' setif ' });
  assert.deepEqual(new Set(response.data.trips.map(item => item.trip.id)), new Set([exact.id, later.id, booked.id]));

  response = await search({ origin_name: 'alger', destination_name: 'SETIF' });
  assert.deepEqual(new Set(response.data.trips.map(item => item.trip.id)), new Set([exact.id, later.id, booked.id]), 'direction and both locations match');
  assert.ok(!response.data.trips.some(item => item.trip.id === reverse.id));

  response = await search({ required_weight: '1000' });
  assert.ok(response.data.trips.some(item => item.trip.id === exact.id), 'exactly 1000 kg is included');
  assert.ok(response.data.trips.some(item => item.trip.id === booked.id), 'remaining capacity after accepted booking is used');
  assert.ok(!response.data.trips.some(item => item.trip.id === reverse.id), 'less than 1000 kg is excluded');

  response = await search({ required_volume: '16' });
  assert.deepEqual(new Set(response.data.trips.map(item => item.trip.id)), new Set([reverse.id, later.id]));
  assert.ok(!response.data.trips.some(item => item.trip.id === oran.id), 'unknown volume cannot satisfy requested volume');

  response = await search({
    origin_name: 'Alger',
    destination_name: 'Setif',
    date: '2035-06-10',
    required_weight: '1000,0',
    required_volume: '10',
    truck_type: 'TARP',
  });
  assert.deepEqual(new Set(response.data.trips.map(item => item.trip.id)), new Set([exact.id, booked.id]), 'all active filters use AND');

  response = await search({ origin_name: 'Alger', destination_name: 'Constantine' });
  assert.equal(response.data.count, 0);
  assert.deepEqual(response.data.trips, []);

  const firstPage = await search({ destination_name: 'Setif', page: '1', page_size: '2' });
  const secondPage = await search({ destination_name: 'Setif', page: '2', page_size: '2' });
  assert.equal(firstPage.data.count, 3);
  assert.equal(firstPage.data.totalPages, 2);
  assert.equal(firstPage.data.trips.length, 2);
  assert.equal(secondPage.data.trips.length, 1, 'filtering happens before pagination');

  response = await search({ truck_type: 'VAN' });
  assert.deepEqual(response.data.trips.map(item => item.trip.id), [oran.id]);

  response = await search({ required_weight: '-1' });
  assert.equal(response.status, 400);
  response = await search({ required_volume: 'not-a-number' });
  assert.equal(response.status, 400);
  response = await search({ date: '2035-02-30' });
  assert.equal(response.status, 400);

  console.log('PASS optional AND filters, normalization, direction, remaining capacity, validation, and pagination');
}

run()
  .catch(error => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (server) {
      server.kill();
      await new Promise(resolve => setTimeout(resolve, 300));
    }
    try {
      fs.unlinkSync(DB_PATH);
    } catch (_) {
      // Ignore cleanup races on Windows.
    }
  });
