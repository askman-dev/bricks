import type { VercelRequest, VercelResponse } from '@vercel/node';

type AppHandler = (req: VercelRequest, res: VercelResponse) => void | Promise<void>;

let appHandlerPromise: Promise<AppHandler> | null = null;

const loadAppHandler = async (): Promise<AppHandler> => {
  if (!appHandlerPromise) {
    appHandlerPromise = import('../apps/node_backend/src/app').then(
      (mod: { default: AppHandler }) => mod.default,
    );
  }

  return appHandlerPromise;
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const app = await loadAppHandler();
  return app(req, res);
}
