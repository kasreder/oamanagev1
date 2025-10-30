import { Router } from 'express';
import { dataStore } from '../data-store.js';

export const inspectionsRouter = Router();

inspectionsRouter.get('/', (req, res) => {
  const { assetUid, synced, from, to, page, pageSize } = req.query;
  const result = dataStore.listInspections({ assetUid, synced, from, to, page, pageSize });
  return res.json(result);
});

inspectionsRouter.post('/', (req, res) => {
  try {
    const payload = req.body ?? {};
    const record = dataStore.createInspection(payload);
    return res.status(201).json({ ...record, synced: record.synced });
  } catch (error) {
    return res.status(400).json({ error: 'INVALID_INPUT', message: error.message });
  }
});

inspectionsRouter.patch('/:id', (req, res) => {
  const { id } = req.params;
  try {
    const record = dataStore.updateInspection(id, req.body ?? {});
    return res.json(record);
  } catch (error) {
    return res.status(404).json({ error: 'NOT_FOUND', resource: 'inspection', id });
  }
});

inspectionsRouter.delete('/:id', (req, res) => {
  const { id } = req.params;
  const deleted = dataStore.deleteInspection(id);
  if (!deleted) {
    return res.status(404).json({ error: 'NOT_FOUND', resource: 'inspection', id });
  }
  return res.status(204).send();

});
