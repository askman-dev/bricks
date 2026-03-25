import jwt from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';

export interface AuthRequest extends Request {
  userId?: string;
}

interface JWTPayload {
  userId: string;
  iat?: number;
}

function getJWTSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error('JWT_SECRET environment variable is not set');
  }
  return secret;
}

// Generate JWT token for user
export function generateToken(userId: string): string {
  return jwt.sign(
    { userId },
    getJWTSecret()
  );
}

// Verify JWT token
export function verifyToken(token: string): JWTPayload {
  return jwt.verify(token, getJWTSecret()) as JWTPayload;
}

// Authentication middleware
export function authenticate(req: AuthRequest, res: Response, next: NextFunction): void {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'No token provided' });
      return;
    }

    const token = authHeader.substring(7);
    const payload = verifyToken(token);

    req.userId = payload.userId;
    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      res.status(401).json({ error: 'Invalid token' });
    } else {
      res.status(500).json({ error: 'Internal server error' });
    }
  }
}

// Optional authentication (allows anonymous access)
export function optionalAuth(req: AuthRequest, res: Response, next: NextFunction): void {
  try {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const payload = verifyToken(token);
      req.userId = payload.userId;
    }

    next();
  } catch (error) {
    // Ignore auth errors for optional auth
    next();
  }
}
