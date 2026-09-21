const { spawn } = require('child_process');
const path = require('path');
const os = require('os');

const PORT = 5300;
const BASE = `http://localhost:${PORT}`;
const DB_PATH = path.join(os.tmpdir(), `backhaul-cors-test-${Date.now()}.db`);
const trustedOrigin = 'https://frontend.example.test';
const untrustedOrigin = 'https://attacker.example.test';

let server;
let passed = 0;
let failed = 0;

function report(name, ok, detail = '') {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}${detail ? ` - ${detail}` : ''}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` - ${detail}` : ''}`);
  }
}

async function request(pathname, options = {}) {
  const response = await fetch(`${BASE}${pathname}`, options);
  return {
    status: response.status,
    allowOrigin: response.headers.get('access-control-allow-origin'),
  };
}

async function run() {
  server = spawn('node', [path.join(__dirname, '..', 'server.js')], {
    env: {
      ...process.env,
      PORT: String(PORT),
      DB_PATH,
      FRONTEND_URLS: trustedOrigin,
    },
    stdio: 'ignore',
  });

  let up = false;
  for (let attempt = 0; attempt < 40; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    try {
      const response = await fetch(`${BASE}/api/health`);
      if (response.ok) {
        up = true;
        break;
      }
    } catch (_) {}
  }

  if (!up) {
    console.error('Server failed to start');
    process.exitCode = 1;
    return;
  }

  let response = await request('/api/health', {
    headers: { Origin: trustedOrigin },
  });
  report('trusted REST origin is allowed', response.status === 200 && response.allowOrigin === trustedOrigin);

  response = await request('/api/health', {
    headers: { Origin: untrustedOrigin },
  });
  report('untrusted REST origin is rejected', response.allowOrigin === null);

  response = await request('/api/health');
  report('requests without Origin still work', response.status === 200 && response.allowOrigin === null);

  response = await request('/socket.io/?EIO=4&transport=polling', {
    headers: { Origin: trustedOrigin },
  });
  report('trusted Socket.IO origin is allowed', response.status === 200 && response.allowOrigin === trustedOrigin);

  response = await request('/socket.io/?EIO=4&transport=polling', {
    headers: { Origin: untrustedOrigin },
  });
  report('untrusted Socket.IO origin is rejected', response.status >= 400 || response.allowOrigin === null);
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => {
    if (server) server.kill();
    console.log(`\n${passed} passed, ${failed} failed`);
    if (failed > 0) process.exitCode = 1;
  });