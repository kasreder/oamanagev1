import { randomUUID } from 'crypto';

const DEFAULT_TTL = 3600; // seconds

export class TokenManager {
  constructor({ ttlSeconds = DEFAULT_TTL } = {}) {
    this.ttlSeconds = ttlSeconds;
    this.tokens = new Map();
  }

  issue(username) {
    const token = randomUUID();
    const expiresAt = Date.now() + this.ttlSeconds * 1000;
    this.tokens.set(token, { username, expiresAt });
    return { token, expiresIn: this.ttlSeconds };
  }

  verify(token) {
    if (!token) return false;
    const record = this.tokens.get(token);
    if (!record) return false;
    if (record.expiresAt < Date.now()) {
      this.tokens.delete(token);
      return false;
    }
    return true;
  }

  cleanup() {
    const now = Date.now();
    for (const [token, record] of this.tokens.entries()) {
      if (record.expiresAt < now) {
        this.tokens.delete(token);
      }
    }
  }
}

export function createAuthMiddleware(tokenManager) {
  return (req, res, next) => {
    const authHeader = req.get('authorization');
    if (!authHeader) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }
    const [scheme, token] = authHeader.split(' ');
    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }
    if (!tokenManager.verify(token)) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }
    return next();
  };
}
