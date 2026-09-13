require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { UserModel, ProfileModel } = require('./models');
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

// Start server
app.listen(PORT, () => {
  console.log(`✓ Backend server running on http://localhost:${PORT}`);
  console.log(`✓ Health check: http://localhost:${PORT}/api/health`);
  console.log(`✓ API endpoints:`);
  console.log(`  POST /api/auth/register`);
  console.log(`  POST /api/auth/login`);
  console.log(`  GET  /api/auth/me`);
  console.log(`  PUT  /api/profile`);
});
