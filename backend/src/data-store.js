import path from 'path';
import { fileURLToPath } from 'url';
import { mkdir, readFile } from 'fs/promises';
import { createHash } from 'crypto';

import { createPoolFromEnv } from './db/pool.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DEFAULT_PAGE_SIZE = 20;
const SIGNATURE_DIR = path.resolve(__dirname, './storage');

function normalizeString(value) {
  if (value === undefined || value === null) return undefined;
  const stringValue = String(value).trim();
  return stringValue.length === 0 ? undefined : stringValue;
}

function parseBoolean(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const lowered = value.trim().toLowerCase();
    if (['true', '1', 'yes', 'y'].includes(lowered)) return true;
    if (['false', '0', 'no', 'n'].includes(lowered)) return false;
  }
  return undefined;
}

function toIsoString(value) {
  if (!value) return undefined;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return undefined;
  }
  return date.toISOString();
}

function mapMetadata(raw) {
  if (!raw) return {};
  if (typeof raw === 'string') {
    try {
      return JSON.parse(raw);
    } catch (error) {
      console.warn('Failed to parse metadata json', error);
      return {};
    }
  }
  if (typeof raw === 'object') {
    return { ...raw };
  }
  return {};
}

function composeLocation(row) {
  if (row.location_text) {
    return row.location_text;
  }
  const parts = [
    normalizeString(row.building),
    normalizeString(row.floor),
  ].filter(Boolean);
  if (row.location_row !== undefined && row.location_row !== null) {
    parts.push(`R${row.location_row}`);
  }
  if (row.location_col !== undefined && row.location_col !== null) {
    parts.push(`C${row.location_col}`);
  }
  return parts.join(' ');
}

function composeDepartment(row) {
  return [
    normalizeString(row.department_hq),
    normalizeString(row.department_dept),
    normalizeString(row.department_team),
    normalizeString(row.department_part),
  ]
    .filter(Boolean)
    .join(' > ');
}

function resolveOrganization(metadata, ownerDepartment) {
  return (
    normalizeString(metadata.organization) ??
    normalizeString(metadata.organization_team) ??
    ownerDepartment ??
    ''
  );
}

function resolveBarcodePhotoUrl(row, metadata) {
  return (
    normalizeString(row.barcode_photo_url) ??
    normalizeString(metadata.barcodePhotoUrl) ??
    normalizeString(metadata.barcode_photo_url) ??
    normalizeString(metadata.barcode_photo) ??
    undefined
  );
}

function normalizeUserId(value) {
  const normalized = normalizeString(value);
  if (normalized === undefined) {
    return undefined;
  }
  const numeric = Number.parseInt(normalized, 10);
  if (Number.isNaN(numeric)) {
    return undefined;
  }
  return numeric;
}

export class DataStore {
  constructor({ pool = createPoolFromEnv(), signatureDir = SIGNATURE_DIR, logger = console } = {}) {
    this.pool = pool;
    this.signatureDir = signatureDir;
    this.logger = logger;
  }

  async initialize() {
    await mkdir(this.signatureDir, { recursive: true });
    await this.pool.query('SELECT 1');
  }

  getSignatureDirectory() {
    return this.signatureDir;
  }

  async listAssets({ q, status, team, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    const filters = [];
    const params = [];

    if (q) {
      params.push(`%${q.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`(
        LOWER(a.uid) LIKE $${idx} OR
        LOWER(COALESCE(a.name, '')) LIKE $${idx} OR
        LOWER(COALESCE(a.asset_type, '')) LIKE $${idx} OR
        LOWER(COALESCE(a.model_name, '')) LIKE $${idx} OR
        LOWER(COALESCE(a.serial_number, '')) LIKE $${idx} OR
        LOWER(COALESCE(a.vendor, '')) LIKE $${idx}
      )`);
    }

    if (status) {
      params.push(status.trim().toLowerCase());
      const idx = params.length;
      filters.push(`LOWER(COALESCE(a.status, '')) = $${idx}`);
    }

    if (team) {
      params.push(`%${team.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`(
        LOWER(COALESCE(a.metadata->>'organization', '')) LIKE $${idx} OR
        LOWER(COALESCE(a.metadata->>'organization_team', '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_hq, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_dept, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_team, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_part, '')) LIKE $${idx}
      )`);
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const limit = Number(pageSize);
    const offset = Number(page) * limit;

    const rowsResult = await this.pool.query(
      `
      SELECT
        a.uid,
        a.name,
        a.asset_type,
        a.model_name,
        a.serial_number,
        a.vendor,
        a.status,
        a.location_text,
        a.building,
        a.floor,
        a.location_row,
        a.location_col,
        a.metadata,
        a.owner_user_id,
        a.barcode_photo_url,
        a.updated_at,
        u.name AS owner_name,
        u.department_hq,
        u.department_dept,
        u.department_team,
        u.department_part
      FROM assets a
      LEFT JOIN users u ON a.owner_user_id = u.id
      ${whereClause}
      ORDER BY a.updated_at DESC, a.uid ASC
      LIMIT $${params.length + 1}
      OFFSET $${params.length + 2}
      `,
      [...params, limit, offset]
    );

    const countResult = await this.pool.query(
      `
      SELECT COUNT(*) AS total
      FROM assets a
      LEFT JOIN users u ON a.owner_user_id = u.id
      ${whereClause}
      `,
      params
    );

    const items = rowsResult.rows.map((row) => this.#mapAssetRow(row));
    const total = Number.parseInt(countResult.rows[0]?.total ?? '0', 10);

    return {
      items,
      total,
      page: Number(page),
      pageSize: limit,
    };
  }

  async getAssetDetail(uid) {
    const result = await this.pool.query(
      `
      SELECT
        a.uid,
        a.name,
        a.asset_type,
        a.model_name,
        a.serial_number,
        a.vendor,
        a.status,
        a.location_text,
        a.building,
        a.floor,
        a.location_row,
        a.location_col,
        a.metadata,
        a.owner_user_id,
        a.barcode_photo_url,
        a.updated_at,
        u.name AS owner_name,
        u.department_hq,
        u.department_dept,
        u.department_team,
        u.department_part
      FROM assets a
      LEFT JOIN users u ON a.owner_user_id = u.id
      WHERE a.uid = $1
      LIMIT 1
      `,
      [uid]
    );

    if (result.rowCount === 0) {
      return undefined;
    }

    const asset = this.#mapAssetRow(result.rows[0]);
    const history = await this.listInspections({ assetUid: uid, pageSize: 50 });
    return {
      ...asset,
      history: history.items,
    };
  }

  async upsertAsset(payload) {
    const uid = normalizeString(payload.uid);
    if (!uid) {
      throw new Error('uid is required');
    }
    const metadata = mapMetadata(payload.metadata);
    const ownerId = normalizeUserId(payload.ownerId);
    const location = normalizeString(payload.location);
    const status = normalizeString(payload.status);
    const name = normalizeString(payload.name);
    const assetType = normalizeString(payload.assetType ?? payload.assets_types);
    const modelName = normalizeString(payload.modelName ?? payload.model);
    const serialNumber = normalizeString(payload.serialNumber ?? payload.serial);
    const vendor = normalizeString(payload.vendor);
    const barcodePhotoUrl = normalizeString(payload.barcodePhotoUrl);

    const updateResult = await this.pool.query(
      `
      UPDATE assets
      SET
        name = COALESCE($2, name),
        asset_type = COALESCE($3, asset_type),
        model_name = COALESCE($4, model_name),
        serial_number = COALESCE($5, serial_number),
        vendor = COALESCE($6, vendor),
        status = COALESCE($7, status),
        location_text = COALESCE($8, location_text),
        metadata = COALESCE($9, metadata),
        owner_user_id = COALESCE($10::bigint, owner_user_id),
        barcode_photo_url = COALESCE($11, barcode_photo_url),
        updated_at = now()
      WHERE uid = $1
      RETURNING uid
      `,
      [
        uid,
        name,
        assetType,
        modelName,
        serialNumber,
        vendor,
        status,
        location,
        Object.keys(metadata).length ? metadata : null,
        ownerId === undefined ? null : ownerId,
        barcodePhotoUrl,
      ]
    );

    if (updateResult.rowCount > 0) {
      return { asset: { uid }, created: false };
    }

    await this.pool.query(
      `
      INSERT INTO assets (
        uid,
        name,
        asset_type,
        model_name,
        serial_number,
        vendor,
        status,
        location_text,
        metadata,
        owner_user_id,
        barcode_photo_url,
        created_at,
        updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,now(),now()
      )
      `,
      [
        uid,
        name ?? '미배정',
        assetType,
        modelName,
        serialNumber,
        vendor,
        status ?? '사용',
        location,
        Object.keys(metadata).length ? metadata : {},
        ownerId === undefined ? null : ownerId,
        barcodePhotoUrl,
      ]
    );

    return { asset: { uid }, created: true };
  }

  async softDeleteAsset(uid) {
    const result = await this.pool.query(
      `
      UPDATE assets
      SET status = '폐기', updated_at = now()
      WHERE uid = $1
      RETURNING uid, status
      `,
      [uid]
    );
    if (result.rowCount === 0) {
      return undefined;
    }
    return {
      uid: result.rows[0].uid,
      status: result.rows[0].status,
    };
  }

  async listInspections({ assetUid, synced, from, to, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    const filters = [];
    const params = [];

    if (assetUid) {
      params.push(assetUid.trim().toLowerCase());
      const idx = params.length;
      filters.push(`LOWER(i.asset_uid) = $${idx}`);
    }

    if (synced !== undefined) {
      const value = typeof synced === 'string' ? synced.toLowerCase() === 'true' : Boolean(synced);
      params.push(value);
      const idx = params.length;
      filters.push(`i.synced = $${idx}`);
    }

    if (from) {
      params.push(new Date(from));
      const idx = params.length;
      filters.push(`i.scanned_at >= $${idx}`);
    }

    if (to) {
      params.push(new Date(to));
      const idx = params.length;
      filters.push(`i.scanned_at <= $${idx}`);
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const limit = Number(pageSize);
    const offset = Number(page) * limit;

    const rowsResult = await this.pool.query(
      `
      SELECT
        i.id,
        i.asset_uid,
        i.status,
        i.memo,
        i.scanned_at,
        i.synced,
        i.user_team,
        i.user_id,
        i.asset_type,
        i.verified,
        i.barcode_photo_url
      FROM inspections i
      ${whereClause}
      ORDER BY i.scanned_at DESC
      LIMIT $${params.length + 1}
      OFFSET $${params.length + 2}
      `,
      [...params, limit, offset]
    );

    const countResult = await this.pool.query(
      `
      SELECT COUNT(*) AS total
      FROM inspections i
      ${whereClause}
      `,
      params
    );

    const items = rowsResult.rows.map((row) => this.#mapInspectionRow(row));
    const total = Number.parseInt(countResult.rows[0]?.total ?? '0', 10);

    return {
      items,
      page: Number(page),
      pageSize: limit,
      total,
    };
  }

  async createInspection(payload) {
    const assetUid = normalizeString(payload.assetUid) ?? normalizeString(payload.asset_code);
    if (!assetUid) {
      throw new Error('assetUid is required');
    }
    const id = normalizeString(payload.id) ?? `ins_${assetUid}_${Date.now()}`;
    const status = normalizeString(payload.status) ?? '사용';
    const memo = normalizeString(payload.memo);
    const scannedAt = toIsoString(payload.scannedAt) ?? new Date().toISOString();
    const synced = parseBoolean(payload.synced) ?? false;
    const userTeam = normalizeString(payload.userTeam);
    const userId = normalizeUserId(payload.userId);
    const assetType = normalizeString(payload.assetType);
    const isVerified = parseBoolean(payload.isVerified) ?? false;
    const barcodePhotoUrl = normalizeString(payload.barcodePhotoUrl);

    const result = await this.pool.query(
      `
      INSERT INTO inspections (
        id,
        asset_uid,
        status,
        memo,
        scanned_at,
        synced,
        user_team,
        user_id,
        asset_type,
        verified,
        barcode_photo_url,
        created_at,
        updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,now(),now()
      )
      RETURNING id, asset_uid, status, memo, scanned_at, synced, user_team, user_id, asset_type, verified, barcode_photo_url
      `,
      [
        id,
        assetUid,
        status,
        memo,
        new Date(scannedAt),
        synced,
        userTeam,
        userId === undefined ? null : userId,
        assetType,
        isVerified,
        barcodePhotoUrl,
      ]
    );

    return this.#mapInspectionRow(result.rows[0]);
  }

  async updateInspection(id, payload) {
    const result = await this.pool.query(
      `
      UPDATE inspections
      SET
        status = COALESCE($2, status),
        memo = CASE WHEN $3 IS NULL THEN memo ELSE $3 END,
        scanned_at = COALESCE($4, scanned_at),
        synced = COALESCE($5, synced),
        updated_at = now()
      WHERE id = $1
      RETURNING id, asset_uid, status, memo, scanned_at, synced, user_team, user_id, asset_type, verified, barcode_photo_url
      `,
      [
        id,
        normalizeString(payload.status),
        payload.memo === undefined ? null : normalizeString(payload.memo),
        payload.scannedAt ? new Date(payload.scannedAt) : null,
        payload.synced === undefined ? null : Boolean(payload.synced),
      ]
    );

    if (result.rowCount === 0) {
      throw new Error('Inspection not found');
    }

    return this.#mapInspectionRow(result.rows[0]);
  }

  async deleteInspection(id) {
    const result = await this.pool.query('DELETE FROM inspections WHERE id = $1', [id]);
    return result.rowCount > 0;
  }

  async latestInspectionByAsset(assetUid) {
    const result = await this.pool.query(
      `
      SELECT id, asset_uid, status, memo, scanned_at, synced, user_team, user_id, asset_type, verified, barcode_photo_url
      FROM inspections
      WHERE asset_uid = $1
      ORDER BY scanned_at DESC
      LIMIT 1
      `,
      [assetUid]
    );
    if (result.rowCount === 0) {
      return undefined;
    }
    return this.#mapInspectionRow(result.rows[0]);
  }

  async listVerifications({ team, assetUid, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    const filters = [];
    const params = [];

    if (assetUid) {
      params.push(`%${assetUid.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`LOWER(a.uid) LIKE $${idx}`);
    }

    if (team) {
      params.push(`%${team.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`(
        LOWER(COALESCE(a.metadata->>'organization', '')) LIKE $${idx} OR
        LOWER(COALESCE(a.metadata->>'organization_team', '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_hq, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_dept, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_team, '')) LIKE $${idx} OR
        LOWER(COALESCE(u.department_part, '')) LIKE $${idx}
      )`);
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const limit = Number(pageSize);
    const offset = Number(page) * limit;

    const baseQuery = `
      FROM assets a
      LEFT JOIN users u ON a.owner_user_id = u.id
      LEFT JOIN LATERAL (
        SELECT s.id AS signature_id,
               s.user_id AS signature_user_id,
               s.user_name AS signature_user_name,
               s.storage_location AS signature_storage_location,
               s.sha256 AS signature_sha256,
               s.captured_at AS signature_captured_at
        FROM signatures s
        WHERE s.asset_uid = a.uid
        ORDER BY s.captured_at DESC
        LIMIT 1
      ) sig ON true
      LEFT JOIN LATERAL (
        SELECT i.scanned_at AS latest_scanned_at,
               i.status AS latest_status
        FROM inspections i
        WHERE i.asset_uid = a.uid
        ORDER BY i.scanned_at DESC
        LIMIT 1
      ) latest ON true
      ${whereClause}
    `;

    const rowsResult = await this.pool.query(
      `
      SELECT
        a.uid,
        a.asset_type,
        a.status,
        a.metadata,
        a.location_text,
        a.building,
        a.floor,
        a.location_row,
        a.location_col,
        a.barcode_photo_url,
        u.id AS owner_id,
        u.name AS owner_name,
        u.department_hq,
        u.department_dept,
        u.department_team,
        u.department_part,
        sig.signature_id,
        sig.signature_user_id,
        sig.signature_user_name,
        sig.signature_storage_location,
        sig.signature_sha256,
        sig.signature_captured_at,
        latest.latest_scanned_at,
        latest.latest_status
      ${baseQuery}
      ORDER BY a.uid ASC
      LIMIT $${params.length + 1}
      OFFSET $${params.length + 2}
      `,
      [...params, limit, offset]
    );

    const countResult = await this.pool.query(
      `
      SELECT COUNT(*) AS total
      ${baseQuery}
      `,
      params
    );

    const items = rowsResult.rows.map((row) => this.#mapVerificationSummary(row));
    const total = Number.parseInt(countResult.rows[0]?.total ?? '0', 10);

    return {
      items,
      total,
      page: Number(page),
      pageSize: limit,
    };
  }

  async getVerificationDetail(assetUid) {
    const rowsResult = await this.pool.query(
      `
      SELECT
        a.uid,
        a.name,
        a.asset_type,
        a.model_name,
        a.serial_number,
        a.vendor,
        a.status,
        a.location_text,
        a.building,
        a.floor,
        a.location_row,
        a.location_col,
        a.metadata,
        a.owner_user_id,
        a.barcode_photo_url,
        u.name AS owner_name,
        u.department_hq,
        u.department_dept,
        u.department_team,
        u.department_part,
        sig.signature_id,
        sig.signature_user_id,
        sig.signature_user_name,
        sig.signature_storage_location,
        sig.signature_sha256,
        sig.signature_captured_at,
        latest.latest_scanned_at,
        latest.latest_status
      FROM assets a
      LEFT JOIN users u ON a.owner_user_id = u.id
      LEFT JOIN LATERAL (
        SELECT s.id AS signature_id,
               s.user_id AS signature_user_id,
               s.user_name AS signature_user_name,
               s.storage_location AS signature_storage_location,
               s.sha256 AS signature_sha256,
               s.captured_at AS signature_captured_at
        FROM signatures s
        WHERE s.asset_uid = a.uid
        ORDER BY s.captured_at DESC
        LIMIT 1
      ) sig ON true
      LEFT JOIN LATERAL (
        SELECT i.scanned_at AS latest_scanned_at,
               i.status AS latest_status
        FROM inspections i
        WHERE i.asset_uid = a.uid
        ORDER BY i.scanned_at DESC
        LIMIT 1
      ) latest ON true
      WHERE a.uid = $1
      LIMIT 1
      `,
      [assetUid]
    );

    if (rowsResult.rowCount === 0) {
      return undefined;
    }

    const row = rowsResult.rows[0];
    const asset = this.#mapAssetRow(row);
    const signatureMeta = this.#mapSignatureMeta(row);
    const latestInspection = row.latest_scanned_at
      ? {
          scannedAt: new Date(row.latest_scanned_at).toISOString(),
          status: row.latest_status ?? asset.status,
        }
      : undefined;
    const history = await this.listInspections({ assetUid, pageSize: 100 });

    return {
      assetUid: asset.uid,
      team: asset.organization,
      user: asset.owner ? { id: asset.owner.id, name: asset.owner.name } : undefined,
      assetType: asset.assetType,
      barcodePhoto: Boolean(asset.barcodePhotoUrl),
      signature: Boolean(signatureMeta),
      latestInspection,
      asset,
      signatureMeta,
      history: history.items,
    };
  }

  async recordSignature(assetUid, metadata) {
    const fileName = normalizeString(metadata.fileName);
    if (!fileName) {
      throw new Error('fileName is required');
    }
    const absolutePath = path.join(this.signatureDir, fileName);
    const fileBuffer = await readFile(absolutePath);
    const sha256 = createHash('sha256').update(fileBuffer).digest('hex');
    const storedAt = metadata.storedAt ? new Date(metadata.storedAt) : new Date();
    const userId = normalizeUserId(metadata.userId);
    const userName = normalizeString(metadata.userName);

    const result = await this.pool.query(
      `
      INSERT INTO signatures (
        asset_uid,
        user_id,
        user_name,
        storage_location,
        sha256,
        captured_at,
        migrated
      ) VALUES (
        $1,$2,$3,$4,$5,$6,false
      )
      RETURNING id, asset_uid, user_id, user_name, storage_location, sha256, captured_at
      `,
      [
        assetUid,
        userId === undefined ? null : userId,
        userName,
        fileName,
        sha256,
        storedAt,
      ]
    );

    const row = result.rows[0];
    return {
      signatureId: String(row.id),
      assetUid: row.asset_uid,
      storageLocation: row.storage_location,
      sha256: row.sha256,
      userId: row.user_id === null || row.user_id === undefined ? undefined : String(row.user_id),
      userName: row.user_name ?? undefined,
      capturedAt: new Date(row.captured_at).toISOString(),
    };
  }

  async findSignatureById(signatureId) {
    const result = await this.pool.query(
      `
      SELECT id, asset_uid, user_id, user_name, storage_location, sha256, captured_at
      FROM signatures
      WHERE id = $1
      LIMIT 1
      `,
      [signatureId]
    );
    if (result.rowCount === 0) {
      return undefined;
    }
    const row = result.rows[0];
    return {
      signatureId: String(row.id),
      assetUid: row.asset_uid,
      storageLocation: row.storage_location,
      sha256: row.sha256,
      userId: row.user_id === null || row.user_id === undefined ? undefined : String(row.user_id),
      userName: row.user_name ?? undefined,
      capturedAt: new Date(row.captured_at).toISOString(),
    };
  }

  async persistSignatures() {
    // No-op: signatures are persisted immediately in the database.
  }

  async getSignatureFilePath(assetUid) {
    const result = await this.pool.query(
      `
      SELECT storage_location
      FROM signatures
      WHERE asset_uid = $1
      ORDER BY captured_at DESC
      LIMIT 1
      `,
      [assetUid]
    );
    if (result.rowCount === 0) {
      return undefined;
    }
    const fileName = result.rows[0].storage_location;
    if (!fileName) {
      return undefined;
    }
    return path.join(this.signatureDir, fileName);
  }

  async batchAssignSignature({ assetUids, signatureId }) {
    if (!Array.isArray(assetUids) || assetUids.length === 0) {
      return [];
    }
    const source = await this.findSignatureById(signatureId);
    if (!source) {
      throw new Error('signatureId not found');
    }

    const applied = [];
    for (const uid of assetUids) {
      const normalized = normalizeString(uid);
      if (!normalized) continue;
      const userIdValue = source.userId !== undefined ? Number.parseInt(source.userId, 10) : null;
      const normalizedUserId = userIdValue !== null && !Number.isNaN(userIdValue) ? userIdValue : null;
      try {
        const result = await this.pool.query(
          `
          INSERT INTO signatures (
            asset_uid,
            user_id,
            user_name,
            storage_location,
            sha256,
            captured_at,
            migrated
          ) VALUES (
            $1,$2,$3,$4,$5,$6,false
          )
          RETURNING asset_uid
          `,
          [
            normalized,
            normalizedUserId,
            source.userName ?? null,
            source.storageLocation,
            source.sha256 ?? null,
            new Date(),
          ]
        );
        if (result.rowCount > 0) {
          applied.push(result.rows[0].asset_uid);
        }
      } catch (error) {
        this.logger.error?.('Failed to assign signature', { assetUid: normalized, error });
      }
    }
    return applied;
  }

  async getAllAssetUids() {
    const result = await this.pool.query('SELECT uid FROM assets ORDER BY uid ASC');
    return result.rows.map((row) => row.uid);
  }

  async searchUsers({ q, team } = {}) {
    const filters = [];
    const params = [];

    if (q) {
      params.push(`%${q.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`(
        LOWER(name) LIKE $${idx} OR
        LOWER(employee_id) LIKE $${idx}
      )`);
    }

    if (team) {
      params.push(`%${team.trim().toLowerCase()}%`);
      const idx = params.length;
      filters.push(`(
        LOWER(COALESCE(department_hq, '')) LIKE $${idx} OR
        LOWER(COALESCE(department_dept, '')) LIKE $${idx} OR
        LOWER(COALESCE(department_team, '')) LIKE $${idx} OR
        LOWER(COALESCE(department_part, '')) LIKE $${idx}
      )`);
    }

    const whereClause = filters.length ? `WHERE ${filters.join(' AND ')}` : '';

    const result = await this.pool.query(
      `
      SELECT id, name, employee_id, department_hq, department_dept, department_team, department_part
      FROM users
      ${whereClause}
      ORDER BY name ASC
      LIMIT 100
      `,
      params
    );

    return result.rows.map((row) => ({
      id: String(row.id),
      name: row.name ?? '',
      department: composeDepartment(row),
      employeeId: row.employee_id ?? undefined,
      numericId: row.id !== undefined && row.id !== null ? String(row.id) : undefined,
    }));
  }

  async searchAssetRefs({ q } = {}) {
    const params = [];
    let whereClause = '';
    if (q) {
      params.push(`%${q.trim().toLowerCase()}%`);
      const idx = params.length;
      whereClause = `WHERE LOWER(uid) LIKE $${idx}`;
    }

    const result = await this.pool.query(
      `
      SELECT uid, name, asset_type
      FROM assets
      ${whereClause}
      ORDER BY uid ASC
      LIMIT 25
      `,
      params
    );

    return result.rows.map((row) => ({
      uid: row.uid,
      name: row.name ?? '',
      assetType: row.asset_type ?? '',
    }));
  }

  #mapAssetRow(row) {
    const metadata = mapMetadata(row.metadata);
    const ownerDepartment = composeDepartment(row);
    const ownerId = row.owner_user_id === null || row.owner_user_id === undefined ? undefined : String(row.owner_user_id);
    const owner = ownerId
      ? {
          id: ownerId,
          name: row.owner_name ?? '미상',
          department: ownerDepartment || undefined,
        }
      : undefined;
    const organization = resolveOrganization(metadata, ownerDepartment);
    const barcodePhotoUrl = resolveBarcodePhotoUrl(row, metadata);

    return {
      uid: row.uid,
      name: row.name ?? owner?.name ?? '미배정',
      assetType: row.asset_type ?? '',
      modelName: row.model_name ?? '',
      serialNumber: row.serial_number ?? '',
      status: row.status ?? '사용',
      vendor: row.vendor ?? '',
      location: composeLocation(row),
      organization,
      metadata,
      owner,
      barcodePhotoUrl,
    };
  }

  #mapInspectionRow(row) {
    return {
      id: row.id,
      assetUid: row.asset_uid,
      status: row.status ?? '사용',
      memo: row.memo ?? undefined,
      scannedAt: new Date(row.scanned_at).toISOString(),
      synced: row.synced ?? false,
      userTeam: row.user_team ?? undefined,
      userId: row.user_id === null || row.user_id === undefined ? undefined : String(row.user_id),
      assetType: row.asset_type ?? undefined,
      isVerified: row.verified ?? false,
      barcodePhotoUrl: row.barcode_photo_url ?? undefined,
    };
  }

  #mapSignatureMeta(row) {
    if (!row.signature_id) {
      return undefined;
    }
    return {
      signatureId: String(row.signature_id),
      userId: row.signature_user_id === null || row.signature_user_id === undefined ? undefined : String(row.signature_user_id),
      userName: row.signature_user_name ?? undefined,
      storageLocation: row.signature_storage_location,
      sha256: row.signature_sha256 ?? undefined,
      capturedAt: row.signature_captured_at ? new Date(row.signature_captured_at).toISOString() : undefined,
    };
  }

  #mapVerificationSummary(row) {
    const metadata = mapMetadata(row.metadata);
    const ownerDepartment = composeDepartment(row);
    const organization = resolveOrganization(metadata, ownerDepartment);
    const barcodePhotoUrl = resolveBarcodePhotoUrl(row, metadata);
    const signatureMeta = this.#mapSignatureMeta(row);

    return {
      assetUid: row.uid,
      team: organization,
      user: row.owner_id !== null && row.owner_id !== undefined
        ? { id: String(row.owner_id), name: row.owner_name ?? '미상' }
        : undefined,
      assetType: row.asset_type ?? '',
      barcodePhoto: Boolean(barcodePhotoUrl),
      signature: Boolean(signatureMeta),
      latestInspection: row.latest_scanned_at
        ? {
            scannedAt: new Date(row.latest_scanned_at).toISOString(),
            status: row.latest_status ?? row.status ?? '사용',
          }
        : undefined,
    };
  }
}

export const dataStore = new DataStore();
