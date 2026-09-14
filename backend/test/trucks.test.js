const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const PORT = 5199;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-trucks-test-${Date.now()}.db`);

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
  console.log('Starting truck API tests on port', PORT);

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

  const truckA = {
    truck_type: 'TARP',
    brand: 'Volvo',
    model: 'FH16',
    max_weight: 25000,
    max_volume: 120,
    registration_number: 'DZ-1234-A',
  };

  const tokenA = await register(randomEmail('drivera'), 'DRIVER');
  const tokenB = await register(randomEmail('driverb'), 'DRIVER');
  const tokenC = await register(randomEmail('customer'), 'CUSTOMER');
  report('register drivers & customer', tokenA && tokenB && tokenC);

  // --- Unauthenticated access denied
  let res = await api('GET', '/trucks/my');
  report('GET /trucks/my requires auth', res.status === 401);

  res = await api('POST', '/trucks', null, truckA);
  report('POST /trucks requires auth', res.status === 401);

  // --- Customer cannot create/edit/delete trucks
  res = await api('POST', '/trucks', tokenC, truckA);
  report('customer cannot create truck', res.status === 403);

  res = await api('GET', '/trucks/my', tokenC);
  report('customer cannot list own trucks', res.status === 403);

  res = await api('GET', '/trucks/1', tokenC);
  report('customer cannot get a truck', res.status === 403);

  res = await api('PUT', '/trucks/1', tokenC, truckA);
  report('customer cannot update a truck', res.status === 403);

  res = await api('DELETE', '/trucks/1', tokenC);
  report('customer cannot delete a truck', res.status === 403);

  // --- Driver A creates trucks
  res = await api('POST', '/trucks', tokenA, truckA);
  report('driver creates truck', res.status === 201 && res.data.truck.id);
  const truck1Id = res.data.truck.id;

  const truck2 = {
    truck_type: 'REFRIGERATED',
    brand: 'Mercedes',
    model: 'Actros',
    max_weight: 20000,
    max_volume: 90,
  };
  res = await api('POST', '/trucks', tokenA, truck2);
  report('driver creates second truck (multiple trucks)', res.status === 201);
  const truck2Id = res.data.truck.id;

  // --- Driver B cannot touch Driver A's truck
  res = await api('GET', `/trucks/${truck1Id}`, tokenB);
  report('driver B cannot view driver A truck', res.status === 403);

  res = await api('PUT', `/trucks/${truck1Id}`, tokenB, truckA);
  report('driver B cannot update driver A truck', res.status === 403);

  res = await api('DELETE', `/trucks/${truck1Id}`, tokenB);
  report('driver B cannot delete driver A truck', res.status === 403);

  // --- Validation
  res = await api('POST', '/trucks', tokenA, { truck_type: 'TARP' });
  report('missing max_weight rejected', res.status === 400);

  res = await api('POST', '/trucks', tokenA, { truck_type: 'NOT_A_TYPE', max_weight: 1000 });
  report('invalid truck type rejected', res.status === 400);

  res = await api('POST', '/trucks', tokenA, { truck_type: 'TARP', max_weight: -5 });
  report('non-positive weight rejected', res.status === 400);

  // --- Driver A lists and views own trucks
  res = await api('GET', '/trucks/my', tokenA);
  report(
    'driver lists own trucks',
    res.status === 200 && Array.isArray(res.data.trucks) && res.data.trucks.length === 2
  );

  res = await api('GET', `/trucks/${truck1Id}`, tokenA);
  report(
    'driver views own truck',
    res.status === 200 && res.data.truck.id === truck1Id && res.data.truck.driver_id
  );

  // --- Update
  res = await api('PUT', `/trucks/${truck1Id}`, tokenA, {
    truck_type: 'FLATBED',
    brand: 'Volvo',
    model: 'FH16',
    max_weight: 26000,
    max_volume: 120,
  });
  report(
    'driver updates own truck',
    res.status === 200 && res.data.truck.max_weight === 26000 && res.data.truck.truck_type === 'FLATBED'
  );

  // --- Delete
  res = await api('DELETE', `/trucks/${truck2Id}`, tokenA);
  report('driver deletes own truck', res.status === 200);

  res = await api('GET', '/trucks/my', tokenA);
  report('truck list reflects deletion', res.status === 200 && res.data.trucks.length === 1);

  // --- 404 for non-existent
  res = await api('GET', '/trucks/99999', tokenA);
  report('get missing truck returns 404', res.status === 404);

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