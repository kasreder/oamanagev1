import express from 'express';
import cors from 'cors';

import { dataStore } from './data-store.js';
import { TokenManager, createAuthMiddleware } from './utils/token-manager.js';
import { createAuthRouter } from './routes/auth.js';
import { assetsRouter } from './routes/assets.js';
import { inspectionsRouter } from './routes/inspections.js';
import { verificationsRouter } from './routes/verifications.js';
import { referencesRouter } from './routes/references.js';
import { healthRouter } from './routes/health.js';

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

const tokenManager = new TokenManager();

app.use('/health', healthRouter);
app.use('/auth', createAuthRouter(tokenManager));

app.use(createAuthMiddleware(tokenManager));

app.use('/assets', assetsRouter);
app.use('/inspections', inspectionsRouter);
app.use('/verifications', verificationsRouter);
app.use('/references', referencesRouter);

app.use((err, _req, res, _next) => {
  if (err?.message?.includes('Only PNG signatures')) {
    return res.status(400).json({ error: 'INVALID_INPUT', message: err.message });
  }
  console.error('Unexpected error:', err);
  return res.status(500).json({ error: 'INTERNAL_ERROR', traceId: Date.now().toString() });
});

async function bootstrap() {
  await dataStore.initialize();
  app.listen(port, () => {
    console.log(`OA Asset Manager backend listening on port ${port}`);
  });
}

bootstrap().catch((error) => {
  console.error('Failed to start backend', error);
  process.exit(1);
});
