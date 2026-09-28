const { UserModel } = require('../models');

async function main() {
  const [email, password, fullName = 'Camoins Admin'] = process.argv.slice(2);
  if (!email || !password || password.length < 8) {
    console.error('Usage: npm run create-admin -- <email> <password-min-8-chars> [full-name]');
    process.exitCode = 1;
    return;
  }
  if (UserModel.findByEmail(email.trim().toLowerCase())) {
    console.error('An account with this email already exists.');
    process.exitCode = 1;
    return;
  }
  const userId = await UserModel.create(email.trim().toLowerCase(), password, 'ADMIN', {
    full_name: fullName,
  });
  console.log(`Admin account created with id ${userId}.`);
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
