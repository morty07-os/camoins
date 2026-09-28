const jwt = require('jsonwebtoken');
const db = require('./database');

const DEVELOPMENT_JWT_SECRET = 'backhaul-secret-key-change-in-production';
const isProduction = process.env.NODE_ENV === 'production';

if (isProduction && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET is required when NODE_ENV=production. Configure it before starting the backend.');
}

const JWT_SECRET = process.env.JWT_SECRET || DEVELOPMENT_JWT_SECRET;
const JWT_EXPIRES_IN = '7d';

function generateToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
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
  next();
}

module.exports = { generateToken, verifyToken, authMiddleware };
