const jwt = require('jsonwebtoken');
const { createHash, randomUUID } = require('node:crypto');
const db = require('./database');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || Buffer.byteLength(JWT_SECRET) < 32 || JWT_SECRET === 'backhaul-secret-key-change-in-production') {
  throw new Error('Set JWT_SECRET to a unique random secret of at least 32 bytes before starting the backend.');
}
const JWT_EXPIRES_IN = '12h';
const tokenFingerprint = token => createHash('sha256').update(token).digest('hex');

function generateToken(user) {
  db.prepare('DELETE FROM revoked_tokens WHERE expires_at <= ?').run(Math.floor(Date.now() / 1000));
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN, algorithm: 'HS256', jwtid: randomUUID() }
  );
}

function verifyToken(token) {
  try {
    const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
    if (!Number.isSafeInteger(decoded.id) || decoded.id <= 0 || !Number.isSafeInteger(decoded.exp)) return null;
    if (db.prepare('SELECT 1 FROM revoked_tokens WHERE token_hash = ?').get(tokenFingerprint(token))) return null;
    return decoded;
  } catch (error) {
    return null;
  }
}

function revokeToken(token, expiresAt) {
  db.prepare('DELETE FROM revoked_tokens WHERE expires_at <= ?').run(Math.floor(Date.now() / 1000));
  db.prepare('INSERT OR IGNORE INTO revoked_tokens (token_hash, expires_at) VALUES (?, ?)')
    .run(tokenFingerprint(token), expiresAt);
}

function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: 'No token provided'
    });
  }

  const token = authHeader.substring(7);
  const decoded = verifyToken(token);

  if (!decoded) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token'
    });
  }

  const currentUser = db.prepare('SELECT id, email, role FROM users WHERE id = ?').get(decoded.id);
  if (!currentUser) {
    return res.status(401).json({ success: false, message: 'Account no longer exists' });
  }
  req.user = currentUser;
  req.authToken = token;
  req.authExpiresAt = decoded.exp;
  next();
}

module.exports = { generateToken, verifyToken, authMiddleware, revokeToken, tokenFingerprint };
