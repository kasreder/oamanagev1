import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const assetsRouter = Router();

assetsRouter.get('/', (req, res) => {
  const { q, status, team, page, pageSize } = req.query;
  const result = dataStore.listAssets({ q, status, team, page, pageSize });
  return res.json(result);
});

assetsRouter.get('/:uid', (req, res) => {
  const { uid } = req.params;
  const detail = dataStore.getAssetDetail(uid);
  if (!detail) {
    return res.status(404).json({ error: 'NOT_FOUND', resource: 'asset', id: uid });
  }
  return res.json(detail);
});

assetsRouter.post('/', (req, res) => {
  try {
    const payload = req.body ?? {};
    const { asset, created } = dataStore.upsertAsset(payload);
    return res.status(created ? 201 : 200).json({ uid: asset.uid, created });
  } catch (error) {
    return res.status(400).json({ error: 'INVALID_INPUT', message: error.message });
  }
});

assetsRouter.delete('/:uid', (req, res) => {
  const { uid } = req.params;
  const asset = dataStore.softDeleteAsset(uid);
  if (!asset) {
    return res.status(404).json({ error: 'NOT_FOUND', resource: 'asset', id: uid });
  }
  return res.json({ uid: asset.uid, status: asset.status });
});
