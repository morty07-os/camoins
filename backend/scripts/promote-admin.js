const db = require('../database');
const { UserModel } = require('../models');

function main() {
  const email = process.argv[2]?.trim().toLowerCase();
  if (!email) {
    console.error('Usage: npm run promote-admin -- <existing-user-email>');
    process.exitCode = 1;
    return;
  }

  const user = UserModel.findByEmail(email);
  if (!user) {
    console.error('No existing user was found with that email.');
    process.exitCode = 1;
    return;
  }
  if (user.role === 'ADMIN') {
    console.log(`Account ${email} is already an admin.`);
    return;
  }

  const previousRole = user.role;
  db.prepare("UPDATE users SET role = 'ADMIN' WHERE id = ?").run(user.id);
  console.log(`Account ${email} was promoted from ${previousRole} to ADMIN.`);
  console.log('Log out and sign in again to open the admin dashboard.');
}

main();
