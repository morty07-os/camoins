require('dotenv').config();
const express = require('express');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const http = require('http');
const socketIo = require('socket.io');
const db = require('./database');
const Completion = require('./completion');
const { UserModel, ProfileModel, TruckModel, TripModel, CargaisonModel, TransportRequestModel, ConversationModel, MessageModel, NotificationModel, RatingModel } = require('./models');
const { generateToken, authMiddleware, verifyToken } = require('./auth');

const localFrontendOriginPattern = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
const configuredFrontendOrigins = (process.env.FRONTEND_URLS || process.env.FRONTEND_URL || '')
  .split(',')
  .map((origin) => origin.trim().replace(/\/$/, ''))
  .filter(Boolean);

function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (configuredFrontendOrigins.includes(origin)) return true;
  return configuredFrontendOrigins.length === 0 && localFrontendOriginPattern.test(origin);
}

function corsOrigin(origin, callback) {
  if (isAllowedOrigin(origin)) {
    return callback(null, true);
  }
  return callback(new Error('Origin not allowed by CORS'));
}

const corsOptions = {
  origin: corsOrigin,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']
};

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: corsOptions
});
const PORT = process.env.PORT || 5000;

// Middleware
app.set('trust proxy', process.env.TRUST_PROXY === 'true' ? 1 : false);
app.use(cors(corsOptions));
app.use(express.json());

const authRateLimitResponse = {
  success: false,
  message: 'Too many authentication attempts. Please try again later.'
};

const loginRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  handler: (req, res) => res.status(429).json(authRateLimitResponse)
});

const registrationRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => res.status(429).json(authRateLimitResponse)
});

// ============================================
// NOTIFICATION HELPER FUNCTIONS
// ============================================

// Create notification for a user
async function createNotification(userId, title, body, type, relatedId = null, conversationId = null, tripId = null, requestId = null) {
  try {
    // Create in database
    const notificationId = NotificationModel.create(userId, {
      title,
      body,
      type,
      related_id: relatedId,
      conversation_id: conversationId,
      trip_id: tripId,
      request_id: requestId
    });

    // Get the created notification
    const notification = NotificationModel.findById(notificationId);

    // Ensure timestamp is ISO 8601 UTC for WebSocket emission
    if (notification && notification.created_at) {
      const dt = new Date(notification.created_at);
      if (!isNaN(dt.getTime())) {
        notification.created_at = dt.toISOString();
      }
    }

    // Send real-time notification via WebSocket if user is connected
    // We can emit to a user-specific room
    io.to(`user-${userId}`).emit('notification', notification);

    return notification;
  } catch (error) {
    console.error('Create notification error:', error);
    return null;
  }
}

// Create notifications for multiple users
async function createNotifications(userIds, title, body, type, relatedId = null, conversationId = null, tripId = null, requestId = null) {
  for (const userId of userIds) {
    await createNotification(userId, title, body, type, relatedId, conversationId, tripId, requestId);
  }
}

// Notification types
const NOTIFICATION_TYPES = {
  REQUEST_ACCEPTED: 'request_accepted',
  REQUEST_REJECTED: 'request_rejected',
  REQUEST_CANCELLED: 'request_cancelled',
  TRIP_STARTED: 'trip_started',
  TRIP_COMPLETED: 'trip_completed',
  NEW_MESSAGE: 'new_message',
  NEW_REQUEST: 'new_request',
  TRIP_CANCELLED: 'trip_cancelled',
  NEW_RATING: 'new_rating'
};

// ============================================
// FIREBASE CLOUD MESSAGING PREPARATION
// ============================================
// To enable push notifications, add firebase-admin:
// 1. npm install firebase-admin
// 2. Add service account key
// 3. Initialize FCM
//
// const admin = require('firebase-admin');
// const serviceAccount = require('./path/to/serviceAccountKey.json');
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });
//
// async function sendPushNotification(token, title, body, data = {}) {
//   try {
//     const message = {
//       token,
//       notification: { title, body },
//       data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
//       android: { priority: 'high' }
//     };
//     await admin.messaging().send(message);
//   } catch (error) {
//     console.error('FCM send error:', error);
//   }
// }
//
// In createNotification, after io.emit, also call:
// if (user has FCM token) sendPushNotification(token, title, body, { type, relatedId });

// Store FCM tokens per user (in-memory for now, use DB in production)
const userFcmTokens = new Map();

// API to register FCM token
// app.post('/api/notifications/fcm-token', authMiddleware, (req, res) => {
//   const { token } = req.body;
//   if (token) {
//     userFcmTokens.set(req.user.id, token);
//     res.json({ success: true });
//   } else {
//     res.status(400).json({ success: false, message: 'Token required' });
//   }
// });

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Register endpoint
app.post('/api/auth/register', registrationRateLimiter, async (req, res) => {
  try {
    const { email, password, full_name, phone, role } = req.body;

    // Validate required fields
    if (!email || !password || !full_name || !role) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, full name, and role are required'
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid email format'
      });
    }

    // Validate password length
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters'
      });
    }

    // Validate role
    if (role !== 'DRIVER' && role !== 'CUSTOMER') {
      return res.status(400).json({
        success: false,
        message: 'Role must be either DRIVER or CUSTOMER'
      });
    }

    // Check if user already exists
    const existingUser = UserModel.findByEmail(email);
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email already registered'
      });
    }

    // Create user with profile
    const userId = await UserModel.create(email, password, role, {
      full_name,
      phone: phone || null,
      city: null,
      wilaya: null
    });

    // Get the created user
    const user = UserModel.findById(userId);
    const profile = ProfileModel.findByUserId(userId);

    // Generate token
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: 'Registration successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        profile: {
          full_name: profile.full_name,
          phone: profile.phone,
          city: profile.city,
          wilaya: profile.wilaya
        }
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Login endpoint
app.post('/api/auth/login', loginRateLimiter, async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate required fields
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Verify credentials
    const user = await UserModel.verifyPassword(email, password);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password'
      });
    }

    // Get profile
    const profile = ProfileModel.findByUserId(user.id);

    // Generate token
    const token = generateToken(user);

    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        profile: {
          full_name: profile.full_name,
          phone: profile.phone,
          city: profile.city,
          wilaya: profile.wilaya
        }
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get current user endpoint (protected)
app.get('/api/auth/me', authMiddleware, (req, res) => {
  try {
    const user = UserModel.findById(req.user.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const profile = ProfileModel.findByUserId(user.id);

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        profile: {
          full_name: profile.full_name,
          phone: profile.phone,
          city: profile.city,
          wilaya: profile.wilaya,
          profile_image: profile.profile_image,
          rating: profile.rating,
          rating_count: profile.rating_count
        }
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update profile endpoint (protected)
app.put('/api/profile', authMiddleware, (req, res) => {
  try {
    const { full_name, phone, city, wilaya } = req.body;

    // Validate required fields
    if (!full_name) {
      return res.status(400).json({
        success: false,
        message: 'Full name is required'
      });
    }

    // Update profile
    const updated = ProfileModel.update(req.user.id, {
      full_name,
      phone: phone || null,
      city: city || null,
      wilaya: wilaya || null
    });

    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found'
      });
    }

    // Get updated profile
    const profile = ProfileModel.findByUserId(req.user.id);

    res.json({
      success: true,
      message: 'Profile updated successfully',
      profile: {
        full_name: profile.full_name,
        phone: profile.phone,
        city: profile.city,
        wilaya: profile.wilaya,
        profile_image: profile.profile_image,
        rating: profile.rating,
        rating_count: profile.rating_count
      }
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Truck type validation
const VALID_TRUCK_TYPES = ['FLATBED', 'TARP', 'REFRIGERATED', 'VAN', 'SEMI_TRAILER', 'OTHER'];

// Middleware to check if user is a driver
const isDriverMiddleware = (req, res, next) => {
  if (req.user.role !== 'DRIVER') {
    return res.status(403).json({
      success: false,
      message: 'Only drivers can access this resource'
    });
  }
  next();
};

// Get all trucks for current driver
app.get('/api/trucks/my', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trucks = TruckModel.findByDriverId(req.user.id);
    res.json({
      success: true,
      trucks
    });
  } catch (error) {
    console.error('Get trucks error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Create a new truck
app.post('/api/trucks', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const { truck_type, brand, model, max_weight, max_volume, registration_number, image_url } = req.body;

    // Validate required fields
    if (!truck_type || !max_weight) {
      return res.status(400).json({
        success: false,
        message: 'Truck type and maximum weight are required'
      });
    }

    // Validate truck type
    if (!VALID_TRUCK_TYPES.includes(truck_type)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid truck type'
      });
    }

    // Validate max_weight is a positive number
    if (typeof max_weight !== 'number' || max_weight <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Maximum weight must be a positive number'
      });
    }

    // Validate max_volume if provided
    if (max_volume !== undefined && max_volume !== null && (typeof max_volume !== 'number' || max_volume <= 0)) {
      return res.status(400).json({
        success: false,
        message: 'Maximum volume must be a positive number'
      });
    }

    // Create truck
    const truckId = TruckModel.create(req.user.id, {
      truck_type,
      brand,
      model,
      max_weight,
      max_volume,
      registration_number,
      image_url
    });

    // Get created truck
    const truck = TruckModel.findById(truckId);

    res.status(201).json({
      success: true,
      message: 'Truck created successfully',
      truck
    });
  } catch (error) {
    console.error('Create truck error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get a specific truck
app.get('/api/trucks/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const truckId = parseInt(req.params.id);

    if (isNaN(truckId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid truck ID'
      });
    }

    const truck = TruckModel.findById(truckId);

    if (!truck) {
      return res.status(404).json({
        success: false,
        message: 'Truck not found'
      });
    }

    // Check if truck belongs to current driver
    if (truck.driver_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to access this truck'
      });
    }

    res.json({
      success: true,
      truck
    });
  } catch (error) {
    console.error('Get truck error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update a truck
app.put('/api/trucks/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const truckId = parseInt(req.params.id);

    if (isNaN(truckId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid truck ID'
      });
    }

    const truck = TruckModel.findById(truckId);

    if (!truck) {
      return res.status(404).json({
        success: false,
        message: 'Truck not found'
      });
    }

    // Check if truck belongs to current driver
    if (truck.driver_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to modify this truck'
      });
    }

    const { truck_type, brand, model, max_weight, max_volume, registration_number, image_url } = req.body;

    // Validate required fields
    if (!truck_type || !max_weight) {
      return res.status(400).json({
        success: false,
        message: 'Truck type and maximum weight are required'
      });
    }

    // Validate truck type
    if (!VALID_TRUCK_TYPES.includes(truck_type)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid truck type'
      });
    }

    // Validate max_weight
    if (typeof max_weight !== 'number' || max_weight <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Maximum weight must be a positive number'
      });
    }

    // Validate max_volume if provided
    if (max_volume !== undefined && max_volume !== null && (typeof max_volume !== 'number' || max_volume <= 0)) {
      return res.status(400).json({
        success: false,
        message: 'Maximum volume must be a positive number'
      });
    }

    // Update truck
    const updated = TruckModel.update(truckId, {
      truck_type,
      brand,
      model,
      max_weight,
      max_volume,
      registration_number,
      image_url
    });

    if (!updated) {
      return res.status(500).json({
        success: false,
        message: 'Failed to update truck'
      });
    }

    // Get updated truck
    const updatedTruck = TruckModel.findById(truckId);

    res.json({
      success: true,
      message: 'Truck updated successfully',
      truck: updatedTruck
    });
  } catch (error) {
    console.error('Update truck error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Delete a truck
app.delete('/api/trucks/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const truckId = parseInt(req.params.id);

    if (isNaN(truckId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid truck ID'
      });
    }

    const truck = TruckModel.findById(truckId);

    if (!truck) {
      return res.status(404).json({
        success: false,
        message: 'Truck not found'
      });
    }

    // Check if truck belongs to current driver
    if (truck.driver_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You do not have permission to delete this truck'
      });
    }

    // Delete truck
    const deleted = TruckModel.delete(truckId);

    if (!deleted) {
      return res.status(500).json({
        success: false,
        message: 'Failed to delete truck'
      });
    }

    res.json({
      success: true,
      message: 'Truck deleted successfully'
    });
  } catch (error) {
    console.error('Delete truck error:', error);
    if (error.status) return res.status(error.status).json({ success: false, message: error.message });
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Trip type validation
const VALID_TRIP_TYPES = ['RETURN'];
const VALID_TRIP_STATUSES = ['PUBLISHED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

// Validate and normalize a trip payload shared by create & update
function buildTripData(body) {
  const {
    truck_id,
    origin_name,
    origin_lat,
    origin_lng,
    destination_name,
    destination_lat,
    destination_lng,
    departure_date,
    available_weight,
    available_volume,
    trip_type,
    description
  } = body;

  if (!truck_id) {
    return { error: 'A truck must be selected' };
  }
  if (!origin_name || typeof origin_name !== 'string' || !origin_name.trim()) {
    return { error: 'Origin is required' };
  }
  if (!destination_name || typeof destination_name !== 'string' || !destination_name.trim()) {
    return { error: 'Destination is required' };
  }
  if (origin_name.trim().toLowerCase() === destination_name.trim().toLowerCase()) {
    return { error: 'Origin and destination must be different' };
  }
  if (!departure_date) {
    return { error: 'Departure date is required' };
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(departure_date)) {
    return { error: 'Departure date must be in YYYY-MM-DD format' };
  }
  if (typeof available_weight !== 'number' || available_weight <= 0) {
    return { error: 'Available weight must be a positive number' };
  }
  if (available_volume !== undefined && available_volume !== null &&
      (typeof available_volume !== 'number' || available_volume <= 0)) {
    return { error: 'Available volume must be a positive number' };
  }
  if (trip_type !== undefined && !VALID_TRIP_TYPES.includes(trip_type)) {
    return { error: 'Invalid trip type' };
  }

  const isValidCoordPair = (lat, lng) => {
    const hasLat = lat !== undefined && lat !== null;
    const hasLng = lng !== undefined && lng !== null;
    if (hasLat !== hasLng) {
      return false;
    }
    if (!hasLat) {
      return true;
    }
    return (
      typeof lat === 'number' &&
      typeof lng === 'number' &&
      lat >= -90 && lat <= 90 &&
      lng >= -180 && lng <= 180
    );
  };
  if (!isValidCoordPair(origin_lat, origin_lng)) {
    return { error: 'Origin latitude and longitude must both be provided and valid' };
  }
  if (!isValidCoordPair(destination_lat, destination_lng)) {
    return { error: 'Destination latitude and longitude must both be provided and valid' };
  }

  return {
    data: {
      truck_id,
      origin_name: origin_name.trim(),
      origin_lat: origin_lat ?? null,
      origin_lng: origin_lng ?? null,
      destination_name: destination_name.trim(),
      destination_lat: destination_lat ?? null,
      destination_lng: destination_lng ?? null,
      departure_date,
      available_weight,
      available_volume: available_volume ?? null,
      trip_type: trip_type || 'RETURN',
      description: description || null
    }
  };
}

// Check that the selected truck exists and belongs to the current driver
function getOwnedTruck(req, res, truckId) {
  if (typeof truckId !== 'number' || !Number.isInteger(truckId)) {
    res.status(400).json({ success: false, message: 'Invalid truck ID' });
    return null;
  }
  const truck = TruckModel.findById(truckId);
  if (!truck) {
    res.status(400).json({ success: false, message: 'Selected truck was not found' });
    return null;
  }
  if (truck.driver_id !== req.user.id) {
    res.status(403).json({ success: false, message: 'Selected truck does not belong to you' });
    return null;
  }
  return truck;
}

function validateTripCapacity(data, truck) {
  if (data.available_weight > truck.max_weight) {
    return `Available weight cannot exceed the truck maximum of ${truck.max_weight}`;
  }
  return null;
}

// Load a trip by :id and check ownership against the current driver
function getOwnedTrip(req, res) {
  const tripId = parseInt(req.params.id);
  if (isNaN(tripId)) {
    res.status(400).json({ success: false, message: 'Invalid trip ID' });
    return null;
  }
  const trip = TripModel.findById(tripId);
  if (!trip) {
    res.status(404).json({ success: false, message: 'Trip not found' });
    return null;
  }
  if (trip.driver_id !== req.user.id) {
    res.status(403).json({ success: false, message: 'You do not have permission to access this trip' });
    return null;
  }
  return trip;
}

// Get all trips for the current driver
app.get('/api/trips/my', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trips = TripModel.findByDriverId(req.user.id);
    res.json({
      success: true,
      trips
    });
  } catch (error) {
    console.error('Get trips error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Create a new return trip
app.post('/api/trips', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const { data, error } = buildTripData(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error });
    }

    // The selected truck must belong to the driver
    const truck = getOwnedTruck(req, res, data.truck_id);
    if (!truck) {
      return;
    }
    const capacityError = validateTripCapacity(data, truck);
    if (capacityError) {
      return res.status(400).json({ success: false, message: capacityError });
    }

    const tripId = TripModel.create(req.user.id, data);
    const trip = TripModel.findById(tripId);

    res.status(201).json({
      success: true,
      message: 'Return trip published successfully',
      trip
    });
  } catch (error) {
    console.error('Create trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/trips/history - Get trip history for current user
app.get('/api/trips/history', authMiddleware, (req, res) => {
  try {
    const userId = req.user.id;
    const isDriver = req.user.role === 'DRIVER';

    let history = [];

    if (isDriver) {
      // Driver history: completed trips they own
      const trips = db.prepare(`
        SELECT t.*, tr.id as request_id, tr.customer_id, tr.status as request_status,
               p.full_name as customer_name, p.rating as customer_rating, p.rating_count as customer_rating_count,
               tk.truck_type, tk.brand, tk.model
        FROM trips t
        LEFT JOIN transport_requests tr ON t.id = tr.trip_id AND tr.status = 'COMPLETED'
        LEFT JOIN profiles p ON tr.customer_id = p.user_id
        LEFT JOIN trucks tk ON t.truck_id = tk.id
        WHERE t.driver_id = ? AND (t.status = 'COMPLETED' OR tr.status = 'COMPLETED')
        ORDER BY t.departure_date DESC
      `).all(userId);

      history = trips.map(trip => {
        // Get rating given by driver (if any)
        let myRating = null;
        if (trip.request_id) {
          myRating = RatingModel.getMyRatingForRequest(trip.request_id, userId);
        }
        return {
          id: trip.id,
          type: 'trip',
          trip_id: trip.id,
          request_id: trip.request_id,
          origin: trip.origin_name,
          destination: trip.destination_name,
          date: trip.departure_date,
          status: trip.request_status || trip.status,
          otherParty: trip.customer_id ? {
            id: trip.customer_id,
            name: trip.customer_name,
            role: 'CUSTOMER',
            rating: trip.customer_rating,
            rating_count: trip.customer_rating_count
          } : null,
          truck: trip.truck_type ? {
            type: trip.truck_type,
            brand: trip.brand,
            model: trip.model
          } : null,
          myRating: myRating ? { rating: myRating.rating, comment: myRating.comment } : null
        };
      });
    } else {
      // Customer history: completed requests they made
      const requests = db.prepare(`
        SELECT tr.*, t.id as trip_id, t.origin_name, t.destination_name, t.departure_date, t.status as trip_status,
               t.driver_id, t.truck_id,
               p.full_name as driver_name, p.rating as driver_rating, p.rating_count as driver_rating_count,
               tk.truck_type, tk.brand, tk.model
        FROM transport_requests tr
        JOIN trips t ON tr.trip_id = t.id
        LEFT JOIN profiles p ON t.driver_id = p.user_id
        LEFT JOIN trucks tk ON t.truck_id = tk.id
        WHERE tr.customer_id = ? AND tr.status = 'COMPLETED'
        ORDER BY t.departure_date DESC
      `).all(userId);

      history = requests.map(req => {
        // Get rating given by customer (if any)
        let myRating = RatingModel.getMyRatingForRequest(req.id, userId);
        return {
          id: req.id,
          type: 'request',
          trip_id: req.trip_id,
          request_id: req.id,
          origin: req.origin_name,
          destination: req.destination_name,
          date: req.departure_date,
          status: req.status,
          otherParty: req.driver_id ? {
            id: req.driver_id,
            name: req.driver_name,
            role: 'DRIVER',
            rating: req.driver_rating,
            rating_count: req.driver_rating_count
          } : null,
          truck: req.truck_type ? {
            type: req.truck_type,
            brand: req.brand,
            model: req.model
          } : null,
          myRating: myRating ? { rating: myRating.rating, comment: myRating.comment } : null
        };
      });
    }

    res.json({
      success: true,
      history
    });
  } catch (error) {
    console.error('Get history error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get a specific trip
app.get('/api/trips/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    res.json({
      success: true,
      trip
    });
  } catch (error) {
    console.error('Get trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update a trip
app.put('/api/trips/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    const { data, error } = buildTripData(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error });
    }

    // The selected truck must belong to the driver
    const truck = getOwnedTruck(req, res, data.truck_id);
    if (!truck) {
      return;
    }
    const capacityError = validateTripCapacity(data, truck);
    if (capacityError) {
      return res.status(400).json({ success: false, message: capacityError });
    }

    const updated = TripModel.update(trip.id, data);
    if (!updated) {
      return res.status(500).json({
        success: false,
        message: 'Failed to update trip'
      });
    }

    const updatedTrip = TripModel.findById(trip.id);

    res.json({
      success: true,
      message: 'Return trip updated successfully',
      trip: updatedTrip
    });
  } catch (error) {
    console.error('Update trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Delete a trip
app.delete('/api/trips/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    const deleted = TripModel.delete(trip.id);
    if (!deleted) {
      return res.status(500).json({
        success: false,
        message: 'Failed to delete trip'
      });
    }

    res.json({
      success: true,
      message: 'Return trip deleted successfully'
    });
  } catch (error) {
    console.error('Delete trip error:', error);
    if (error.status) return res.status(error.status).json({ success: false, message: error.message });
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Start a trip (PUBLISHED -> IN_PROGRESS)
app.post('/api/trips/:id/start', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    if (trip.status !== 'PUBLISHED') {
      return res.status(400).json({
        success: false,
        message: 'Only published trips can be started'
      });
    }

    TripModel.updateStatus(trip.id, 'IN_PROGRESS');
    const updatedTrip = TripModel.findById(trip.id);

    // Notify customers with accepted requests on this trip
    const acceptedRequests = db.prepare(`
      SELECT customer_id FROM transport_requests
      WHERE trip_id = ? AND status = 'ACCEPTED'
    `).all(trip.id);

    for (const req of acceptedRequests) {
      createNotification(req.customer_id,
        'Transport Started',
        `Your transport from ${trip.origin_name} to ${trip.destination_name} has started.`,
        NOTIFICATION_TYPES.TRIP_STARTED,
        trip.id,
        null,
        trip.id,
        null
      );
    }

    res.json({
      success: true,
      message: 'Return trip started successfully',
      trip: updatedTrip
    });
  } catch (error) {
    console.error('Start trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Completion events are emitted only after the transaction commits.
function emitCompletion(events) {
  for (const { message, notification } of events) {
    if (message) io.to(`conversation-${message.conversation_id}`).emit('message-received', buildMessagePayload(message));
    io.to(`user-${notification.user_id}`).emit('notification', notification);
  }
}
app.post('/api/trips/:id/complete', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const id = Number(req.params.id);
    emitCompletion(Completion.finishTrip(id, req.user));
    res.json({ success: true, trip: TripModel.findById(id) });
  } catch (error) {
    res.status(error.status || 500).json({ success: false, message: error.status ? error.message : 'Impossible de terminer le trajet' });
  }
});

// Cancel a trip (PUBLISHED or IN_PROGRESS -> CANCELLED)
app.post('/api/trips/:id/cancel', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    if (!['PUBLISHED', 'IN_PROGRESS'].includes(trip.status)) {
      return res.status(400).json({
        success: false,
        message: 'This trip can no longer be cancelled'
      });
    }

    const requests = TripModel.finishWithRequests(trip.id, 'CANCELLED');
    const updatedTrip = TripModel.findById(trip.id);

    // Notify customers with accepted/pending requests on this trip

    for (const req of requests) {
      createNotification(req.customer_id,
        'Transport Cancelled',
        `The transport from ${trip.origin_name} to ${trip.destination_name} has been cancelled by the driver.`,
        NOTIFICATION_TYPES.TRIP_CANCELLED,
        trip.id,
        null,
        trip.id,
        null
      );
    }

    res.json({
      success: true,
      message: 'Return trip cancelled successfully',
      trip: updatedTrip
    });
  } catch (error) {
    console.error('Cancel trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ---- CARGAISONS (chargements) ROUTES ----

// Get all cargaisons for the current driver
app.get('/api/cargaisons/my', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const cargaisons = CargaisonModel.findByDriverId(req.user.id);
    res.json({
      success: true,
      cargaisons
    });
  } catch (error) {
    console.error('Get cargaisons error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get a specific cargaison (owner check)
function getOwnedCargaison(req, res) {
  const cargaisonId = parseInt(req.params.id);
  if (isNaN(cargaisonId)) {
    res.status(400).json({ success: false, message: 'Invalid cargaison ID' });
    return null;
  }
  const cargaison = CargaisonModel.findById(cargaisonId);
  if (!cargaison) {
    res.status(404).json({ success: false, message: 'Cargaison not found' });
    return null;
  }
  if (cargaison.driver_id !== req.user.id) {
    res.status(403).json({ success: false, message: 'You do not have permission to access this cargaison' });
    return null;
  }
  return cargaison;
}

// Build & validate a cargaison payload
function buildCargaisonData(body) {
  const {
    trip_id,
    origin_name,
    destination_name,
    cargo_type,
    weight,
    description,
    status,
    customer_name,
    customer_phone
  } = body;

  if (!origin_name || typeof origin_name !== 'string' || !origin_name.trim()) {
    return { error: 'Origin is required' };
  }
  if (!destination_name || typeof destination_name !== 'string' || !destination_name.trim()) {
    return { error: 'Destination is required' };
  }
  if (origin_name.trim().toLowerCase() === destination_name.trim().toLowerCase()) {
    return { error: 'Origin and destination must be different' };
  }
  if (!cargo_type || typeof cargo_type !== 'string' || !cargo_type.trim()) {
    return { error: 'Cargo type is required' };
  }
  if (typeof weight !== 'number' || weight <= 0) {
    return { error: 'Weight must be a positive number' };
  }

  return {
    data: {
      trip_id: trip_id ?? null,
      origin_name: origin_name.trim(),
      destination_name: destination_name.trim(),
      cargo_type: cargo_type.trim(),
      weight,
      description: description || null,
      status: status || 'AVAILABLE',
      customer_name: customer_name || null,
      customer_phone: customer_phone || null
    }
  };
}

// Create a new cargaison
app.post('/api/cargaisons', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const { data, error } = buildCargaisonData(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error });
    }

    const cargaisonId = CargaisonModel.create(req.user.id, data);
    const cargaison = CargaisonModel.findById(cargaisonId);

    res.status(201).json({
      success: true,
      message: 'Cargaison created successfully',
      cargaison
    });
  } catch (error) {
    console.error('Create cargaison error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get a specific cargaison
app.get('/api/cargaisons/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const cargaison = getOwnedCargaison(req, res);
    if (!cargaison) {
      return;
    }
    res.json({ success: true, cargaison });
  } catch (error) {
    console.error('Get cargaison error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// Update a cargaison
app.put('/api/cargaisons/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const cargaison = getOwnedCargaison(req, res);
    if (!cargaison) {
      return;
    }

    const { data, error } = buildCargaisonData(req.body);
    if (error) {
      return res.status(400).json({ success: false, message: error });
    }

    const updated = CargaisonModel.update(cargaison.id, data);
    if (!updated) {
      return res.status(500).json({ success: false, message: 'Failed to update cargaison' });
    }

    const updatedCargaison = CargaisonModel.findById(cargaison.id);
    res.json({ success: true, message: 'Cargaison updated successfully', cargaison: updatedCargaison });
  } catch (error) {
    console.error('Update cargaison error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// Update cargaison status (assign to trip, start, complete, cancel)
app.post('/api/cargaisons/:id/status', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const cargaison = getOwnedCargaison(req, res);
    if (!cargaison) {
      return;
    }

    const { status, trip_id } = req.body;
    const VALID_STATUSES = ['AVAILABLE', 'ASSIGNED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'];
    if (!VALID_STATUSES.includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }

    CargaisonModel.updateStatus(cargaison.id, status, trip_id);
    const updatedCargaison = CargaisonModel.findById(cargaison.id);

    res.json({
      success: true,
      message: 'Cargaison status updated successfully',
      cargaison: updatedCargaison
    });
  } catch (error) {
    console.error('Update cargaison status error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// Delete a cargaison
app.delete('/api/cargaisons/:id', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const cargaison = getOwnedCargaison(req, res);
    if (!cargaison) {
      return;
    }

    const deleted = CargaisonModel.delete(cargaison.id);
    if (!deleted) {
      return res.status(500).json({ success: false, message: 'Failed to delete cargaison' });
    }

    res.json({ success: true, message: 'Cargaison deleted successfully' });
  } catch (error) {
    console.error('Delete cargaison error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// ---- SEARCH ENDPOINTS ----

// Calculate distance between two geographic points (Haversine formula)
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth radius in km
  const dLat = (lat2 - lat1) * (Math.PI / 180);
  const dLng = (lng2 - lng1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * (Math.PI / 180)) * Math.cos(lat2 * (Math.PI / 180)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Score a trip match based on origin, destination, date, and capacity
function scoreTrip(trip, originLat, originLng, destLat, destLng, date, reqWeight, reqVolume) {
  let score = 0;

  // Origin proximity (30 points)
  // If coordinates provided, use distance; otherwise use city name match
  let originScore = 0;
  if (originLat !== null && originLng !== null && trip.origin_lat !== null && trip.origin_lng !== null) {
    const distOrigin = calculateDistance(originLat, originLng, trip.origin_lat, trip.origin_lng);
    if (distOrigin < 5) {
      originScore = 30; // Within 5km = exact match
    } else if (distOrigin < 50) {
      originScore = 20; // Within 50km = nearby
    } else if (distOrigin < 150) {
      originScore = 10; // Within 150km = acceptable
    }
  }
  score += originScore;

  // Destination proximity (30 points)
  let destScore = 0;
  if (destLat !== null && destLng !== null && trip.destination_lat !== null && trip.destination_lng !== null) {
    const distDest = calculateDistance(destLat, destLng, trip.destination_lat, trip.destination_lng);
    if (distDest < 5) {
      destScore = 30;
    } else if (distDest < 50) {
      destScore = 20;
    } else if (distDest < 150) {
      destScore = 10;
    }
  }
  score += destScore;

  // Date compatibility (20 points)
  if (trip.departure_date === date) {
    score += 20; // Exact date match
  } else {
    // Check if dates are close (within 3 days)
    const tripDate = new Date(trip.departure_date);
    const searchDate = new Date(date);
    const dayDiff = Math.abs((tripDate - searchDate) / (1000 * 60 * 60 * 24));
    if (dayDiff <= 3) {
      score += 10;
    }
  }

  // Weight compatibility (10 points)
  if (trip.available_weight >= reqWeight) {
    score += 10;
  }

  // Volume compatibility (10 points)
  if (reqVolume === null || trip.available_volume === null || trip.available_volume >= reqVolume) {
    score += 10;
  }

  return score;
}

// Search available trips (customer search)
app.get('/api/search/trips', async (req, res) => {
  try {
    const {
      origin_lat,
      origin_lng,
      destination_lat,
      destination_lng,
      date,
      required_weight,
      required_volume
    } = req.query;

    // Validate required parameters
    if (!date || !required_weight) {
      return res.status(400).json({
        success: false,
        message: 'Date and required weight are required'
      });
    }

    const reqWeight = parseFloat(required_weight);
    const reqVolume = required_volume ? parseFloat(required_volume) : null;
    const originLat = origin_lat ? parseFloat(origin_lat) : null;
    const originLng = origin_lng ? parseFloat(origin_lng) : null;
    const destLat = destination_lat ? parseFloat(destination_lat) : null;
    const destLng = destination_lng ? parseFloat(destination_lng) : null;

    if (isNaN(reqWeight) || reqWeight <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Required weight must be a positive number'
      });
    }

    if (reqVolume !== null && isNaN(reqVolume)) {
      return res.status(400).json({
        success: false,
        message: 'Required volume must be a valid number'
      });
    }

    // Get all published trips
    const stmt = db.prepare(`
      SELECT t.*, u.email, u.role, p.full_name, p.rating, p.rating_count
      FROM trips t
      JOIN users u ON t.driver_id = u.id
      JOIN profiles p ON u.id = p.user_id
      WHERE t.status = 'PUBLISHED'
        AND t.departure_date >= ?
        AND t.available_weight >= ?
      ORDER BY t.created_at DESC
    `);

    const trips = stmt.all(date, reqWeight);

    // Score and filter trips
    const scoredTrips = trips
      .map(trip => ({
        ...trip,
        matchScore: scoreTrip(trip, originLat, originLng, destLat, destLng, date, reqWeight, reqVolume)
      }))
      .filter(trip => trip.matchScore > 0)
      .sort((a, b) => b.matchScore - a.matchScore);

    // Get truck details for each trip
    const enrichedTrips = scoredTrips.map(trip => {
      const truckStmt = db.prepare('SELECT * FROM trucks WHERE id = ?');
      const truck = truckStmt.get(trip.truck_id);
      return {
        trip: {
          id: trip.id,
          driver_id: trip.driver_id,
          truck_id: trip.truck_id,
          origin_name: trip.origin_name,
          origin_lat: trip.origin_lat,
          origin_lng: trip.origin_lng,
          destination_name: trip.destination_name,
          destination_lat: trip.destination_lat,
          destination_lng: trip.destination_lng,
          departure_date: trip.departure_date,
          available_weight: trip.available_weight,
          available_volume: trip.available_volume,
          trip_type: trip.trip_type,
          status: trip.status,
          description: trip.description,
          created_at: trip.created_at,
          updated_at: trip.updated_at,
        },
        driver: {
          id: trip.driver_id,
          email: trip.email,
          full_name: trip.full_name,
          rating: trip.rating,
          rating_count: trip.rating_count,
        },
        truck: truck,
        matchScore: trip.matchScore,
      };
    });

    res.json({
      success: true,
      count: enrichedTrips.length,
      trips: enrichedTrips
    });
  } catch (error) {
    console.error('Search trips error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/requests - Customer requests transport
app.post('/api/requests', authMiddleware, (req, res) => {
  try {
    const { trip_id, requested_weight, requested_volume, cargo_description, pickup_location, delivery_location } = req.body;

    // Validate required fields
    if (!trip_id || requested_weight === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Trip ID and requested weight are required'
      });
    }

    const weight = requested_weight;
    if (typeof weight !== 'number' || !Number.isFinite(weight) || weight <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Requested weight must be a positive number'
      });
    }

    // Get trip
    const trip = TripModel.findById(trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Trip not found'
      });
    }

    // Verify trip is published and belongs to a different driver
    if (trip.status !== 'PUBLISHED') {
      return res.status(400).json({
        success: false,
        message: 'Trip is not available for requests'
      });
    }

    if (trip.driver_id === req.user.id) {
      return res.status(400).json({
        success: false,
        message: 'Cannot request your own trip'
      });
    }

    // Check capacity
    if (trip.available_weight < weight) {
      return res.status(400).json({
        success: false,
        message: 'Insufficient weight capacity on this trip'
      });
    }

    const volume = requested_volume ?? null;
    if (volume !== null && (typeof volume !== 'number' || !Number.isFinite(volume) || volume <= 0)) {
      return res.status(400).json({ success: false, message: 'Requested volume must be a positive finite number' });
    }
    if (volume !== null) {
      if (trip.available_volume === null || trip.available_volume < volume) {
        return res.status(400).json({
          success: false,
          message: 'Insufficient volume capacity on this trip'
        });
      }
    }

    // Create request
    const requestId = TransportRequestModel.create(req.user.id, trip_id, {
      requested_weight: weight,
      requested_volume: volume,
      cargo_description: cargo_description || null,
      pickup_location: pickup_location || null,
      delivery_location: delivery_location || null
    });

    const request = TransportRequestModel.findById(requestId);

    // Notify driver of new transport request
    const driverProfile = ProfileModel.findByUserId(req.user.id);
    createNotification(trip.driver_id,
      'New Transport Request',
      `${driverProfile?.full_name || 'A customer'} has requested transport from ${trip.origin_name} to ${trip.destination_name}.`,
      NOTIFICATION_TYPES.NEW_REQUEST,
      requestId,
      null,
      trip.id,
      requestId
    );

    res.status(201).json({
      success: true,
      message: 'Transport request created successfully',
      request
    });
  } catch (error) {
    console.error('Create request error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/requests/my - Get my requests (customer sees their requests, driver sees requests for their trips)
app.get('/api/requests/my', authMiddleware, (req, res) => {
  try {
    let requests;

    if (req.user.role === 'DRIVER') {
      // Driver sees requests for their trips
      const driverTrips = TripModel.findByDriverId(req.user.id);
      const tripIds = driverTrips.map(t => t.id);

      if (tripIds.length === 0) {
        requests = [];
      } else {
        const placeholders = tripIds.map(() => '?').join(',');
        const stmt = db.prepare(`
          SELECT tr.*, p.full_name as customer_name, p.rating as customer_rating, p.rating_count as customer_rating_count
          FROM transport_requests tr
          JOIN profiles p ON tr.customer_id = p.user_id
          WHERE tr.trip_id IN (${placeholders})
          ORDER BY tr.created_at DESC
        `);
        requests = stmt.all(...tripIds);
      }
    } else {
      // Customer sees their requests
      requests = TransportRequestModel.findByCustomerId(req.user.id);
      // Enrich with customer name (for consistency)
      const profile = ProfileModel.findByUserId(req.user.id);
      requests = requests.map(r => ({
        ...r,
        customer_name: profile?.full_name,
        customer_rating: profile?.rating,
        customer_rating_count: profile?.rating_count
      }));
    }

    res.json({
      success: true,
      requests
    });
  } catch (error) {
    console.error('Get requests error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/requests/:id - Get specific request
app.get('/api/requests/:id', authMiddleware, (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const request = TransportRequestModel.findById(requestId);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    const trip = TripModel.findById(request.trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Associated trip not found'
      });
    }

    // Verify access: customer owns request OR driver owns trip
    if (req.user.id !== request.customer_id && req.user.id !== trip.driver_id) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized access'
      });
    }

    // Enrich with additional data
    const truck = TruckModel.findById(trip.truck_id);
    const customerProfile = ProfileModel.findByUserId(request.customer_id);
    const driverProfile = ProfileModel.findByUserId(trip.driver_id);

    res.json({
      success: true,
      request: {
        ...request,
        trip,
        truck,
        customer: {
          id: request.customer_id,
          full_name: customerProfile?.full_name,
          rating: customerProfile?.rating,
          rating_count: customerProfile?.rating_count
        },
        driver: {
          id: trip.driver_id,
          full_name: driverProfile?.full_name,
          rating: driverProfile?.rating,
          rating_count: driverProfile?.rating_count
        }
      }
    });
  } catch (error) {
    console.error('Get request error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/requests/:id/accept - Driver accepts request
app.post('/api/requests/:id/accept', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const request = TransportRequestModel.findById(requestId);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    const trip = TripModel.findById(request.trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Trip not found'
      });
    }

    // Verify driver owns this trip
    if (trip.driver_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You do not own this trip'
      });
    }

    // Verify request is pending
    if (request.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: `Cannot accept a ${request.status} request`
      });
    }

    try {
      // Accept with capacity update (transaction)
      TransportRequestModel.acceptWithCapacityUpdate(requestId, request.trip_id);

      const updatedRequest = TransportRequestModel.findById(requestId);
      const updatedTrip = TripModel.findById(request.trip_id);

      const conversation = ConversationModel.findOrCreateByRequestId(requestId);

      // Notify customer that request was accepted
      createNotification(request.customer_id,
        'Request Accepted',
        `Your transport request for ${trip.origin_name} to ${trip.destination_name} has been accepted.`,
        NOTIFICATION_TYPES.REQUEST_ACCEPTED,
        requestId,
        conversation.id,
        trip.id,
        requestId
      );

      res.json({
        success: true,
        message: 'Transport request accepted',
        request: updatedRequest,
        trip: updatedTrip,
        conversation: conversation
      });
    } catch (error) {
      if (error.status || error.message.includes('Insufficient')) {
        return res.status(error.status || 409).json({
          success: false,
          message: error.message
        });
      }
      throw error;
    }
  } catch (error) {
    console.error('Accept request error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/requests/:id/reject - Driver rejects request
app.post('/api/requests/:id/reject', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const request = TransportRequestModel.findById(requestId);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    const trip = TripModel.findById(request.trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Trip not found'
      });
    }

    // Verify driver owns this trip
    if (trip.driver_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You do not own this trip'
      });
    }

    // Verify request is pending
    if (request.status !== 'PENDING') {
      return res.status(400).json({
        success: false,
        message: `Cannot reject a ${request.status} request`
      });
    }

    // Update status
    TransportRequestModel.updateStatus(requestId, 'REJECTED');
    const updatedRequest = TransportRequestModel.findById(requestId);

    // Notify customer that request was rejected
    createNotification(request.customer_id,
      'Request Rejected',
      `Your transport request for ${trip.origin_name} to ${trip.destination_name} has been rejected.`,
      NOTIFICATION_TYPES.REQUEST_REJECTED,
      requestId,
      null,
      trip.id,
      requestId
    );

    res.json({
      success: true,
      message: 'Transport request rejected',
      request: updatedRequest
    });
  } catch (error) {
    console.error('Reject request error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/requests/:id/cancel - Customer cancels request
app.post('/api/requests/:id/cancel', authMiddleware, (req, res) => {
  try {
    const requestId = parseInt(req.params.id);
    const request = TransportRequestModel.findById(requestId);

    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    // Verify customer owns this request
    if (request.customer_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'You cannot cancel this request'
      });
    }

    const trip = TripModel.findById(request.trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Trip not found'
      });
    }

    // Can only cancel if PENDING or ACCEPTED
    if (request.status === 'AWAITING_CUSTOMER_CONFIRMATION' || request.status === 'REJECTED' || request.status === 'COMPLETED' || request.status === 'CANCELLED') {
      return res.status(400).json({
        success: false,
        message: `Cannot cancel a ${request.status} request`
      });
    }

    // Cancel with capacity restore if accepted
    TransportRequestModel.cancelWithCapacityRestore(requestId, request.trip_id);
    const updatedRequest = TransportRequestModel.findById(requestId);

    // Notify driver that request was cancelled
    createNotification(trip.driver_id,
      'Request Cancelled',
      `The customer cancelled the transport request for ${trip.origin_name} to ${trip.destination_name}.`,
      NOTIFICATION_TYPES.REQUEST_CANCELLED,
      requestId,
      null,
      trip.id,
      requestId
    );

    res.json({
      success: true,
      message: 'Transport request cancelled',
      request: updatedRequest
    });
  } catch (error) {
    console.error('Cancel request error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

for (const action of ['complete', 'confirm']) {
  app.post('/api/requests/:id/' + action, authMiddleware, (req, res) => {
    try {
      const id = Number(req.params.id);
      emitCompletion(Completion.finishRequest(id, req.user, action === 'confirm'));
      res.json({ success: true, request: db.prepare('SELECT * FROM transport_requests WHERE id = ?').get(id) });
    } catch (error) {
      res.status(error.status || 500).json({ success: false, message: error.status ? error.message : 'Impossible de finaliser la demande' });
    }
  });
}

app.get('/api/conversations/:id', authMiddleware, (req, res) => {
  const conversation = ConversationModel.findById(Number(req.params.id));
  if (!conversation) return res.status(404).json({ success: false, message: 'Conversation introuvable' });
  if (!canAccessConversation(conversation, req.user.id)) return res.status(403).json({ success: false, message: 'Accès interdit' });
  const request = db.prepare('SELECT * FROM transport_requests WHERE id = ?').get(conversation.request_id);
  res.json({ success: true, conversation: { ...conversation, request_status: request.status,
    trip_id: request.trip_id, driver_finished_at: request.driver_finished_at,
    customer_confirmed_at: request.customer_confirmed_at } });
});

// ---- CONVERSATIONS & MESSAGES (Chat) ----

// A user can access a conversation only when they are one of its participants.
function canAccessConversation(conversation, userId) {
  return !!conversation && (conversation.driver_id === userId || conversation.customer_id === userId);
}

// Canonical shape of a message broadcast to conversation participants.
function buildMessagePayload(message, clientId = null) {
  // Ensure timestamps are ISO 8601 UTC (e.g., 2026-09-19T16:04:32.000Z)
  const toISO = (ts) => {
    if (!ts) return null;
    const dt = new Date(/Z$|[+-]\d\d:\d\d$/.test(ts) ? ts : ts.replace(' ', 'T') + 'Z');
    return isNaN(dt.getTime()) ? ts : dt.toISOString();
  };

  return {
    id: message.id,
    conversation_id: message.conversation_id,
    sender_id: message.sender_id,
    sender_name: message.sender_name || 'Unknown',
    message: message.message,
    is_system: message.is_system,
    created_at: toISO(message.created_at),
    read_at: toISO(message.read_at),
    client_id: clientId
  };
}

// Single source of truth for persisting and broadcasting a chat message.
// Used by both the REST endpoint and the Socket.IO 'send-message' handler so a
// message is created exactly once regardless of the transport used.
function deliverMessage(conversationId, senderId, message, clientId = null) {
  const messageId = MessageModel.create(conversationId, senderId, message);
  const created = MessageModel.findById(messageId);
  const payload = buildMessagePayload(created, clientId);
  io.to(`conversation-${conversationId}`).emit('message-received', payload);
  return payload;
}

// Let conversation participants know that messages have been read.
function broadcastReadReceipt(conversationId, readerId, messageIds) {
  if (!messageIds || messageIds.length === 0) return;
  io.to(`conversation-${conversationId}`).emit('messages-read', {
    conversation_id: conversationId,
    reader_id: readerId,
    message_ids: messageIds,
    read_at: new Date().toISOString()
  });
}

// POST /api/conversations - Legacy accepted-request conversation endpoint
app.post('/api/conversations', authMiddleware, (req, res) => {
  try {
    const { request_id } = req.body;

    if (!request_id) {
      return res.status(400).json({
        success: false,
        message: 'Request ID is required'
      });
    }

    // Get request
    const request = TransportRequestModel.findById(request_id);
    if (!request) {
      return res.status(404).json({
        success: false,
        message: 'Request not found'
      });
    }

    // Get trip to find driver
    const trip = TripModel.findById(request.trip_id);
    if (!trip) {
      return res.status(404).json({
        success: false,
        message: 'Trip not found'
      });
    }

    // Verify user is either driver or customer of this request
    if (req.user.id !== trip.driver_id && req.user.id !== request.customer_id) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    const conversation = ConversationModel.findOrCreateByRequestId(request_id);

    res.status(201).json({
      success: true,
      message: 'Conversation created',
      conversation
    });
  } catch (error) {
    console.error('Create conversation error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/conversations/find-or-create - Find or create a request conversation.
app.post('/api/conversations/find-or-create', authMiddleware, (req, res) => {
  try {
    const otherUserId = Number(req.body.otherUserId ?? req.body.other_user_id);
    const requestIdValue = req.body.requestId ?? req.body.request_id;
    if (requestIdValue === undefined || requestIdValue === null || requestIdValue === '') {
      return res.status(400).json({ success: false, error: 'requestId is required', message: 'requestId is required' });
    }
    const requestId = Number(requestIdValue);
    const otherUser = UserModel.findById(otherUserId);

    if (!Number.isInteger(otherUserId) || !otherUser || otherUserId === req.user.id) {
      return res.status(400).json({ success: false, message: 'A valid other user is required' });
    }
    if (otherUser.role === req.user.role) {
      return res.status(400).json({ success: false, message: 'Conversations require a driver and a customer' });
    }
    if (!Number.isInteger(requestId) || !TransportRequestModel.findById(requestId)) {
      return res.status(400).json({ success: false, message: 'Invalid request ID' });
    }

    const driverId = req.user.role === 'DRIVER' ? req.user.id : otherUserId;
    const customerId = req.user.role === 'CUSTOMER' ? req.user.id : otherUserId;
    const request = TransportRequestModel.findById(requestId);
    const trip = request && TripModel.findById(request.trip_id);
    if (!request || !trip || request.customer_id !== customerId || trip.driver_id !== driverId) {
      return res.status(403).json({ success: false, message: 'Request does not belong to this conversation' });
    }

    const conversation = ConversationModel.findOrCreateByRequestId(requestId);
    res.status(200).json({ success: true, conversation });
  } catch (error) {
    console.error('Find or create conversation error:', error);
    res.status(500).json({ success: false, message: 'Internal server error' });
  }
});

// GET /api/conversations - Get all conversations for current user
app.get('/api/conversations', authMiddleware, (req, res) => {
  try {
    const conversations = ConversationModel.findByUserId(req.user.id);

    // Enrich with last message and unread count
    const enriched = conversations.map(conv => {
      const lastMessage = MessageModel.getLastMessage(conv.id);
      const unreadCount = MessageModel.getUnreadCount(conv.id, req.user.id);

      return {
        ...conv,
        last_message: lastMessage,
        unread_count: unreadCount.count
      };
    });

    res.json({
      success: true,
      conversations: enriched
    });
  } catch (error) {
    console.error('Get conversations error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/conversations/:id/messages - Get messages for a conversation
app.get('/api/conversations/:id/messages', authMiddleware, (req, res) => {
  try {
    const conversationId = parseInt(req.params.id);
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    // Verify user has access to conversation
    const conversation = ConversationModel.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found'
      });
    }

    if (!canAccessConversation(conversation, req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized access to conversation'
      });
    }

    // Collect the messages about to be marked as read so the other
    // participant can be notified with a read receipt.
    const unreadIds = MessageModel.findByConversationId(conversationId, limit, offset)
      .filter(m => m.sender_id !== req.user.id && m.read_at == null)
      .map(m => m.id);

    // Mark all unread messages as read
    MessageModel.markConversationAsRead(conversationId, req.user.id);

    // Get messages (read_at now populated for the messages just read)
    const messages = MessageModel.findByConversationId(conversationId, limit, offset);

    broadcastReadReceipt(conversationId, req.user.id, unreadIds);

    res.json({
      success: true,
      messages
    });
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/conversations/:id/messages - Send a message
app.post('/api/conversations/:id/messages', authMiddleware, (req, res) => {
  try {
    const conversationId = parseInt(req.params.id);
    const { message, client_id } = req.body;

    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Message is required and must not be empty'
      });
    }

    // Verify user has access to conversation
    const conversation = ConversationModel.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: 'Conversation not found'
      });
    }

    if (!canAccessConversation(conversation, req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized access to conversation'
      });
    }

    // Determine the other user
    const otherUserId = req.user.id === conversation.driver_id ? conversation.customer_id : conversation.driver_id;

    // Persist once and broadcast to every connected participant.
    const payload = deliverMessage(conversationId, req.user.id, message.trim(), client_id || null);

    // Notify the other user if they're not currently in the conversation
    const senderProfile = ProfileModel.findByUserId(req.user.id);
    createNotification(otherUserId,
      `New message from ${senderProfile?.full_name || 'Someone'}`,
      message.trim().substring(0, 100),
      NOTIFICATION_TYPES.NEW_MESSAGE,
      conversationId,
      conversationId,
      null,
      null
    );

    res.status(201).json({
      success: true,
      message: 'Message sent',
      data: payload
    });
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PATCH /api/messages/:id/read - Mark message as read
app.patch('/api/messages/:id/read', authMiddleware, (req, res) => {
  try {
    const messageId = parseInt(req.params.id);
    const message = MessageModel.findById(messageId);

    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message not found'
      });
    }

    // Verify user has access to conversation
    const conversation = ConversationModel.findById(message.conversation_id);
    if (!canAccessConversation(conversation, req.user.id)) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    // Only the recipient of an unread message triggers a read receipt.
    const shouldNotify = message.read_at == null && message.sender_id !== req.user.id;

    // Mark as read
    MessageModel.markAsRead(messageId);
    const updatedMessage = MessageModel.findById(messageId);

    if (shouldNotify) {
      broadcastReadReceipt(message.conversation_id, req.user.id, [messageId]);
    }

    res.json({
      success: true,
      message: 'Message marked as read',
      data: updatedMessage
    });
  } catch (error) {
    console.error('Mark message as read error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ============================================
// NOTIFICATION API ENDPOINTS
// ============================================

// GET /api/notifications - Get all notifications for current user
app.get('/api/notifications', authMiddleware, (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;

    const notifications = NotificationModel.findByUserId(req.user.id, limit, offset);
    const unreadCount = NotificationModel.getUnreadCount(req.user.id);

    res.json({
      success: true,
      notifications,
      unread_count: unreadCount.count
    });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PATCH /api/notifications/:id/read - Mark notification as read
app.patch('/api/notifications/:id/read', authMiddleware, (req, res) => {
  try {
    const notificationId = parseInt(req.params.id);

    const notification = NotificationModel.findById(notificationId);
    if (!notification) {
      return res.status(404).json({
        success: false,
        message: 'Notification not found'
      });
    }

    // Verify ownership
    if (notification.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized'
      });
    }

    NotificationModel.markAsRead(notificationId);
    const updatedNotification = NotificationModel.findById(notificationId);

    res.json({
      success: true,
      message: 'Notification marked as read',
      notification: updatedNotification
    });
  } catch (error) {
    console.error('Mark notification as read error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// PATCH /api/notifications/read-all - Mark all notifications as read
app.patch('/api/notifications/read-all', authMiddleware, (req, res) => {
  try {
    const count = NotificationModel.markAllAsRead(req.user.id);

    res.json({
      success: true,
      message: 'All notifications marked as read',
      updated_count: count
    });
  } catch (error) {
    console.error('Mark all notifications as read error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ============================================
// RATINGS API ENDPOINTS
// ============================================

// POST /api/ratings - Create a rating
app.post('/api/ratings', authMiddleware, (req, res) => {
  try {
    const { trip_id, request_id, reviewed_user_id, rating, comment } = req.body;

    // Validate required fields
    if (!trip_id || !request_id || !reviewed_user_id || rating === undefined) {
      return res.status(400).json({
        success: false,
        message: 'trip_id, request_id, reviewed_user_id, and rating are required'
      });
    }

    // Validate rating range
    const ratingValue = rating;
    if (!Number.isInteger(ratingValue) || ratingValue < 1 || ratingValue > 5) {
      return res.status(400).json({
        success: false,
        message: 'Rating must be an integer between 1 and 5'
      });
    }

    if (![trip_id, request_id, reviewed_user_id].every(id => Number.isSafeInteger(id) && id > 0)) {
      return res.status(400).json({ success: false, message: 'Invalid rating identifiers' });
    }
    if (comment != null && (typeof comment !== 'string' || comment.length > 500)) {
      return res.status(400).json({ success: false, message: 'Comment must be text of at most 500 characters' });
    }
    // Check if user can rate this request
    const canRateResult = RatingModel.canRate(request_id, req.user.id);
    if (!canRateResult.canRate) {
      return res.status(403).json({
        success: false,
        message: canRateResult.reason
      });
    }

    // Verify the reviewed_user_id matches the expected other party
    if (canRateResult.reviewedUserId !== reviewed_user_id || canRateResult.tripId !== trip_id) {
      return res.status(400).json({
        success: false,
        message: 'Invalid reviewed user'
      });
    }

    // Create the rating
    const ratingId = RatingModel.create({
      trip_id,
      request_id,
      reviewer_id: req.user.id,
      reviewed_user_id,
      rating: ratingValue,
      comment: comment?.trim() || null
    });

    const createdRating = RatingModel.findById(ratingId);

    // Notify the reviewed user
    const reviewerProfile = ProfileModel.findByUserId(req.user.id);
    createNotification(reviewed_user_id,
      'Nouvelle évaluation',
      `${reviewerProfile?.full_name || 'Quelqu\'un'} vous a évalué ${ratingValue} étoile${ratingValue > 1 ? 's' : ''}.`,
      NOTIFICATION_TYPES.NEW_RATING,
      ratingId,
      null,
      trip_id,
      request_id
    );

    res.status(201).json({
      success: true,
      message: 'Rating submitted successfully',
      rating: createdRating
    });
  } catch (error) {
    if (error.message && error.message.includes('UNIQUE constraint failed')) {
      return res.status(409).json({
        success: false,
        message: 'You have already rated this transport'
      });
    }
    console.error('Create rating error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/users/:id/ratings - Get all ratings for a user
app.get('/api/users/:id/ratings', authMiddleware, (req, res) => {
  try {
    const userId = Number(req.params.id);

    if (!Number.isSafeInteger(userId) || userId <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Invalid user ID'
      });
    }

    // Check if user exists
    const user = UserModel.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const ratings = RatingModel.findByUserId(userId);

    res.json({
      success: true,
      average_rating: RatingModel.getAverageRating(userId).avg,
      rating_count: ratings.length,
      ratings
    });
  } catch (error) {
    console.error('Get user ratings error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// ============================================
// WebSocket (Socket.IO)
// ============================================

// Middleware to verify socket connection
io.use((socket, next) => {
  const token = socket.handshake.auth.token;
  if (!token) {
    return next(new Error('Authentication error'));
  }

  try {
    const decoded = verifyToken(token);
    socket.userId = decoded.id;
    socket.userRole = decoded.role;
    next();
  } catch (error) {
    next(new Error('Invalid token'));
  }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log(`✓ User ${socket.userId} connected`);

  // Join user-specific room for notifications
  socket.join(`user-${socket.userId}`);

  // Join conversation room
  socket.on('join-conversation', (incomingId) => {
    const conversationId = parseInt(incomingId, 10);
    const conversation = ConversationModel.findById(conversationId);

    // Verify access
    if (!canAccessConversation(conversation, socket.userId)) {
      socket.emit('error', { message: 'Unauthorized' });
      return;
    }

    socket.join(`conversation-${conversationId}`);
    socket.conversationId = conversationId;
    socket.emit('joined-conversation', { conversation_id: conversationId });
    console.log(`✓ User ${socket.userId} joined conversation ${conversationId}`);
  });

  // Receive message: persists once and broadcasts to the whole room.
  socket.on('send-message', (data, ack) => {
    try {
      const conversationId = parseInt(data && data.conversationId, 10);
      const message = data && data.message;
      const clientId = data && data.clientId;

      if (!conversationId || !message || !String(message).trim()) {
        if (typeof ack === 'function') ack({ success: false, error: 'Missing required fields' });
        socket.emit('error', { message: 'Missing required fields' });
        return;
      }

      // Verify access
      const conversation = ConversationModel.findById(conversationId);
      if (!canAccessConversation(conversation, socket.userId)) {
        if (typeof ack === 'function') ack({ success: false, error: 'Unauthorized' });
        socket.emit('error', { message: 'Unauthorized' });
        return;
      }

      // Determine the other user
      const otherUserId = socket.userId === conversation.driver_id ? conversation.customer_id : conversation.driver_id;

      const payload = deliverMessage(conversationId, socket.userId, String(message).trim(), clientId || null);

      // Notify the other user if they're not currently in the conversation
      const senderProfile = ProfileModel.findByUserId(socket.userId);
      createNotification(otherUserId,
        `New message from ${senderProfile?.full_name || 'Someone'}`,
        String(message).trim().substring(0, 100),
        NOTIFICATION_TYPES.NEW_MESSAGE,
        conversationId
      );

      if (typeof ack === 'function') {
        ack({ success: true, data: payload });
      }
    } catch (error) {
      console.error('Send message error:', error);
      if (typeof ack === 'function') ack({ success: false, error: 'Failed to send message' });
      socket.emit('error', { message: 'Failed to send message' });
    }
  });

  // Typing indicator relayed to the other conversation participants only.
  socket.on('typing', (data) => {
    const conversationId = parseInt(data && data.conversationId, 10);
    if (!conversationId) return;

    const conversation = ConversationModel.findById(conversationId);
    if (!canAccessConversation(conversation, socket.userId)) return;

    const profile = ProfileModel.findByUserId(socket.userId);
    socket.to(`conversation-${conversationId}`).emit('typing', {
      conversation_id: conversationId,
      user_id: socket.userId,
      user_name: profile?.full_name || 'Unknown',
      is_typing: !!(data && data.isTyping)
    });
  });

  // Mark the whole conversation as read (socket equivalent of the REST PATCH).
  socket.on('mark-read', (data) => {
    const conversationId = parseInt(data && data.conversationId, 10);
    if (!conversationId) return;

    const conversation = ConversationModel.findById(conversationId);
    if (!canAccessConversation(conversation, socket.userId)) return;

    const unreadIds = MessageModel.findByConversationId(conversationId)
      .filter(m => m.sender_id !== socket.userId && m.read_at == null)
      .map(m => m.id);

    const changed = MessageModel.markConversationAsRead(conversationId, socket.userId);
    if (changed > 0) {
      broadcastReadReceipt(conversationId, socket.userId, unreadIds);
    }
  });

  // Leave conversation
  socket.on('leave-conversation', (incomingId) => {
    const conversationId = parseInt(incomingId, 10);
    socket.leave(`conversation-${conversationId}`);
    if (socket.conversationId === conversationId) {
      socket.conversationId = null;
    }
    console.log(`✓ User ${socket.userId} left conversation ${conversationId}`);
  });

  // Disconnect
  socket.on('disconnect', () => {
    console.log(`✓ User ${socket.userId} disconnected`);
  });
});


// Start server
const httpServer = server.listen(PORT, () => {
  console.log(`✓ Backend server running on http://localhost:${PORT}`);
  console.log(`✓ Health check: http://localhost:${PORT}/api/health`);
  console.log(`✓ API endpoints:`);
  console.log(`  POST /api/auth/register`);
  console.log(`  POST /api/auth/login`);
  console.log(`  GET  /api/auth/me`);
  console.log(`  PUT  /api/profile`);
  console.log(`  POST /api/cargaisons`);
  console.log(`  GET  /api/cargaisons/my`);
  console.log(`  GET  /api/cargaisons/:id`);
  console.log(`  PUT  /api/cargaisons/:id`);
  console.log(`  POST /api/cargaisons/:id/status`);
  console.log(`  DELETE /api/cargaisons/:id`);
  console.log(`  POST /api/trips`);
  console.log(`  GET  /api/trips/my`);
  console.log(`  GET  /api/trips/:id`);
  console.log(`  PUT  /api/trips/:id`);
  console.log(`  DELETE /api/trips/:id`);
  console.log(`  POST /api/trips/:id/start | complete | cancel`);
  console.log(`  GET  /api/trips/history`);
  console.log(`  POST /api/conversations`);
  console.log(`  GET  /api/conversations`);
  console.log(`  GET  /api/conversations/:id/messages`);
  console.log(`  POST /api/conversations/:id/messages`);
  console.log(`  PATCH /api/messages/:id/read`);
  console.log(`  GET  /api/notifications`);
  console.log(`  PATCH /api/notifications/:id/read`);
  console.log(`  PATCH /api/notifications/read-all`);
  console.log(`  POST /api/ratings`);
  console.log(`  GET  /api/users/:id/ratings`);
  console.log(`✓ WebSocket: ws://localhost:${PORT}`);
});
