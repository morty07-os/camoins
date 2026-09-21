const { spawn } = require('child_process');
const path = require('path');
const os = require('os');

const PORT = 5210;
const BASE = `http://localhost:${PORT}/api`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-auth-rate-limit-${Date.now()}.db`);

let server;

async function api(url, body) {
  const response = await fetch(`${BASE}${url}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return { status: response.status, data: await response.json() };
}

function registration(email) {
  return {
    email,
    password: 'password123',
    full_name: 'Rate Limit Test User',
    role: 'CUSTOMER',
  };
}

async function waitForServer() {
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const response = await fetch(`${BASE}/health`);
      if (response.ok) return;
    } catch (_) {
      // Server is still starting.
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error('Server failed to start');
}

async function run() {
  const email = `auth-rate-limit-${Date.now()}@test.com`;

  server = spawn('node', [path.join(__dirname, '..', 'server.js')], {
    env: { ...process.env, PORT: String(PORT), DB_PATH },
    stdio: 'ignore',
  });

  await waitForServer();

  let response = await api('/auth/register', registration(email));
  if (response.status !== 201 || !response.data.token) {
    throw new Error(`Normal registration failed: ${response.status}`);
  }

  for (let attempt = 0; attempt < 4; attempt++) {
    response = await api('/auth/login', { email, password: 'wrong-password' });
    if (response.status !== 401) {
      throw new Error(`Failed login was limited too early: ${response.status}`);
    }
  }

  response = await api('/auth/login', { email, password: 'password123' });
  if (response.status !== 200 || !response.data.token) {
    throw new Error(`Successful login was unnecessarily blocked: ${response.status}`);
  }

  let failedLoginsBeforeLimit = 0;
  for (let attempt = 0; attempt < 6; attempt++) {
    response = await api('/auth/login', { email, password: 'wrong-password' });
    if (response.status === 429) {
      break;
    }
    if (response.status !== 401) {
      throw new Error(`Unexpected failed-login response: ${response.status}`);
    }
    failedLoginsBeforeLimit++;
  }

  if (response.status !== 429 || failedLoginsBeforeLimit === 0 || response.data.success !== false) {
    throw new Error(`Login rate limit did not return a generic 429: ${response.status}`);
  }

  for (let attempt = 0; attempt < 9; attempt++) {
    response = await api('/auth/register', registration(`new-${attempt}-${Date.now()}@test.com`));
    if (response.status !== 201) {
      throw new Error(`Registration was limited before the configured limit: ${response.status}`);
    }
  }

  response = await api('/auth/register', registration(`blocked-${Date.now()}@test.com`));
  if (response.status !== 429 || response.data.success !== false) {
    throw new Error(`Registration rate limit did not return a generic 429: ${response.status}`);
  }

  const health = await fetch(`${BASE}/health`);
  if (health.status !== 200) {
    throw new Error(`Health check was rate limited: ${health.status}`);
  }

  console.log('Authentication rate limiting tests passed');
}

run()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(() => {
    if (server) server.kill();
  });