import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const inspectionsRouter = Router();

inspectionsRouter.get('/', async (req, res, next) => {
  try {
    const { assetUid, synced, from, to, page, pageSize } = req.query;
    const result = await dataStore.listInspections({ assetUid, synced, from, to, page, pageSize });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
});

inspectionsRouter.post('/', async (req, res, next) => {
  try {
    const payload = req.body ?? {};
    const record = await dataStore.createInspection(payload);
    return res.status(201).json({ ...record, synced: record.synced });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: error.message });
    }
    return next(error);
  }
});

inspectionsRouter.patch('/:id', async (req, res, next) => {
  const { id } = req.params;
  try {
    const record = await dataStore.updateInspection(id, req.body ?? {});
    return res.json(record);
  } catch (error) {
    if (error instanceof Error && error.message.includes('not found')) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'inspection', id });
    }
    return next(error);
  }
});

inspectionsRouter.delete('/:id', async (req, res, next) => {
  try {
    const { id } = req.params;
    const deleted = await dataStore.deleteInspection(id);
    if (!deleted) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'inspection', id });
    }
    return res.status(204).send();
  } catch (error) {
    return next(error);
  }
});
