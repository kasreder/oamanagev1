import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const referencesRouter = Router();

referencesRouter.get('/users', async (req, res, next) => {
  try {
    const { q, team } = req.query;
    const users = await dataStore.searchUsers({ q, team });
    return res.json({ items: users });
  } catch (error) {
    return next(error);
  }
});

referencesRouter.get('/assets', async (req, res, next) => {
  try {
    const { q } = req.query;
    const assets = await dataStore.searchAssetRefs({ q });
    return res.json({ items: assets });
  } catch (error) {
    return next(error);
  }
});
