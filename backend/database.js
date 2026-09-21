const Database = require('better-sqlite3');
const path = require('path');

// Initialize database
const dbPath = process.env.DB_PATH || path.join(__dirname, 'backhaul.db');
const db = new Database(dbPath);

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

  // Trucks table
  db.exec(`
    CREATE TABLE IF NOT EXISTS trucks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      driver_id INTEGER NOT NULL,
      truck_type TEXT NOT NULL CHECK(truck_type IN ('FLATBED', 'TARP', 'REFRIGERATED', 'VAN', 'SEMI_TRAILER', 'OTHER')),
      brand TEXT,
      model TEXT,
      max_weight REAL NOT NULL,
      max_volume REAL,
      registration_number TEXT,
      image_url TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Trips table
  db.exec(`
    CREATE TABLE IF NOT EXISTS trips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      driver_id INTEGER NOT NULL,
      truck_id INTEGER NOT NULL,
      origin_name TEXT NOT NULL,
      origin_lat REAL,
      origin_lng REAL,
      destination_name TEXT NOT NULL,
      destination_lat REAL,
      destination_lng REAL,
      departure_date TEXT NOT NULL,
      available_weight REAL NOT NULL,
      available_volume REAL,
      trip_type TEXT NOT NULL CHECK(trip_type IN ('RETURN')),
      status TEXT NOT NULL DEFAULT 'PUBLISHED' CHECK(status IN ('PUBLISHED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
      description TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (truck_id) REFERENCES trucks(id) ON DELETE CASCADE
    )
  `);

  // Cargaisons table
  db.exec(`
    CREATE TABLE IF NOT EXISTS cargaisons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      driver_id INTEGER NOT NULL,
      trip_id INTEGER,
      origin_name TEXT NOT NULL,
      destination_name TEXT NOT NULL,
      cargo_type TEXT NOT NULL,
      weight REAL NOT NULL,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'AVAILABLE' CHECK(status IN ('AVAILABLE', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED')),
      customer_name TEXT,
      customer_phone TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL
    )
  `);

  // Transport requests table
  db.exec(`
    CREATE TABLE IF NOT EXISTS transport_requests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      requested_weight REAL NOT NULL,
      requested_volume REAL,
      cargo_description TEXT,
      pickup_location TEXT,
      delivery_location TEXT,
      agreed_price TEXT,
      status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED', 'COMPLETED')),
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Conversations table
  db.exec(`
    CREATE TABLE IF NOT EXISTS conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      request_id INTEGER,
      driver_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (request_id) REFERENCES transport_requests(id) ON DELETE CASCADE,
      FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(driver_id, customer_id)
    )
  `);

  // Messages table
  db.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      sender_id INTEGER NOT NULL,
      message TEXT NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      read_at DATETIME,
      FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE,
      FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Notifications table
  db.exec(`
    CREATE TABLE IF NOT EXISTS notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      type TEXT NOT NULL,
      related_id INTEGER,
      conversation_id INTEGER,
      trip_id INTEGER,
      request_id INTEGER,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )
  `);

  // Ratings table
  db.exec(`
    CREATE TABLE IF NOT EXISTS ratings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL,
      request_id INTEGER NOT NULL,
      reviewer_id INTEGER NOT NULL,
      reviewed_user_id INTEGER NOT NULL,
      rating INTEGER NOT NULL CHECK(rating BETWEEN 1 AND 5),
      comment TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE,
      FOREIGN KEY (request_id) REFERENCES transport_requests(id) ON DELETE CASCADE,
      FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (reviewed_user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(request_id, reviewer_id)
    )
  `);

  migrateConversations();

  // Migration: Add missing columns if they don't exist (for existing databases)
  const columns = db.prepare("PRAGMA table_info(notifications)").all();
  const columnNames = columns.map(c => c.name);
  if (!columnNames.includes('conversation_id')) {
    db.exec('ALTER TABLE notifications ADD COLUMN conversation_id INTEGER');
  }
  if (!columnNames.includes('trip_id')) {
    db.exec('ALTER TABLE notifications ADD COLUMN trip_id INTEGER');
  }
  if (!columnNames.includes('request_id')) {
    db.exec('ALTER TABLE notifications ADD COLUMN request_id INTEGER');
  }

  console.log('✓ Database tables initialized');
}

function migrateConversations() {
  const columns = db.prepare('PRAGMA table_info(conversations)').all();
  const requestColumn = columns.find(column => column.name === 'request_id');
  const indexes = db.prepare('PRAGMA index_list(conversations)').all();
  const hasPairUniqueIndex = indexes.some(index => {
    if (!index.unique) return false;
    const indexedColumns = db.prepare(`PRAGMA index_info('${index.name.replace(/'/g, "''")}')`).all();
    return indexedColumns.map(column => column.name).join(',') === 'driver_id,customer_id';
  });

  if (requestColumn && requestColumn.notnull === 0 && hasPairUniqueIndex) return;

  db.pragma('foreign_keys = OFF');
  try {
    db.transaction(() => {
      db.exec(`
        ALTER TABLE conversations RENAME TO conversations_legacy;
        CREATE TABLE conversations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          request_id INTEGER,
          driver_id INTEGER NOT NULL,
          customer_id INTEGER NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (request_id) REFERENCES transport_requests(id) ON DELETE CASCADE,
          FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE(driver_id, customer_id)
        );
        INSERT INTO conversations (id, request_id, driver_id, customer_id, created_at)
        SELECT c.id, c.request_id, c.driver_id, c.customer_id, c.created_at
        FROM conversations_legacy c
        WHERE c.id = (
          SELECT c2.id FROM conversations_legacy c2
          WHERE c2.driver_id = c.driver_id AND c2.customer_id = c.customer_id
          ORDER BY c2.created_at DESC, c2.id DESC LIMIT 1
        );
        CREATE TEMP TABLE conversation_id_map AS
        SELECT legacy.id AS legacy_id, canonical.id AS canonical_id
        FROM conversations_legacy legacy
        JOIN conversations canonical
          ON canonical.driver_id = legacy.driver_id
         AND canonical.customer_id = legacy.customer_id;
        UPDATE messages
        SET conversation_id = (
          SELECT canonical_id FROM conversation_id_map
          WHERE legacy_id = messages.conversation_id
        )
        WHERE conversation_id IN (SELECT legacy_id FROM conversation_id_map);
        UPDATE notifications
        SET conversation_id = (
          SELECT canonical_id FROM conversation_id_map
          WHERE legacy_id = notifications.conversation_id
        )
        WHERE conversation_id IN (SELECT legacy_id FROM conversation_id_map);
        DROP TABLE conversations_legacy;
        DROP TABLE conversation_id_map;
      `);
    })();
  } finally {
    db.pragma('foreign_keys = ON');
  }
}

// Initialize on load
initializeDatabase();

module.exports = db;
