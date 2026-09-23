const Database = require('better-sqlite3');
const path = require('path');
const fs = require('fs');

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
      request_id INTEGER NOT NULL,
      driver_id INTEGER NOT NULL,
      customer_id INTEGER NOT NULL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (request_id) REFERENCES transport_requests(id) ON DELETE CASCADE,
      FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE(request_id)
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

  migrateCompletion();

  // Guards apply to existing databases too. Submitted ratings are immutable.
  db.exec(`
    CREATE TRIGGER IF NOT EXISTS ratings_validate_insert BEFORE INSERT ON ratings
    BEGIN
      SELECT CASE WHEN typeof(NEW.rating) != 'integer' OR NEW.rating NOT BETWEEN 1 AND 5
        THEN RAISE(ABORT, 'Rating must be an integer between 1 and 5') END;
      SELECT CASE WHEN NEW.reviewer_id = NEW.reviewed_user_id OR NOT EXISTS (
        SELECT 1 FROM transport_requests r JOIN trips t ON t.id = r.trip_id
        WHERE r.id = NEW.request_id AND t.id = NEW.trip_id AND r.status = 'COMPLETED'
          AND ((NEW.reviewer_id = r.customer_id AND NEW.reviewed_user_id = t.driver_id)
            OR (NEW.reviewer_id = t.driver_id AND NEW.reviewed_user_id = r.customer_id))
      ) THEN RAISE(ABORT, 'Invalid completed transport participants') END;
    END;
    CREATE TRIGGER IF NOT EXISTS ratings_no_update BEFORE UPDATE ON ratings
    BEGIN SELECT RAISE(ABORT, 'Ratings cannot be edited'); END;
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

  initializeIndexes();

  console.log('✓ Database tables initialized');
}

// Rebuild the CHECK constraint without changing any existing request or child row.
function migrateCompletion() {
  const schema = db.prepare("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'transport_requests'").get().sql;
  if (!schema.includes('AWAITING_CUSTOMER_CONFIRMATION')) {
    db.pragma('foreign_keys = OFF');
    try {
      db.transaction(() => {
        const objects = db.prepare("SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL AND (type = 'trigger' OR (type = 'index' AND tbl_name = 'transport_requests'))").all();
        for (const object of objects.filter(o => o.type === 'trigger')) {
          db.exec(`DROP TRIGGER "${object.name.replace(/"/g, '""')}"`);
        }
        db.exec(schema.replace(/CREATE TABLE ["`]?transport_requests["`]?/i, 'CREATE TABLE transport_requests_completion')
          .replace("'ACCEPTED',", "'ACCEPTED', 'AWAITING_CUSTOMER_CONFIRMATION',"));
        db.exec(`INSERT INTO transport_requests_completion SELECT * FROM transport_requests;
          DROP TABLE transport_requests;
          ALTER TABLE transport_requests_completion RENAME TO transport_requests;`);
        for (const object of objects) db.exec(object.sql);
        if (db.pragma('foreign_key_check').length) throw new Error('Completion migration foreign key check failed');
      }).immediate();
    } finally {
      db.pragma('foreign_keys = ON');
    }
  }
  const columns = db.pragma('table_info(transport_requests)').map(c => c.name);
  for (const column of ['driver_finished_at', 'customer_confirmed_at']) {
    if (!columns.includes(column)) db.exec(`ALTER TABLE transport_requests ADD COLUMN ${column} TEXT`);
  }
  if (!db.pragma('table_info(messages)').some(c => c.name === 'is_system')) {
    db.exec('ALTER TABLE messages ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0');
  }
}

function initializeIndexes() {
  db.exec(`
    CREATE INDEX IF NOT EXISTS idx_trucks_driver_created
      ON trucks (driver_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_trips_driver_created
      ON trips (driver_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_cargaisons_driver_created
      ON cargaisons (driver_id, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_transport_requests_trip_status
      ON transport_requests (trip_id, status);
    CREATE INDEX IF NOT EXISTS idx_transport_requests_customer_status_created
      ON transport_requests (customer_id, status, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_conversations_driver
      ON conversations (driver_id);
    CREATE INDEX IF NOT EXISTS idx_conversations_customer
      ON conversations (customer_id);

    CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
      ON messages (conversation_id, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
      ON notifications (user_id, is_read, created_at DESC);

    CREATE INDEX IF NOT EXISTS idx_ratings_reviewed_created
      ON ratings (reviewed_user_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_ratings_reviewer_created
      ON ratings (reviewer_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_ratings_trip_created
      ON ratings (trip_id, created_at DESC);
  `);
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
  const hasRequestUniqueIndex = indexes.some(index => {
    if (!index.unique) return false;
    const indexedColumns = db.prepare(`PRAGMA index_info('${index.name.replace(/'/g, "''")}')`).all();
    return indexedColumns.map(column => column.name).join(',') === 'request_id';
  });

  if (requestColumn && requestColumn.notnull === 1 && hasRequestUniqueIndex && !hasPairUniqueIndex) return;

  const backupPath = `${dbPath}.pre-conversation-migration-${Date.now()}.bak`;
  fs.copyFileSync(dbPath, backupPath);

  db.pragma('foreign_keys = OFF');
  try {
    db.transaction(() => {
      db.exec(`
        CREATE TABLE conversation_archive (
          id INTEGER PRIMARY KEY,
          request_id INTEGER,
          driver_id INTEGER NOT NULL,
          customer_id INTEGER NOT NULL,
          created_at DATETIME,
          archived_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          archive_reason TEXT NOT NULL
        );
        CREATE TABLE message_archive (
          id INTEGER PRIMARY KEY,
          conversation_id INTEGER NOT NULL,
          sender_id INTEGER NOT NULL,
          message TEXT NOT NULL,
          created_at DATETIME,
          read_at DATETIME,
          archived_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE notification_archive (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          type TEXT NOT NULL,
          related_id INTEGER,
          conversation_id INTEGER,
          trip_id INTEGER,
          request_id INTEGER,
          is_read INTEGER NOT NULL,
          created_at DATETIME,
          archived_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE conversations_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          request_id INTEGER NOT NULL,
          driver_id INTEGER NOT NULL,
          customer_id INTEGER NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (request_id) REFERENCES transport_requests(id) ON DELETE CASCADE,
          FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE(request_id)
        );
        CREATE TEMP TABLE conversation_id_map
        (legacy_id INTEGER PRIMARY KEY, canonical_id INTEGER NOT NULL);
      `);

      const legacyConversations = db.prepare(`
        SELECT c.*, tr.id AS matching_request_id
        FROM conversations c
        LEFT JOIN transport_requests tr
          ON tr.id = c.request_id
         AND tr.customer_id = c.customer_id
         AND tr.trip_id IN (SELECT id FROM trips WHERE driver_id = c.driver_id)
        ORDER BY c.id
      `).all();
      const validByRequest = new Map();
      const insertConversation = db.prepare(`
        INSERT INTO conversations_new (id, request_id, driver_id, customer_id, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
      `);
      const mapConversation = db.prepare(
        'INSERT INTO conversation_id_map (legacy_id, canonical_id) VALUES (?, ?)',
      );
      const archiveConversation = db.prepare(`
        INSERT OR REPLACE INTO conversation_archive
          (id, request_id, driver_id, customer_id, created_at, archive_reason)
        VALUES (?, ?, ?, ?, ?, ?)
      `);

      for (const conversation of legacyConversations) {
        if (conversation.matching_request_id === null) {
          archiveConversation.run(
            conversation.id,
            conversation.request_id,
            conversation.driver_id,
            conversation.customer_id,
            conversation.created_at,
            conversation.request_id === null ? 'missing_request_id' : 'invalid_request_participants',
          );
          continue;
        }

        let canonical = validByRequest.get(conversation.request_id);
        if (!canonical) {
          canonical = conversation;
          validByRequest.set(conversation.request_id, canonical);
          insertConversation.run(
            conversation.id,
            conversation.request_id,
            conversation.driver_id,
            conversation.customer_id,
            conversation.created_at,
          );
        } else {
          archiveConversation.run(
            conversation.id,
            conversation.request_id,
            conversation.driver_id,
            conversation.customer_id,
            conversation.created_at,
            'duplicate_request_id_merged_into_lowest_id',
          );
        }
        mapConversation.run(conversation.id, canonical.id);
      }

      db.exec(`
        INSERT INTO message_archive (id, conversation_id, sender_id, message, created_at, read_at)
        SELECT m.id, m.conversation_id, m.sender_id, m.message, m.created_at, m.read_at
        FROM messages m
        WHERE m.conversation_id NOT IN (SELECT legacy_id FROM conversation_id_map);
        INSERT INTO notification_archive
          (id, user_id, title, body, type, related_id, conversation_id, trip_id, request_id, is_read, created_at)
        SELECT n.id, n.user_id, n.title, n.body, n.type, n.related_id, n.conversation_id,
               n.trip_id, n.request_id, n.is_read, n.created_at
        FROM notifications n
        WHERE n.conversation_id IS NOT NULL
          AND n.conversation_id NOT IN (SELECT legacy_id FROM conversation_id_map);
        UPDATE messages
        SET conversation_id = (
          SELECT canonical_id FROM conversation_id_map
          WHERE legacy_id = messages.conversation_id
        )
        WHERE conversation_id IN (SELECT legacy_id FROM conversation_id_map);
        DELETE FROM messages
        WHERE conversation_id NOT IN (SELECT canonical_id FROM conversation_id_map);
        UPDATE notifications
        SET conversation_id = (
          SELECT canonical_id FROM conversation_id_map
          WHERE legacy_id = notifications.conversation_id
        )
        WHERE conversation_id IN (SELECT legacy_id FROM conversation_id_map);
        UPDATE notifications
        SET conversation_id = NULL
        WHERE conversation_id IS NOT NULL
          AND conversation_id NOT IN (SELECT canonical_id FROM conversation_id_map);
        DROP TABLE conversations;
        ALTER TABLE conversations_new RENAME TO conversations;
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
