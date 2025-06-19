const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(cors());
app.use(express.json());

// Health check endpoint for DigitalOcean
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy',
    service: 'messagequest-server',
    timestamp: new Date().toISOString()
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'MessageQuest Server',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      info: '/info'
    }
  });
});

// Info endpoint
app.get('/info', (req, res) => {
  res.json({
    environment: process.env.NODE_ENV || 'development',
    supabase: {
      url: process.env.SUPABASE_URL || 'Not configured',
      configured: !!(process.env.SUPABASE_URL && process.env.SERVICE_ROLE_KEY)
    },
    services: {
      database: 'PostgreSQL (via Supabase)',
      auth: 'Supabase Auth',
      realtime: 'Supabase Realtime',
      storage: 'Supabase Storage',
      edge_functions: 'Supabase Edge Functions'
    }
  });
});

// Note: The actual API endpoints are handled by Supabase
// This server primarily serves health checks for DigitalOcean

app.listen(PORT, () => {
  console.log(`MessageQuest server running on port ${PORT}`);
});