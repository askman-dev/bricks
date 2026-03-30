import { testConnection } from './db/index.js';
import { runMigrations } from './db/migrate.js';
import app from './app.js';

const PORT = process.env.PORT || 3000;

// Start server
async function startServer() {
  try {
    console.log('Starting Bricks Backend Service...');

    // Test database connection
    const dbConnected = await testConnection();
    if (!dbConnected) {
      throw new Error('Database connection failed');
    }

    // Run migrations
    if (process.env.AUTO_MIGRATE !== 'false') {
      await runMigrations();
    }

    // Start listening
    app.listen(PORT, () => {
      console.log(`✓ Server running on port ${PORT}`);
      console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
      console.log(`✓ Health check: http://localhost:${PORT}/api/health`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

startServer();
