interface ReturnToValidationOptions {
  callbackUrl?: string;
  nodeEnv?: string;
  allowedReturnOrigins?: string;
}

export function isAllowedReturnTo(
  rawReturnTo: string,
  options: ReturnToValidationOptions = {}
): boolean {
  let parsed: URL;
  try {
    parsed = new URL(rawReturnTo);
  } catch {
    return false;
  }

  const nodeEnv = options.nodeEnv ?? process.env.NODE_ENV;
  const callbackUrl = options.callbackUrl;
  const allowedReturnOrigins = options.allowedReturnOrigins ?? '';

  const isLocalhost = parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1';
  if (isLocalhost) {
    if (nodeEnv === 'production') {
      // Disallow localhost/loopback redirects in production to avoid open redirect to local services.
      return false;
    }
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  }

  if (parsed.protocol !== 'https:') {
    return false;
  }

  // Required preview pattern:
  //   https://bricks-<alnum>-askman-dev.vercel.app
  if (/^bricks-[A-Za-z0-9]+-askman-dev\.vercel\.app$/u.test(parsed.hostname)) {
    return true;
  }

  if (callbackUrl) {
    try {
      const callbackOrigin = new URL(callbackUrl).origin;
      if (parsed.origin === callbackOrigin) {
        return true;
      }
    } catch {
      // Ignore invalid callback URL config and fall back to explicit allowlist.
    }
  }

  const configuredOrigins = allowedReturnOrigins
    .split(',')
    .map(v => v.trim())
    .filter(Boolean);
  const normalizedOrigins = new Set<string>();
  for (const value of configuredOrigins) {
    try {
      normalizedOrigins.add(new URL(value).origin);
    } catch {
      // Ignore invalid URL entries in OAUTH_ALLOWED_RETURN_ORIGINS
    }
  }

  return normalizedOrigins.has(parsed.origin);
}
