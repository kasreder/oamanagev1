import { Router } from 'express';

export function createAuthRouter(tokenManager) {
  const router = Router();

  router.post('/token', (req, res) => {
    const { username, password } = req.body ?? {};
    if (!username || !password) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: 'username and password are required' });
    }
    const issued = tokenManager.issue(username);
    return res.json({ access_token: issued.token, expires_in: issued.expiresIn });
  });

  router.post('/refresh', (req, res) => {
    const { refresh_token: refreshToken } = req.body ?? {};
    if (!refreshToken || !tokenManager.verify(refreshToken)) {
      return res.status(401).json({ error: 'UNAUTHORIZED' });
    }
    const issued = tokenManager.issue('refresh');
    return res.json({ access_token: issued.token, expires_in: issued.expiresIn });
  });

  return router;
}
