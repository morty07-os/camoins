const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PORT = 5197;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-auth-test-${process.pid}.db`);

async function request(route, body) {
  const response = await fetch(`${BASE}${route}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}

async function waitForServer() {
  for (let attempt = 0; attempt < 40; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    try {
      if ((await fetch(`${BASE}/health`)).ok) return;
    } catch (_) {
      // The child process may still be starting.
    }
  }
  throw new Error('Server failed to start');
}

async function run() {
  const server = spawn('node', [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(PORT), DB_PATH },
    stdio: 'ignore',
  });

  try {
    await waitForServer();

    let result = await request('/auth/register', {
      email: '  Driver.Example@TEST.com  ',
      password: 'password123',
      full_name: '  Example Driver  ',
      role: 'DRIVER',
    });
    if (result.status !== 201 || result.data.user.email !== 'driver.example@test.com' ||
        result.data.user.profile.full_name !== 'Example Driver') {
      throw new Error('Registration did not normalize account fields');
    }

    result = await request('/auth/login', {
      email: ' DRIVER.EXAMPLE@test.COM ',
      password: 'password123',
    });
    if (result.status !== 200 || !result.data.token) {
      throw new Error('Login should be case-insensitive and ignore surrounding whitespace');
    }

    result = await request('/auth/register', {
      email: 'DRIVER.EXAMPLE@TEST.COM',
      password: 'password123',
      full_name: 'Duplicate',
      role: 'DRIVER',
    });
    if (result.status !== 400 || result.data.message !== 'Email already registered') {
      throw new Error('Case variants of an existing email should be rejected');
    }

    result = await request('/auth/register', {
      email: 'invalid-password@test.com',
      password: 123456,
      full_name: 'Invalid Password',
      role: 'CUSTOMER',
    });
    if (result.status !== 400) {
      throw new Error('Non-string passwords should return a validation error');
    }

    console.log('Authentication normalization and validation tests passed');
  } finally {
    server.kill();
    fs.rmSync(DB_PATH, { force: true });
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
