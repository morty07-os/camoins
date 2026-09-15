const bcrypt = require('bcrypt');
const db = require('./database');

// User queries
const insertUser = db.prepare(`
  INSERT INTO users (email, password_hash, role)
  VALUES (?, ?, ?)
`);

const findUserByEmail = db.prepare(`
  SELECT id, email, role, created_at
  FROM users
  WHERE email = ?
`);

const findUserByEmailWithPassword = db.prepare(`
  SELECT id, email, password_hash, role, created_at
  FROM users
  WHERE email = ?
`);

const findUserById = db.prepare(`
  SELECT id, email, role, created_at
  FROM users
  WHERE id = ?
`);

// Profile queries
const insertProfile = db.prepare(`
  INSERT INTO profiles (user_id, full_name, phone, city, wilaya)
  VALUES (?, ?, ?, ?, ?)
`);

const findProfileByUserId = db.prepare(`
  SELECT id, user_id, full_name, phone, city, wilaya, profile_image, rating, rating_count, created_at, updated_at
  FROM profiles
  WHERE user_id = ?
`);

const updateProfile = db.prepare(`
  UPDATE profiles
  SET full_name = ?, phone = ?, city = ?, wilaya = ?, updated_at = CURRENT_TIMESTAMP
  WHERE user_id = ?
`);

// User model functions
const UserModel = {
  async create(email, password, role, profileData) {
    const passwordHash = await bcrypt.hash(password, 10);

    const transaction = db.transaction(() => {
      const result = insertUser.run(email, passwordHash, role);
      const userId = result.lastInsertRowid;

      insertProfile.run(
        userId,
        profileData.full_name,
        profileData.phone || null,
        profileData.city || null,
        profileData.wilaya || null
      );

      return userId;
    });

    return transaction();
  },

  findByEmail(email) {
    return findUserByEmail.get(email);
  },

  findById(id) {
    return findUserById.get(id);
  },

  async verifyPassword(email, password) {
    const user = findUserByEmailWithPassword.get(email);
    if (!user) {
      return null;
    }

    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return null;
    }

    // Return user without password hash
    const { password_hash, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }
};

// Profile model functions
const ProfileModel = {
  findByUserId(userId) {
    return findProfileByUserId.get(userId);
  },

  update(userId, profileData) {
    const result = updateProfile.run(
      profileData.full_name,
      profileData.phone || null,
      profileData.city || null,
      profileData.wilaya || null,
      userId
    );
    return result.changes > 0;
  }
};

// Truck model functions
const TruckModel = {
  create(driverId, truckData) {
    const stmt = db.prepare(`
      INSERT INTO trucks (driver_id, truck_type, brand, model, max_weight, max_volume, registration_number, image_url)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      driverId,
      truckData.truck_type,
      truckData.brand || null,
      truckData.model || null,
      truckData.max_weight,
      truckData.max_volume || null,
      truckData.registration_number || null,
      truckData.image_url || null
    );

    return result.lastInsertRowid;
  },

  findByDriverId(driverId) {
    const stmt = db.prepare(`
      SELECT id, driver_id, truck_type, brand, model, max_weight, max_volume,
             registration_number, image_url, created_at, updated_at
      FROM trucks
      WHERE driver_id = ?
      ORDER BY created_at DESC
    `);
    return stmt.all(driverId);
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, driver_id, truck_type, brand, model, max_weight, max_volume,
             registration_number, image_url, created_at, updated_at
      FROM trucks
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  update(id, truckData) {
    const stmt = db.prepare(`
      UPDATE trucks
      SET truck_type = ?, brand = ?, model = ?, max_weight = ?, max_volume = ?,
          registration_number = ?, image_url = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);

    const result = stmt.run(
      truckData.truck_type,
      truckData.brand || null,
      truckData.model || null,
      truckData.max_weight,
      truckData.max_volume || null,
      truckData.registration_number || null,
      truckData.image_url || null,
      id
    );

    return result.changes > 0;
  },

  delete(id) {
    const stmt = db.prepare(`DELETE FROM trucks WHERE id = ?`);
    const result = stmt.run(id);
    return result.changes > 0;
  }
};

// Trip model functions
const TripModel = {
  create(driverId, tripData) {
    const stmt = db.prepare(`
      INSERT INTO trips (driver_id, truck_id, origin_name, origin_lat, origin_lng,
                         destination_name, destination_lat, destination_lng,
                         departure_date, available_weight, available_volume,
                         trip_type, status, description)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      driverId,
      tripData.truck_id,
      tripData.origin_name,
      tripData.origin_lat ?? null,
      tripData.origin_lng ?? null,
      tripData.destination_name,
      tripData.destination_lat ?? null,
      tripData.destination_lng ?? null,
      tripData.departure_date,
      tripData.available_weight,
      tripData.available_volume ?? null,
      tripData.trip_type || 'RETURN',
      tripData.status || 'PUBLISHED',
      tripData.description || null
    );

    return result.lastInsertRowid;
  },

  findByDriverId(driverId) {
    const stmt = db.prepare(`
      SELECT id, driver_id, truck_id, origin_name, origin_lat, origin_lng,
             destination_name, destination_lat, destination_lng,
             departure_date, available_weight, available_volume,
             trip_type, status, description, created_at, updated_at
      FROM trips
      WHERE driver_id = ?
      ORDER BY created_at DESC
    `);
    return stmt.all(driverId);
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, driver_id, truck_id, origin_name, origin_lat, origin_lng,
             destination_name, destination_lat, destination_lng,
             departure_date, available_weight, available_volume,
             trip_type, status, description, created_at, updated_at
      FROM trips
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  update(id, tripData) {
    const stmt = db.prepare(`
      UPDATE trips
      SET truck_id = ?, origin_name = ?, origin_lat = ?, origin_lng = ?,
          destination_name = ?, destination_lat = ?, destination_lng = ?,
          departure_date = ?, available_weight = ?, available_volume = ?,
          description = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);

    const result = stmt.run(
      tripData.truck_id,
      tripData.origin_name,
      tripData.origin_lat ?? null,
      tripData.origin_lng ?? null,
      tripData.destination_name,
      tripData.destination_lat ?? null,
      tripData.destination_lng ?? null,
      tripData.departure_date,
      tripData.available_weight,
      tripData.available_volume ?? null,
      tripData.description || null,
      id
    );

    return result.changes > 0;
  },

  updateStatus(id, status) {
    const stmt = db.prepare(`
      UPDATE trips
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);
    const result = stmt.run(status, id);
    return result.changes > 0;
  },

  delete(id) {
    const stmt = db.prepare(`DELETE FROM trips WHERE id = ?`);
    const result = stmt.run(id);
    return result.changes > 0;
  }
};

// Cargaison model functions
const CargaisonModel = {
  create(driverId, data) {
    const stmt = db.prepare(`
      INSERT INTO cargaisons (driver_id, trip_id, origin_name, destination_name, cargo_type, weight, description, status, customer_name, customer_phone)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const result = stmt.run(
      driverId,
      data.trip_id || null,
      data.origin_name,
      data.destination_name,
      data.cargo_type,
      data.weight,
      data.description || null,
      data.status || 'AVAILABLE',
      data.customer_name || null,
      data.customer_phone || null
    );

    return result.lastInsertRowid;
  },

  findByDriverId(driverId) {
    const stmt = db.prepare(`
      SELECT id, driver_id, trip_id, origin_name, destination_name, cargo_type,
             weight, description, status, customer_name, customer_phone,
             created_at, updated_at
      FROM cargaisons
      WHERE driver_id = ?
      ORDER BY created_at DESC
    `);
    return stmt.all(driverId);
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, driver_id, trip_id, origin_name, destination_name, cargo_type,
             weight, description, status, customer_name, customer_phone,
             created_at, updated_at
      FROM cargaisons
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  update(id, data) {
    const stmt = db.prepare(`
      UPDATE cargaisons
      SET origin_name = ?, destination_name = ?, cargo_type = ?, weight = ?,
          description = ?, customer_name = ?, customer_phone = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);

    const result = stmt.run(
      data.origin_name,
      data.destination_name,
      data.cargo_type,
      data.weight,
      data.description || null,
      data.customer_name || null,
      data.customer_phone || null,
      id
    );

    return result.changes > 0;
  },

  updateStatus(id, status, tripId) {
    let stmt;
    if (tripId !== undefined) {
      stmt = db.prepare(`
        UPDATE cargaisons
        SET status = ?, trip_id = ?, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
      `);
      const result = stmt.run(status, tripId, id);
      return result.changes > 0;
    }
    stmt = db.prepare(`
      UPDATE cargaisons
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);
    const result = stmt.run(status, id);
    return result.changes > 0;
  },

  delete(id) {
    const stmt = db.prepare(`DELETE FROM cargaisons WHERE id = ?`);
    const result = stmt.run(id);
    return result.changes > 0;
  }
};

module.exports = { UserModel, ProfileModel, TruckModel, TripModel, CargaisonModel };
