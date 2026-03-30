// Root-level Vercel serverless entry for the unified monorepo deployment.
// Vercel auto-detects files in the root api/ directory as serverless functions.
// All /api/* requests are rewritten here (see root vercel.json).
//
// Note: apps/node_backend/api/index.ts is a separate entry used when deploying
// only the backend standalone (via apps/node_backend/vercel.json).
import app from '../apps/node_backend/src/app.js';

export default app;
