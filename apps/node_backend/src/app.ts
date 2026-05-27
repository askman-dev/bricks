import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.js';
import configRoutes from './routes/config.js';
import llmRoutes from './routes/llm.js';
import chatRoutes from './routes/chat.js';
import platformRoutes from './routes/platform.js';
import resourcesRoutes from './routes/resources.js';
import cronRoutes from './routes/cron.js';
import { runMigrations } from './db/migrate.js';

// Load environment variables (no-op in Vercel production where env vars are injected directly)
dotenv.config();

const app = express();

// Only enable trust proxy when running behind Vercel (or another trusted proxy),
// so non-proxied environments keep the safer default behavior.
if (process.env.VERCEL || process.env.VERCEL_ENV) {
  app.set('trust proxy', 1);
}

// Security middleware
app.use(helmet());

// CORS configuration
const corsOrigin = process.env.CORS_ORIGIN || '*';
const corsOptions =
  corsOrigin === '*'
    ? {
        origin: '*',
        credentials: false,
      }
    : {
        origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
          const allowedOrigins = corsOrigin.split(',').map((o) => o.trim());
          if (!origin) {
            return callback(null, false);
          }
          if (allowedOrigins.includes(origin)) {
            return callback(null, true);
          }
          return callback(new Error('Not allowed by CORS'), false);
        },
        credentials: true,
      };

app.use(cors(corsOptions));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Run database migrations once per process / Vercel cold start.
// The promise is cached so subsequent requests incur no overhead.
let _migrationsPromise: Promise<void> | null = null;

function shouldRunMigrations(): boolean {
  return process.env.AUTO_MIGRATE !== 'false';
}

function ensureMigrations(): Promise<void> {
  if (!shouldRunMigrations()) {
    return Promise.resolve();
  }

  if (!_migrationsPromise) {
    _migrationsPromise = runMigrations();
    // On failure reset the cache so the next request retries.
    _migrationsPromise.catch(() => {
      _migrationsPromise = null;
    });
  }
  return _migrationsPromise;
}

// Ensure migrations have run before handling any request.
// On migration failure, forward the error to Express's error handler so the
// caller receives a proper 500 response instead of a cryptic DB table error.
app.use((_req: Request, _res: Response, next: NextFunction) => {
  ensureMigrations().then(() => next()).catch((err: unknown) => next(err));
});

// Health check endpoint (under /api/ prefix for unified Vercel routing)
app.get('/api/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api', authRoutes);
app.use('/api/config', configRoutes);
app.use('/api/llm', llmRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/v1/platform', platformRoutes);
app.use('/api/resources', resourcesRoutes);
// Cron routes do NOT use the JWT authenticate middleware — they use CRON_SECRET.
app.use('/api/cron', cronRoutes);

// 404 handler
app.use((req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler
app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

export default app;
