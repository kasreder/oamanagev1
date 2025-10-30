import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const referencesRouter = Router();

referencesRouter.get('/users', (req, res) => {
  const { q, team } = req.query;
  const users = dataStore.searchUsers({ q, team });
  return res.json({ items: users });
});

referencesRouter.get('/assets', (req, res) => {
  const { q } = req.query;
  const assets = dataStore.searchAssetRefs({ q });
  return res.json({ items: assets });

});
