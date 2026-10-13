// Shared application limits for REST and Socket.IO. Reconnecting or switching
// transports must not reset a user's message allowance.
const MAX_MESSAGE_LENGTH = 4000;
const buckets = new Map();
const cleanup = setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets) if (bucket.resetAt <= now) buckets.delete(key);
}, 60000);
cleanup.unref();

function consumeQuota(category, userId, limit, windowMs = 60000) {
  const key = `${category}:${userId}`;
  const now = Date.now();
  let bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 0, resetAt: now + windowMs };
    buckets.set(key, bucket);
  }
  return ++bucket.count <= limit;
}

function validateMessage(message, clientId) {
  if (typeof message !== 'string' || !message.trim() || message.length > MAX_MESSAGE_LENGTH) {
    return `Message must contain between 1 and ${MAX_MESSAGE_LENGTH} characters`;
  }
  if (clientId != null && (typeof clientId !== 'string' || clientId.length > 128)) {
    return 'Invalid client message ID';
  }
  return null;
}

function pagination(query) {
  const integer = (value, fallback, min, max) => {
    if (value === undefined) return fallback;
    if (typeof value !== 'string' || !/^\d+$/.test(value)) return null;
    const number = Number(value);
    return Number.isSafeInteger(number) && number >= min && number <= max ? number : null;
  };
  const limit = integer(query.limit, 50, 1, 100);
  const offset = integer(query.offset, 0, 0, 100000);
  return limit === null || offset === null ? null : { limit, offset };
}

function chatReadLimiter(req, res, next) {
  if (!consumeQuota('chat-read', req.user.id, 120)) {
    return res.status(429).json({ success: false, message: 'Too many requests. Try again shortly.' });
  }
  next();
}

module.exports = { consumeQuota, validateMessage, pagination, chatReadLimiter };
