import { readFile, writeFile, mkdir, access } from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { randomUUID } from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DEFAULT_PAGE_SIZE = 20;
const DATA_ROOT = path.resolve(__dirname, '../../assets/dummy/mock');
const SIGNATURE_DIR = path.resolve(__dirname, './storage');

const ASSET_CORE_KEYS = new Set([
  'id',
  'asset_uid',
  'uid',
  'name',
  'assets_status',
  'status',
  'assets_types',
  'assetType',
  'serial_number',
  'serialNumber',
  'model_name',
  'modelName',
  'vendor',
  'organization',
  'network',
  'building1',
  'building',
  'floor',
  'location_drawing_id',
  'location_row',
  'location_col',
  'location_drawing_file',
  'member_name',
  'user_id',
  'userId',
  'created_at',
  'updated_at',
]);

function normalizeString(value) {
  if (value === undefined || value === null) return undefined;
  const stringValue = String(value).trim();
  return stringValue.length === 0 ? undefined : stringValue;
}

function normalizeBoolean(value) {
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
  if (!value) {
    return undefined;
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return undefined;
  }
  return date.toISOString();
}

export class DataStore {
  constructor({
    dataRoot = DATA_ROOT,
    signatureDir = SIGNATURE_DIR,
    logger = console,
  } = {}) {
    this.dataRoot = dataRoot;
    this.signatureDir = signatureDir;
    this.logger = logger;
    this.users = new Map();
    this.assets = new Map();
    this.inspections = new Map();
    this.signaturesByAsset = new Map();
    this.signaturesById = new Map();
  }

  async initialize() {
    await mkdir(this.signatureDir, { recursive: true });
    await this.#loadUsers();
    await this.#loadAssets();
    await this.#loadInspections();
    await this.#hydrateExistingSignatures();
  }

  getSignatureDirectory() {
    return this.signatureDir;
  }

  async #readJson(fileName) {
    const filePath = path.resolve(this.dataRoot, fileName);
    const raw = await readFile(filePath, 'utf8');
    return JSON.parse(raw);
  }

  async #loadUsers() {
    const items = await this.#readJson('users.json');
    this.users.clear();
    for (const item of items) {
      const id = normalizeString(item.employee_id) ?? normalizeString(item.id);
      if (!id) continue;
      const name = normalizeString(item.employee_name) ?? normalizeString(item.name) ?? '미상';
      const departmentParts = [
        normalizeString(item.organization_hq),
        normalizeString(item.organization_dept),
        normalizeString(item.organization_team),
        normalizeString(item.organization_part),
      ].filter(Boolean);
      const department = departmentParts.join(' > ');
      const record = {
        id,
        numericId: normalizeString(item.id),
        employeeId: normalizeString(item.employee_id),
        name,
        department,
        meta: { ...item },
      };
      this.users.set(id, record);
      if (record.numericId && record.numericId !== id) {
        this.users.set(record.numericId, record);
      }
    }
  }

  async #loadAssets() {
    const items = await this.#readJson('assets.json');
    this.assets.clear();
    for (const item of items) {
      const uid = normalizeString(item.asset_uid) ?? normalizeString(item.uid);
      if (!uid) continue;
      const metadata = {};
      for (const [key, value] of Object.entries(item)) {
        if (ASSET_CORE_KEYS.has(key)) continue;
        const normalized = normalizeString(value);
        if (normalized !== undefined) {
          metadata[key] = normalized;
        }
      }
      const ownerId = normalizeString(item.user_id) ?? normalizeString(item.userId);
      const owner = ownerId ? this.users.get(ownerId) : undefined;
      const asset = {
        uid,
        name: normalizeString(item.name) ?? owner?.name ?? '미배정',
        assetType: normalizeString(item.assets_types) ?? normalizeString(item.assetType) ?? '',
        modelName: normalizeString(item.model_name) ?? normalizeString(item.modelName) ?? '',
        serialNumber: normalizeString(item.serial_number) ?? normalizeString(item.serialNumber) ?? '',
        status: normalizeString(item.assets_status) ?? normalizeString(item.status) ?? '사용',
        vendor: normalizeString(item.vendor) ?? '',
        location: this.#resolveLocation(item),
        organization: normalizeString(item.organization) ?? '',
        owner: owner
          ? {
              id: owner.id,
              name: owner.name,
            }
          : undefined,
        metadata,
        barcodePhotoUrl: normalizeString(metadata.barcodePhotoUrl ?? metadata.barcode_photo_url ?? metadata.barcode_photo),
      };
      this.assets.set(uid, asset);
    }
  }

  async #loadInspections() {
    const items = await this.#readJson('asset_inspections.json');
    this.inspections.clear();
    for (const item of items) {
      const normalized = this.#normalizeInspection(item);
      this.inspections.set(normalized.id, normalized);
    }
  }

  async #hydrateExistingSignatures() {
    try {
      await access(path.join(this.signatureDir, 'signatures.json'));
      const raw = await readFile(path.join(this.signatureDir, 'signatures.json'), 'utf8');
      const entries = JSON.parse(raw);
      this.signaturesByAsset.clear();
      this.signaturesById.clear();
      for (const entry of entries) {
        if (!entry.assetUid || !entry.signatureId || !entry.fileName) continue;
        this.signaturesByAsset.set(entry.assetUid, entry);
        this.signaturesById.set(entry.signatureId, entry);
      }
    } catch (error) {
      if (error && error.code !== 'ENOENT') {
        this.logger.error('Failed to hydrate signatures', error);
      }
    }
  }

  async #persistSignatures() {
    const entries = Array.from(this.signaturesByAsset.values());
    const filePath = path.join(this.signatureDir, 'signatures.json');
    await writeFile(filePath, JSON.stringify(entries, null, 2), 'utf8');
  }

  #normalizeInspection(item) {
    const assetUid = normalizeString(item.asset_code) ?? normalizeString(item.assetUid);
    if (!assetUid) {
      throw new Error('Inspection missing assetUid');
    }
    const asset = this.assets.get(assetUid);
    const idRaw = normalizeString(item.id) ?? undefined;
    const id = idRaw ?? `ins_${assetUid}_${item.inspection_date ?? Date.now()}`;
    const scannedAtRaw =
      normalizeString(item.inspection_date) ?? normalizeString(item.scannedAt) ?? new Date().toISOString();
    const scannedAt = new Date(scannedAtRaw);
    const memo = this.#buildMemo(item);
    const userId = normalizeString(item.user_id) ?? normalizeString(item.userId);
    const inspection = {
      id,
      assetUid,
      status: normalizeString(item.status) ?? asset?.status ?? '사용',
      memo,
      scannedAt: toIsoString(scannedAt) ?? new Date().toISOString(),
      synced: normalizeBoolean(item.synced) ?? ((item.inspection_count ?? 0) % 2 === 0),
      userTeam: normalizeString(item.user_team) ?? undefined,
      userId: userId ?? undefined,
      assetType: normalizeString(item.asset_type) ?? asset?.assetType ?? undefined,
      isVerified: normalizeBoolean(item.is_verified) ?? true,
      barcodePhotoUrl: asset?.barcodePhotoUrl,
    };
    return inspection;
  }

  #buildMemo(item) {
    const lines = [];
    const inspector = normalizeString(item.inspector_name);
    const team = normalizeString(item.user_team);
    const departmentConfirm = normalizeString(item.department_confirm);
    if (inspector) lines.push(`점검자: ${inspector}`);
    if (team) lines.push(`소속: ${team}`);
    const assetInfo = item.asset_info && typeof item.asset_info === 'object' ? item.asset_info : undefined;
    if (assetInfo) {
      const usage = normalizeString(assetInfo.usage);
      const model = normalizeString(assetInfo.model_name ?? assetInfo.modelName);
      const serial = normalizeString(assetInfo.serial_number ?? assetInfo.serialNumber);
      if (usage) lines.push(`용도: ${usage}`);
      if (model) lines.push(`모델: ${model}`);
      if (serial) lines.push(`시리얼: ${serial}`);
    }
    if (departmentConfirm) lines.push(`확인부서: ${departmentConfirm}`);
    return lines.length ? lines.join('\n') : undefined;
  }

  #resolveLocation(item) {
    const parts = [
      normalizeString(item.building1),
      normalizeString(item.building),
      normalizeString(item.floor),
    ].filter(Boolean);
    if (item.location_row !== undefined && item.location_row !== null) {
      parts.push(`R${item.location_row}`);
    }
    if (item.location_col !== undefined && item.location_col !== null) {
      parts.push(`C${item.location_col}`);
    }
    return parts.join(' ');
  }

  getAsset(uid) {
    return this.assets.get(uid);
  }

  getAllAssetUids() {
    return Array.from(this.assets.keys());
  }

  listAssets({ q, status, team, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    let items = Array.from(this.assets.values());
    if (q) {
      const lowered = q.trim().toLowerCase();
      items = items.filter((item) => {
        return [
          item.uid,
          item.name,
          item.assetType,
          item.modelName,
          item.serialNumber,
          item.organization,
        ]
          .filter(Boolean)
          .some((field) => field.toLowerCase().includes(lowered));
      });
    }
    if (status) {
      const lowered = status.trim().toLowerCase();
      items = items.filter((item) => item.status?.toLowerCase() === lowered);
    }
    if (team) {
      const lowered = team.trim().toLowerCase();
      items = items.filter((item) => {
        const ownerDept = item.owner?.department?.toLowerCase();
        const organization = item.organization?.toLowerCase();
        return (ownerDept && ownerDept.includes(lowered)) || (organization && organization.includes(lowered));
      });
    }
    const total = items.length;
    const start = Number(page) * Number(pageSize);
    const end = start + Number(pageSize);
    const paged = items.slice(start, end);
    return {
      items: paged.map((item) => ({
        ...item,
        metadata: { ...item.metadata },
      })),
      total,
      page: Number(page),
      pageSize: Number(pageSize),
    };
  }

  getAssetDetail(uid) {
    const asset = this.assets.get(uid);
    if (!asset) return undefined;
    const history = this.listInspections({ assetUid: uid, pageSize: 50 }).items;
    return {
      ...asset,
      metadata: { ...asset.metadata },
      history,
    };
  }

  upsertAsset(payload) {
    const uid = normalizeString(payload.uid);
    if (!uid) {
      throw new Error('uid is required');
    }
    const existing = this.assets.get(uid);
    const owner = payload.ownerId ? this.users.get(String(payload.ownerId)) : existing?.owner;
    const asset = {
      uid,
      name: normalizeString(payload.name) ?? existing?.name ?? '미배정',
      assetType: normalizeString(payload.assetType) ?? normalizeString(payload.assets_types) ?? existing?.assetType ?? '',
      modelName: normalizeString(payload.modelName) ?? normalizeString(payload.model) ?? existing?.modelName ?? '',
      serialNumber: normalizeString(payload.serialNumber) ?? normalizeString(payload.serial) ?? existing?.serialNumber ?? '',
      status: normalizeString(payload.status) ?? existing?.status ?? '사용',
      vendor: normalizeString(payload.vendor) ?? existing?.vendor ?? '',
      location: normalizeString(payload.location) ?? existing?.location ?? '',
      organization: normalizeString(payload.organization) ?? existing?.organization ?? '',
      owner: owner
        ? {
            id: owner.id,
            name: owner.name,
            department: owner.department,
          }
        : existing?.owner,
      metadata: { ...(existing?.metadata ?? {}), ...(payload.metadata ?? {}) },
      barcodePhotoUrl:
        normalizeString(payload.barcodePhotoUrl) ?? existing?.barcodePhotoUrl ?? undefined,
    };
    this.assets.set(uid, asset);
    return { asset, created: !existing };
  }

  softDeleteAsset(uid) {
    const asset = this.assets.get(uid);
    if (!asset) return undefined;
    const updated = { ...asset, status: '폐기' };
    this.assets.set(uid, updated);
    return updated;
  }

  listInspections({ assetUid, synced, from, to, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    let items = Array.from(this.inspections.values());
    if (assetUid) {
      const lowered = assetUid.trim().toLowerCase();
      items = items.filter((item) => item.assetUid.toLowerCase() === lowered);
    }
    if (synced !== undefined) {
      const boolValue = synced === 'false' ? false : synced === 'true' ? true : Boolean(synced);
      items = items.filter((item) => item.synced === boolValue);
    }
    if (from) {
      const fromDate = new Date(from);
      items = items.filter((item) => new Date(item.scannedAt) >= fromDate);
    }
    if (to) {
      const toDate = new Date(to);
      items = items.filter((item) => new Date(item.scannedAt) <= toDate);
    }
    items.sort((a, b) => new Date(b.scannedAt) - new Date(a.scannedAt));
    const total = items.length;
    const start = Number(page) * Number(pageSize);
    const end = start + Number(pageSize);
    const paged = items.slice(start, end);
    return {
      items: paged.map((item) => ({ ...item })),
      page: Number(page),
      pageSize: Number(pageSize),
      total,
    };
  }

  createInspection(payload) {
    const assetUid = normalizeString(payload.assetUid) ?? normalizeString(payload.asset_code);
    if (!assetUid) {
      throw new Error('assetUid is required');
    }
    const id = normalizeString(payload.id) ?? `ins_${assetUid}_${Date.now()}`;
    const record = {
      id,
      assetUid,
      status: normalizeString(payload.status) ?? '사용',
      memo: normalizeString(payload.memo),
      scannedAt: toIsoString(payload.scannedAt) ?? new Date().toISOString(),
      synced: normalizeBoolean(payload.synced) ?? false,
      userTeam: normalizeString(payload.userTeam),
      userId: normalizeString(payload.userId),
      assetType: normalizeString(payload.assetType),
      isVerified: normalizeBoolean(payload.isVerified) ?? false,
      barcodePhotoUrl: normalizeString(payload.barcodePhotoUrl),
    };
    this.inspections.set(id, record);
    return record;
  }

  updateInspection(id, payload) {
    const existing = this.inspections.get(id);
    if (!existing) {
      throw new Error('Inspection not found');
    }
    const updated = {
      ...existing,
      status: normalizeString(payload.status) ?? existing.status,
      memo: payload.memo !== undefined ? normalizeString(payload.memo) : existing.memo,
      scannedAt: toIsoString(payload.scannedAt) ?? existing.scannedAt,
      synced: payload.synced !== undefined ? normalizeBoolean(payload.synced) ?? existing.synced : existing.synced,
    };
    this.inspections.set(id, updated);
    return updated;
  }

  deleteInspection(id) {
    const existed = this.inspections.delete(id);
    return existed;
  }

  latestInspectionByAsset(uid) {
    const inspections = Array.from(this.inspections.values()).filter((item) => item.assetUid === uid);
    if (!inspections.length) return undefined;
    inspections.sort((a, b) => new Date(b.scannedAt) - new Date(a.scannedAt));
    return inspections[0];
  }

  listVerifications({ team, assetUid, page = 0, pageSize = DEFAULT_PAGE_SIZE } = {}) {
    let items = Array.from(this.assets.values()).map((asset) => this.#composeVerification(asset.uid));
    if (assetUid) {
      const lowered = assetUid.trim().toLowerCase();
      items = items.filter((item) => item.assetUid.toLowerCase().includes(lowered));
    }
    if (team) {
      const lowered = team.trim().toLowerCase();
      items = items.filter((item) => {
        const targetTeam = item.team?.toLowerCase();
        return targetTeam?.includes(lowered);
      });
    }
    const total = items.length;
    const start = Number(page) * Number(pageSize);
    const end = start + Number(pageSize);
    const paged = items.slice(start, end);
    return {
      items: paged,
      page: Number(page),
      pageSize: Number(pageSize),
      total,
    };
  }

  getVerificationDetail(assetUid) {
    const asset = this.assets.get(assetUid);
    if (!asset) return undefined;
    return this.#composeVerification(assetUid, { includeAsset: true, includeHistory: true });
  }

  #composeVerification(assetUid, { includeAsset = false, includeHistory = false } = {}) {
    const asset = this.assets.get(assetUid);
    if (!asset) {
      return undefined;
    }
    const signature = this.signaturesByAsset.get(assetUid);
    const latestInspection = this.latestInspectionByAsset(assetUid);
    const verification = {
      assetUid,
      team: asset.organization,
      user: asset.owner
        ? { id: asset.owner.id, name: asset.owner.name }
        : undefined,
      assetType: asset.assetType,
      barcodePhoto: Boolean(asset.barcodePhotoUrl),
      signature: Boolean(signature),
      latestInspection: latestInspection
        ? {
            scannedAt: latestInspection.scannedAt,
            status: latestInspection.status,
          }
        : undefined,
    };
    if (includeAsset) {
      verification.asset = {
        ...asset,
        metadata: { ...asset.metadata },
      };
      verification.signatureMeta = signature;
    }
    if (includeHistory) {
      verification.history = this.listInspections({ assetUid, pageSize: 100 }).items;
    }
    return verification;
  }

  recordSignature(assetUid, metadata) {
    const signatureId = metadata.signatureId ?? randomUUID();
    const record = {
      assetUid,
      signatureId,
      fileName: metadata.fileName,
      storedAt: toIsoString(metadata.storedAt) ?? new Date().toISOString(),
      userId: metadata.userId,
      userName: metadata.userName,
    };
    this.signaturesByAsset.set(assetUid, record);
    this.signaturesById.set(signatureId, record);
    return record;
  }

  findSignatureById(signatureId) {
    return this.signaturesById.get(signatureId);
  }

  async persistSignatures() {
    await this.#persistSignatures();
  }

  getSignatureFilePath(assetUid) {
    const meta = this.signaturesByAsset.get(assetUid);
    if (!meta) return undefined;
    return path.join(this.signatureDir, meta.fileName);
  }

  batchAssignSignature({ assetUids, signatureId }) {
    const source = signatureId ? this.signaturesById.get(signatureId) : undefined;
    if (!source) {
      throw new Error('signatureId not found');
    }
    const applied = [];
    for (const uid of assetUids) {
      if (!this.assets.has(uid)) continue;
      const record = {
        ...source,
        assetUid: uid,
      };
      this.signaturesByAsset.set(uid, record);
      this.signaturesById.set(record.signatureId, record);
      applied.push(uid);
    }
    return applied;
  }

  searchUsers({ q, team }) {
    let users = Array.from(new Set(this.users.values()));
    if (q) {
      const lowered = q.trim().toLowerCase();
      users = users.filter((user) => {
        return (
          user.name.toLowerCase().includes(lowered) ||
          (user.employeeId && user.employeeId.toLowerCase().includes(lowered))
        );
      });
    }
    if (team) {
      const lowered = team.trim().toLowerCase();
      users = users.filter((user) => user.department?.toLowerCase().includes(lowered));
    }
    return users.map((user) => ({
      id: user.id,
      name: user.name,
      department: user.department,
      employeeId: user.employeeId,
      numericId: user.numericId,
    }));
  }

  searchAssetRefs({ q }) {
    let assets = Array.from(this.assets.values());
    if (q) {
      const lowered = q.trim().toLowerCase();
      assets = assets.filter((asset) => asset.uid.toLowerCase().includes(lowered));
    }
    return assets.slice(0, 25).map((asset) => ({
      uid: asset.uid,
      name: asset.name,
      assetType: asset.assetType,
    }));
  }
}

export const dataStore = new DataStore();
