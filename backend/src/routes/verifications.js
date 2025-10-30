import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import { randomUUID } from 'crypto';
import { dataStore } from '../data-store.js';

const signatureDir = dataStore.getSignatureDirectory();

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, signatureDir),
  filename: (req, file, cb) => {
    const signatureId = randomUUID();
    const fileName = `signature-${signatureId}.png`;
    req.signatureUpload = { signatureId, fileName };
    cb(null, fileName);
  },
});

const upload = multer({
  storage,
  fileFilter: (_req, file, cb) => {
    const mime = file.mimetype;
    if (!mime || !mime.includes('png')) {
      return cb(new Error('Only PNG signatures are supported'));
    }
    return cb(null, true);
  },
});

export const verificationsRouter = Router();

verificationsRouter.get('/', async (req, res, next) => {
  try {
    const { team, assetUid, page, pageSize } = req.query;
    const result = await dataStore.listVerifications({ team, assetUid, page, pageSize });
    return res.json(result);
  } catch (error) {
    return next(error);
  }
});

verificationsRouter.get('/:assetUid', async (req, res, next) => {
  try {
    const { assetUid } = req.params;
    const detail = await dataStore.getVerificationDetail(assetUid);
    if (!detail) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'verification', id: assetUid });
    }
    return res.json(detail);
  } catch (error) {
    return next(error);
  }
});

verificationsRouter.post('/:assetUid/signatures', upload.single('file'), async (req, res, next) => {
  const { assetUid } = req.params;
  try {
    const uploadMeta = req.signatureUpload;
    if (!uploadMeta) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: 'file is required' });
    }
    const metadata = await dataStore.recordSignature(assetUid, {
      signatureId: uploadMeta.signatureId,
      fileName: uploadMeta.fileName,
      storedAt: new Date(),
      userId: req.body?.userId,
      userName: req.body?.userName,
    });
    await dataStore.persistSignatures();
    return res.status(201).json({
      signatureId: metadata.signatureId,
      storageLocation: `/verifications/${assetUid}/signatures`,
      signatureMeta: metadata,
    });
  } catch (error) {
    if (error instanceof Error) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: error.message });
    }
    return next(error);
  }
});

verificationsRouter.get('/:assetUid/signatures', async (req, res, next) => {
  try {
    const { assetUid } = req.params;
    const filePath = await dataStore.getSignatureFilePath(assetUid);
    if (!filePath) {
      return res.status(404).json({ error: 'NOT_FOUND', resource: 'signature', id: assetUid });
    }
    return res.sendFile(path.resolve(filePath));
  } catch (error) {
    return next(error);
  }
});

verificationsRouter.post('/batch', async (req, res, next) => {
  try {
    const { assetUids = [], signatureId, applyToAll } = req.body ?? {};
    if (!signatureId) {
      return res.status(400).json({ error: 'INVALID_INPUT', message: 'signatureId is required' });
    }
    const targets = applyToAll ? await dataStore.getAllAssetUids() : assetUids;
    const applied = await dataStore.batchAssignSignature({ assetUids: targets ?? [], signatureId });
    await dataStore.persistSignatures();
    return res.json({ applied, signatureId });
  } catch (error) {
    if (error instanceof Error && error.message.includes('signatureId')) {
      return res.status(404).json({ error: 'NOT_FOUND', message: error.message });
    }
    return next(error);
  }
});
