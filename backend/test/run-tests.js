const { spawnSync } = require('node:child_process');
const { readdirSync } = require('node:fs');
const path = require('node:path');

let failed = false;
for (const file of readdirSync(__dirname).filter(file => file.endsWith('.test.js')).sort()) {
  console.log(`\nRunning ${file}`);
  const result = spawnSync(process.execPath, [path.join(__dirname, file)], {
    stdio: 'inherit',
    timeout: 120000,
  });
  if (result.error) console.error(result.error.message);
  if (result.status !== 0) failed = true;
}
process.exitCode = failed ? 1 : 0;
