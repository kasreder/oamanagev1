// generate-mock.js
// 사용법:
//   node generate-mock.js --users=100 --assets=1000 --inspections=3000 --out=./mock
//
// 기본값:
//   users=50, assets=300, inspections=800, out=./mock
//
// 생성 파일:
//   <out>/users.json
//   <out>/assets.json
//   <out>/asset_inspections.json

const fs = require('fs');
const path = require('path');
const { randomInt } = require('crypto');

/* ------------ CLI ------------ */
const args = Object.fromEntries(process.argv.slice(2).map(a => {
  const [k, v] = a.split('=');
  return [k.replace(/^--/, ''), v ?? true];
}));
const U = parseInt(args.users ?? '50', 10);
const A = parseInt(args.assets ?? '300', 10);
const I = parseInt(args.inspections ?? '800', 10);
const OUT = String(args.out ?? './mock');

/* ------------ utils ------------ */
const pick = (arr) => arr[randomInt(0, arr.length)];
const pad = (n, w) => String(n).padStart(w, '0');
const iso = (d) => new Date(d).toISOString();
const chance = (p) => Math.random() < p;

function randBetweenDays(fromDaysAgo, toDaysAgo) {
  const now = Date.now();
  const from = now - toDaysAgo * 86400000;
  const to = now - fromDaysAgo * 86400000;
  return new Date(from + Math.random() * (to - from));
}
function macAddress() {
  const h = () => pad(randomInt(0, 256).toString(16), 2);
  return `${h()}:${h()}:${h()}:${h()}:${h()}:${h()}`.toUpperCase();
}

/* ------------ dictionaries ------------ */
const HQS = ['경영본부','생산본부','영업본부','연구개발본부','품질본부'];
// 🔹 모두 "~실" 로 변경
const DEPTS = ['재무실','인사실','생산기술실','마케팅실','R&D실','품질관리실'];
const TEAMS = ['회계팀','급여팀','자동화팀','콘텐츠팀','플랫폼팀','검사팀','품질보증팀'];
const PARTS = ['결산파트','운영파트','설계파트','데이터파트','시스템파트']; // 90% null 처리
const POSITIONS = [null, null, '팀장', '파트장', '책임', null];
const BUILDINGS = ['본사A동','본사B동','공장1','공장2','연구동', null];
const FLOORS = ['1층','2층','3층','4층','5층','6층', null];

const ASSET_STATUS = ['사용','가용(창고)','이동'];
const BUILDING1 = ['내부직원','외부직원','자산창고'];
const CATEGORIES = ['IT장비','생산설비','네트워크','사무기기','안전장비'];
const NETWORKS = [null, '사내망','생산망','게스트','분리망'];
const VENDORS = ['Lenovo','HP','Dell','Apple','Samsung','LG','Cisco','Siemens','Omron','Mitsubishi','Universal Robots'];
const ASSET_TYPES_FOR_INSPECTION = ['데스크탑','모니터','프린터','스캐너','노트북','태블릿','소모품'];

function koreanName() {
  const last = ['김','이','박','최','정','조','유','윤','장','임','한','오','서','신','권','황','안','송','심','홍'];
  const firstA = ['민','서','예','지','도','주','하','지','현','재','승','수','규','영','태','유','다','시','윤','가'];
  const firstB = ['준','연','원','훈','진','현','영','빈','성','우','민','희','림','호','성','혁','훈','주','라','원'];
  return `${pick(last)}${pick(firstA)}${pick(firstB)}`;
}
function employeeId(i) {
  const prefix = pick(['B','P','A']);
  return `${prefix}${pad(i + 1, 6)}`;
}
function assetUid() {
  return `A${pad(randomInt(0, 100000), 5)}`;
}
function serial() {
  return `SN-${pad(randomInt(0, 1000000000), 9)}`;
}
function modelName() {
  const series = ['X1','Pro','Elite','Edge','UR','DX','MX','Ultra','Prime','Air'];
  const suffix = ['100','200','500','700','900','10e','3000','G2','M2'];
  return `${pick(VENDORS)} ${pick(series)} ${pick(suffix)}`;
}

/* ------------ generators ------------ */
function generateUsers(n) {
  const res = [];
  for (let i = 0; i < n; i++) {
    res.push({
      id: i + 1,
      employee_id: employeeId(i),
      employee_name: koreanName(),
      organization_hq: pick(HQS),
      // 🔹 3% 확률 null, 97%는 값
      organization_dept: Math.random() < 0.03 ? null : pick(DEPTS),
      organization_team: pick(TEAMS),
      // 🔹 90% null, 10% 값
      organization_part: Math.random() < 0.9 ? null : pick(PARTS),
      organization_etc: pick(POSITIONS),
      work_building: pick(BUILDINGS),
      work_floor: pick(FLOORS)
    });
  }
  return res;
}

function generateAssets(n, users) {
  const res = [];
  for (let i = 0; i < n; i++) {
    const createdAt = randBetweenDays(240, 60);
    const updatedAt = randBetweenDays(59, 0);
    const status = pick(ASSET_STATUS);
    const building1 = pick(BUILDING1);

    const assigned = chance(0.7) ? pick(users) : null;
    const assigneeName = assigned ? assigned.employee_name : '공용';

    const building = assigned?.work_building ?? pick(BUILDINGS);
    const floor = assigned?.work_floor ?? pick(FLOORS);

    const locRow = chance(0.6) ? randomInt(1, 25) : null;
    const locCol = chance(0.6) ? randomInt(1, 40) : null;
    const drawingId = (locRow && locCol) ? randomInt(1, 80) : null;

    const physicalDt = chance(0.6) ? randBetweenDays(120, 0) : null;
    const confirmationDt = chance(0.4) ? randBetweenDays(90, 0) : null;

    res.push({
      id: i + 1,
      asset_uid: assetUid(),
      name: assigneeName,
      assets_status: status,
      category: pick(CATEGORIES),
      serial_number: serial(),
      model_name: modelName(),
      vendor: pick(VENDORS),
      network: pick(NETWORKS),
      physical_check_date: physicalDt ? iso(physicalDt) : null,
      confirmation_date: confirmationDt ? iso(confirmationDt) : null,
      normal_comment: chance(0.5) ? pick(['정상 사용중','정기 점검 예정','교체 검토','부품 대기','폐기 검토']) : null,
      oa_comment: chance(0.35) ? pick(['자산관리 등록 완료','라이선스 점검 필요','보안 정책 적용','패치 예정']) : null,
      mac_address: chance(0.55) ? macAddress() : null,
      building1: building1,
      building: building,
      floor: floor,
      member_name: chance(0.4) ? koreanName() : (assigned?.employee_name ?? null),
      location_drawing_id: drawingId,
      location_row: locRow,
      location_col: locCol,
      location_drawing_file: drawingId ? `drawing_${drawingId}.png` : null,
      created_at: iso(createdAt),
      updated_at: iso(updatedAt),
      user_id: assigned?.id ?? null
    });
  }

  const dedup = (key, gen) => {
    const seen = new Set();
    for (const a of res) {
      while (seen.has(a[key])) a[key] = gen();
      seen.add(a[key]);
    }
  };
  dedup('asset_uid', assetUid);
  dedup('serial_number', serial);

  return res;
}

function generateInspections(total, assets, users) {
  const list = [];
  const countPerAsset = new Map();

  for (let i = 0; i < total; i++) {
    const asset = pick(assets);
    const user = asset.user_id ? users[asset.user_id - 1] : pick(users);
    const inspector = koreanName();
    const deptConfirm = user?.organization_dept ?? pick(DEPTS);

    const next = (countPerAsset.get(asset.id) ?? 0) + 1;
    countPerAsset.set(asset.id, next);

    const when = randBetweenDays(150, 0);

    list.push({
      id: i + 1,
      asset_id: asset.id,
      user_id: user?.id ?? null,
      inspector_name: inspector,
      user_team: user?.organization_team ?? pick(TEAMS),
      asset_code: asset.asset_uid,
      asset_type: pick(ASSET_TYPES_FOR_INSPECTION),
      asset_info: {
        model_name: asset.model_name,
        usage: asset.user_id ? "개인" : "공용",
        serial_number: asset.serial_number
      },
      inspection_count: next,
      inspection_date: iso(when),
      maintenance_company_staff: chance(0.7) ? koreanName() : null,
      department_confirm: deptConfirm
    });
  }

  const byAsset = new Map();
  for (const it of list) {
    if (!byAsset.has(it.asset_id)) byAsset.set(it.asset_id, []);
    byAsset.get(it.asset_id).push(it);
  }
  for (const arr of byAsset.values()) {
    arr.sort((a,b) => new Date(a.inspection_date) - new Date(b.inspection_date));
    arr.forEach((it, idx) => it.inspection_count = idx + 1);
  }
  return list;
}

/* ------------ main ------------ */
(function main() {
  if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

  const users = generateUsers(U);
  const assets = generateAssets(A, users);
  const inspections = generateInspections(I, assets, users);

  fs.writeFileSync(path.join(OUT, 'users.json'), JSON.stringify(users, null, 2), 'utf-8');
  fs.writeFileSync(path.join(OUT, 'assets.json'), JSON.stringify(assets, null, 2), 'utf-8');
  fs.writeFileSync(path.join(OUT, 'asset_inspections.json'), JSON.stringify(inspections, null, 2), 'utf-8');

  console.log(`✅ users.json (${users.length})`);
  console.log(`✅ assets.json (${assets.length})`);
  console.log(`✅ asset_inspections.json (${inspections.length})`);
  console.log(`📁 output: ${path.resolve(OUT)}`);
})();
