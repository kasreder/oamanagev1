import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const assetsRouter = Router();

assetsRouter.get('/', async (req, res, next) => {
  try {
    const { q, status, team, page, pageSize } = req.query;
    const result = await dataStore.listAssets({ q, status, team, page, pageSize });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
});

assetsRouter.get('/:uid', async (req, res, next) => {
  try {
    const { uid } = req.params;
    const detail = await dataStore.getAssetDetail(uid);
    if (!detail) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'asset', id: uid });
    }
    return res.json(detail);
  } catch (error) {
    return next(error);
  }
});

assetsRouter.post('/', async (req, res, next) => {
  try {
    const payload = req.body ?? {};
    const { asset, created } = await dataStore.upsertAsset(payload);
    return res.status(created ? 201 : 200).json({ uid: asset.uid, created });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: error.message });
    }
    return next(error);
  }
});

assetsRouter.delete('/:uid', async (req, res, next) => {
  try {
    const { uid } = req.params;
    const asset = await dataStore.softDeleteAsset(uid);
    if (!asset) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'asset', id: uid });
    }
    return res.json({ uid: asset.uid, status: asset.status });
  } catch (error) {
    return next(error);
  }
});
