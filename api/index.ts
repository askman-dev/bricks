import type { VercelRequest, VercelResponse } from '@vercel/node';
import app from '../apps/node_backend/src/app';

type AppHandler = (req: VercelRequest, res: VercelResponse) => void | Promise<void>;

export default async function handler(req: VercelRequest, res: VercelResponse) {
  return app(req, res);
}
