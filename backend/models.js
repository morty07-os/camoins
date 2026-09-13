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

module.exports = { UserModel, ProfileModel };
