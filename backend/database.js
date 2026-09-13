const Database = require('better-sqlite3');
const path = require('path');

// Initialize database
const db = new Database(path.join(__dirname, 'backhaul.db'));

// Enable foreign keys
db.pragma('foreign_keys = ON');

// Create tables
function initializeDatabase() {
  // Users table
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL CHECK(role IN ('DRIVER', 'CUSTOMER')),
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  // Profiles table
  db.exec(`
    CREATE TABLE IF NOT EXISTS profiles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL UNIQUE,
      full_name TEXT NOT NULL,
      phone TEXT,
      city TEXT,
      wilaya TEXT,
      profile_image TEXT,
      rating REAL DEFAULT 0,
      rating_count INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  console.log('✓ Database tables initialized');
}

// Initialize on load
initializeDatabase();

module.exports = db;
