require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { UserModel, ProfileModel, TruckModel, TripModel, CargaisonModel } = require('./models');
const { generateToken, authMiddleware } = require('./auth');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Register endpoint
app.post('/api/auth/register', async (req, res) => {
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
app.post('/api/auth/login', async (req, res) => {
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
    if (!getOwnedTruck(req, res, data.truck_id)) {
      return;
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
    if (!getOwnedTruck(req, res, data.truck_id)) {
      return;
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

// Complete a trip (IN_PROGRESS -> COMPLETED)
app.post('/api/trips/:id/complete', authMiddleware, isDriverMiddleware, (req, res) => {
  try {
    const trip = getOwnedTrip(req, res);
    if (!trip) {
      return;
    }

    if (trip.status !== 'IN_PROGRESS') {
      return res.status(400).json({
        success: false,
        message: 'Only in-progress trips can be completed'
      });
    }

    TripModel.updateStatus(trip.id, 'COMPLETED');
    const updatedTrip = TripModel.findById(trip.id);

    res.json({
      success: true,
      message: 'Return trip completed successfully',
      trip: updatedTrip
    });
  } catch (error) {
    console.error('Complete trip error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
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

    TripModel.updateStatus(trip.id, 'CANCELLED');
    const updatedTrip = TripModel.findById(trip.id);

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

// Start server
const server = app.listen(PORT, () => {
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
});
