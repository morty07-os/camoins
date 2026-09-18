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

// Transport request model functions
const TransportRequestModel = {
  create(customerId, tripId, requestData) {
    const stmt = db.prepare(`
      INSERT INTO transport_requests (trip_id, customer_id, requested_weight, requested_volume,
                                      cargo_description, pickup_location, delivery_location, agreed_price, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'PENDING')
    `);

    const result = stmt.run(
      tripId,
      customerId,
      requestData.requested_weight,
      requestData.requested_volume || null,
      requestData.cargo_description || null,
      requestData.pickup_location || null,
      requestData.delivery_location || null,
      requestData.agreed_price || 'Prix à convenir'
    );

    return result.lastInsertRowid;
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, trip_id, customer_id, requested_weight, requested_volume,
             cargo_description, pickup_location, delivery_location, agreed_price,
             status, created_at, updated_at
      FROM transport_requests
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  findByCustomerId(customerId) {
    const stmt = db.prepare(`
      SELECT id, trip_id, customer_id, requested_weight, requested_volume,
             cargo_description, pickup_location, delivery_location, agreed_price,
             status, created_at, updated_at
      FROM transport_requests
      WHERE customer_id = ?
      ORDER BY created_at DESC
    `);
    return stmt.all(customerId);
  },

  findByTripId(tripId) {
    const stmt = db.prepare(`
      SELECT id, trip_id, customer_id, requested_weight, requested_volume,
             cargo_description, pickup_location, delivery_location, agreed_price,
             status, created_at, updated_at
      FROM transport_requests
      WHERE trip_id = ?
      ORDER BY created_at DESC
    `);
    return stmt.all(tripId);
  },

  findByIdWithDetails(id) {
    const stmt = db.prepare(`
      SELECT tr.id, tr.trip_id, tr.customer_id, tr.requested_weight, tr.requested_volume,
             tr.cargo_description, tr.pickup_location, tr.delivery_location, tr.agreed_price,
             tr.status, tr.created_at, tr.updated_at,
             t.*, p.full_name, p.rating, p.rating_count
      FROM transport_requests tr
      JOIN trips t ON tr.trip_id = t.id
      JOIN profiles p ON tr.customer_id = p.user_id
      WHERE tr.id = ?
    `);
    return stmt.get(id);
  },

  updateStatus(id, status) {
    const stmt = db.prepare(`
      UPDATE transport_requests
      SET status = ?, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);
    const result = stmt.run(status, id);
    return result.changes > 0;
  },

  acceptWithCapacityUpdate(requestId, tripId) {
    // Use transaction to atomically:
    // 1. Get the request and verify capacity
    // 2. Update request status to ACCEPTED
    // 3. Reduce trip capacity
    const transaction = db.transaction(() => {
      // Get request
      const request = db.prepare(`
        SELECT requested_weight, requested_volume FROM transport_requests WHERE id = ?
      `).get(requestId);

      if (!request) {
        throw new Error('Request not found');
      }

      // Get trip
      const trip = db.prepare(`
        SELECT available_weight, available_volume FROM trips WHERE id = ?
      `).get(tripId);

      if (!trip) {
        throw new Error('Trip not found');
      }

      // Check capacity
      if (trip.available_weight < request.requested_weight) {
        throw new Error('Insufficient weight capacity');
      }

      if (request.requested_volume && trip.available_volume !== null && trip.available_volume < request.requested_volume) {
        throw new Error('Insufficient volume capacity');
      }

      // Update request status
      db.prepare(`
        UPDATE transport_requests SET status = 'ACCEPTED', updated_at = CURRENT_TIMESTAMP WHERE id = ?
      `).run(requestId);

      // Update trip capacity
      const newWeight = trip.available_weight - request.requested_weight;
      const newVolume = request.requested_volume && trip.available_volume !== null
        ? trip.available_volume - request.requested_volume
        : trip.available_volume;

      db.prepare(`
        UPDATE trips SET available_weight = ?, available_volume = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?
      `).run(newWeight, newVolume, tripId);

      return true;
    });

    try {
      return transaction();
    } catch (error) {
      throw error;
    }
  },

  cancelWithCapacityRestore(requestId, tripId) {
    // Restore capacity if request was accepted
    const transaction = db.transaction(() => {
      const request = db.prepare(`
        SELECT status, requested_weight, requested_volume FROM transport_requests WHERE id = ?
      `).get(requestId);

      if (!request) {
        throw new Error('Request not found');
      }

      if (request.status === 'ACCEPTED') {
        const trip = db.prepare(`
          SELECT available_weight, available_volume FROM trips WHERE id = ?
        `).get(tripId);

        if (trip) {
          const newWeight = trip.available_weight + request.requested_weight;
          const newVolume = request.requested_volume && trip.available_volume !== null
            ? trip.available_volume + request.requested_volume
            : trip.available_volume;

          db.prepare(`
            UPDATE trips SET available_weight = ?, available_volume = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?
          `).run(newWeight, newVolume, tripId);
        }
      }

      db.prepare(`
        UPDATE transport_requests SET status = 'CANCELLED', updated_at = CURRENT_TIMESTAMP WHERE id = ?
      `).run(requestId);

      return true;
    });

    try {
      return transaction();
    } catch (error) {
      throw error;
    }
  },

  delete(id) {
    const stmt = db.prepare(`DELETE FROM transport_requests WHERE id = ?`);
    const result = stmt.run(id);
    return result.changes > 0;
  }
};

// Conversation model functions
const ConversationModel = {
  create(requestId, driverId, customerId) {
    const stmt = db.prepare(`
      INSERT INTO conversations (request_id, driver_id, customer_id)
      VALUES (?, ?, ?)
    `);

    const result = stmt.run(requestId, driverId, customerId);
    return result.lastInsertRowid;
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, request_id, driver_id, customer_id, created_at
      FROM conversations
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  findByRequestId(requestId) {
    const stmt = db.prepare(`
      SELECT id, request_id, driver_id, customer_id, created_at
      FROM conversations
      WHERE request_id = ?
    `);
    return stmt.get(requestId);
  },

  findByUserId(userId) {
    const stmt = db.prepare(`
      SELECT c.id, c.request_id, c.driver_id, c.customer_id, c.created_at,
             tr.status as request_status,
             CASE WHEN c.driver_id = ? THEN p2.full_name ELSE p1.full_name END as other_user_name,
             CASE WHEN c.driver_id = ? THEN u2.id ELSE u1.id END as other_user_id
      FROM conversations c
      JOIN transport_requests tr ON c.request_id = tr.id
      LEFT JOIN profiles p1 ON c.customer_id = p1.user_id
      LEFT JOIN profiles p2 ON c.driver_id = p2.user_id
      LEFT JOIN users u1 ON c.customer_id = u1.id
      LEFT JOIN users u2 ON c.driver_id = u2.id
      WHERE c.driver_id = ? OR c.customer_id = ?
      ORDER BY c.created_at DESC
    `);
    return stmt.all(userId, userId, userId, userId);
  }
};

// Message model functions
const MessageModel = {
  create(conversationId, senderId, message) {
    const stmt = db.prepare(`
      INSERT INTO messages (conversation_id, sender_id, message)
      VALUES (?, ?, ?)
    `);

    const result = stmt.run(conversationId, senderId, message);
    return result.lastInsertRowid;
  },

  findById(id) {
    const stmt = db.prepare(`
      SELECT id, conversation_id, sender_id, message, created_at, read_at
      FROM messages
      WHERE id = ?
    `);
    return stmt.get(id);
  },

  findByConversationId(conversationId, limit = 50, offset = 0) {
    const stmt = db.prepare(`
      SELECT m.id, m.conversation_id, m.sender_id, m.message, m.created_at, m.read_at,
             p.full_name as sender_name
      FROM messages m
      LEFT JOIN profiles p ON m.sender_id = p.user_id
      WHERE m.conversation_id = ?
      ORDER BY m.created_at DESC
      LIMIT ? OFFSET ?
    `);
    return stmt.all(conversationId, limit, offset).reverse();
  },

  markAsRead(messageId) {
    const stmt = db.prepare(`
      UPDATE messages
      SET read_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `);
    const result = stmt.run(messageId);
    return result.changes > 0;
  },

  markConversationAsRead(conversationId, userId) {
    const stmt = db.prepare(`
      UPDATE messages
      SET read_at = CURRENT_TIMESTAMP
      WHERE conversation_id = ? AND sender_id != ? AND read_at IS NULL
    `);
    const result = stmt.run(conversationId, userId);
    return result.changes;
  },

  getUnreadCount(conversationId, userId) {
    const stmt = db.prepare(`
      SELECT COUNT(*) as count
      FROM messages
      WHERE conversation_id = ? AND sender_id != ? AND read_at IS NULL
    `);
    return stmt.get(conversationId, userId);
  },

  getLastMessage(conversationId) {
    const stmt = db.prepare(`
      SELECT id, conversation_id, sender_id, message, created_at, read_at,
             p.full_name as sender_name
      FROM messages m
      LEFT JOIN profiles p ON m.sender_id = p.user_id
      WHERE m.conversation_id = ?
      ORDER BY m.created_at DESC
      LIMIT 1
    `);
    return stmt.get(conversationId);
  }
};

module.exports = { UserModel, ProfileModel, TruckModel, TripModel, CargaisonModel, TransportRequestModel, ConversationModel, MessageModel };
