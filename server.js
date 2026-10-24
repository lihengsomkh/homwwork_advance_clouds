'use strict';

const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';
const ENVIRONMENT = process.env.NODE_ENV || 'development';

// Middleware for basic logging and request timing
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl} ${res.statusCode} - ${duration}ms`);
  });
  next();
});

// JSON body parser
app.use(express.json());

// Root endpoint: displays service information and replica container details
app.get('/', (req, res) => {
  res.status(200).json({
    status: 'success',
    service: 'cloud-microservice',
    message: 'CI/CD Automated Deployment on AWS Docker Swarm Cluster',
    version: APP_VERSION,
    environment: ENVIRONMENT,
    nodeVersion: process.version,
    instance: {
      hostname: os.hostname(),
      platform: os.platform(),
      architecture: os.arch(),
      uptimeSeconds: Math.floor(process.uptime()),
    },
    timestamp: new Date().toISOString()
  });
});

// Liveness and readiness probe endpoint for Docker HEALTHCHECK and Swarm routing
app.get('/health', (req, res) => {
  const memory = process.memoryUsage();
  res.status(200).json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memoryUsageMb: {
      rss: +(memory.rss / (1024 * 1024)).toFixed(2),
      heapTotal: +(memory.heapTotal / (1024 * 1024)).toFixed(2),
      heapUsed: +(memory.heapUsed / (1024 * 1024)).toFixed(2)
    }
  });
});

// Detailed system info endpoint for verification
app.get('/api/v1/info', (req, res) => {
  res.status(200).json({
    application: 'Automated CI/CD Microservice',
    clusterEngine: 'Docker Swarm',
    cloudProvider: 'Amazon Web Services (AWS)',
    containerId: os.hostname(),
    networkInterfaces: os.networkInterfaces()
  });
});

// Catch-all 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.originalUrl}`,
    timestamp: new Date().toISOString()
  });
});

// Start HTTP Server
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`[SERVER] Cloud Microservice v${APP_VERSION} listening on port ${PORT} in ${ENVIRONMENT} mode (host: ${os.hostname()})`);
});

// Graceful shutdown handling for Docker Swarm rolling updates
const gracefulShutdown = (signal) => {
  console.log(`[SERVER] Received ${signal}. Starting graceful shutdown...`);
  server.close((err) => {
    if (err) {
      console.error('[SERVER] Error during server close:', err);
      process.exit(1);
    }
    console.log('[SERVER] Closed remaining connections. Exiting process.');
    process.exit(0);
  });

  // Force exit if connections do not close in 10s
  setTimeout(() => {
    console.error('[SERVER] Forcefully terminating after timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));
