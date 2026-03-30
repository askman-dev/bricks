import express, { Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.js';
import configRoutes from './routes/config.js';

// Load environment variables (no-op in Vercel production where env vars are injected directly)
dotenv.config();

const app = express();

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

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
});

app.use('/api/', limiter);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check endpoint (under /api/ prefix for unified Vercel routing)
app.get('/api/health', (req: Request, res: Response) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api/auth', authRoutes);
app.use('/api', authRoutes);
app.use('/api/config', configRoutes);

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
