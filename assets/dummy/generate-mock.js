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
const shuffle = (arr) => {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = randomInt(0, i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
};
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
function resolveOrganization(team, dept, hq) {
  return team ?? dept ?? hq; // 팀 → 실 → 본부
}

/* ------------ dictionaries ------------ */
const HQS = ['경영본부','생산본부','영업본부','연구개발본부','품질본부'];
// 모두 "~실"
const DEPTS = ['재무실','인사실','생산기술실','마케팅실','R&D실','품질관리실'];
const TEAMS = ['회계팀','급여팀','자동화팀','콘텐츠팀','플랫폼팀','검사팀','품질보증팀'];
const PARTS = ['결산파트','운영파트','설계파트','데이터파트','시스템파트']; // 90% null
const POSITIONS = ['본부장', '실장', '팀장', '파트장', '책임', '고문', null];
const BUILDINGS = ['본사A동','본사B동','공장1','공장2','연구동', null];
const FLOORS = ['1층','2층','3층','4층','5층','6층', null];

const ASSET_STATUS = ['사용','가용(창고)','이동'];
const BUILDING1 = ['본사','개발실','본사외'];
const NETWORKS = [null, '업무망','개발망','시스템망','무선업무망','무선인터넷','유선인터넷','로컬'];
const VENDORS = ['Lenovo','HP','Dell','Apple','Samsung','LG','Cisco','Siemens','Omron','Mitsubishi','Universal Robots'];
const ASSET_TYPES = ['데스크탑','모니터','프린터','스캐너','노트북','태블릿','소모품'];

// OS 목록(소문자 표기 유지)
const OS_LIST = ['win', 'ios', 'mac os', 'ipados', 'android', 'etc'];

// memo 샘플
const MEMOS = [
  '정기점검 완료', '부품 교체 필요', '펌웨어 업데이트 예정', '사용 빈도 낮음',
  '소음 발생 관찰됨', '정상 동작', '오염으로 청소 필요', '이동 계획 있음', null
];

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
function osVersion(os) {
  switch (os) {
    case 'win': {
      const win = pick(['10 22H2','11 23H2','11 24H2']);
      return `Windows ${win}`;
    }
    case 'ios': {
      const v = pick(['17.6','17.6.1','18.0','18.1']);
      return `iOS ${v}`;
    }
    case 'mac os': {
      const v = pick(['13.6','14.6.1','15.0']);
      return `macOS ${v}`;
    }
    case 'ipados': {
      const v = pick(['17.6','18.0']);
      return `iPadOS ${v}`;
    }
    case 'android': {
      const v = pick(['13','14','15']);
      return `Android ${v}`;
    }
    case 'etc':
    default:
      return pick(['FreeDOS 1.3','Ubuntu 22.04','Rocky 9','Unknown']);
  }
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
      organization_dept: Math.random() < 0.03 ? null : pick(DEPTS), // 3% null
      organization_team: Math.random() < 0.30 ? null : pick(TEAMS),  // ✅ 팀 30% null
      organization_part: Math.random() < 0.9 ? null : pick(PARTS),   // 90% null
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

    // OS / OS 버전
    const os = pick(OS_LIST);
    const os_ver = osVersion(os);

    // memo1, memo2
    let memo1 = chance(0.55) ? pick(MEMOS) : null;
    const memo2 = chance(0.55) ? pick(MEMOS) : null;

    // ✅ 공용 자산일 때 memo1을 "<팀명> <이름> 사용" 형식으로 강제 입력
    if (!assigned) {
      memo1 = `${pick(TEAMS)} ${koreanName()} 사용`;
    }

    // ✅ organization (팀→실→본부)
    let orgTeam, orgDept, orgHq;
    if (assigned) {
      orgTeam = assigned.organization_team ?? null;
      orgDept = assigned.organization_dept ?? null;
      orgHq   = assigned.organization_hq; // 항상 값 존재
    } else {
      // 공용일 때도 규칙 적용을 위해 가상의 조직값 생성
      orgTeam = Math.random() < 0.30 ? null : pick(TEAMS);          // 팀 30% null 규칙 반영
      orgDept = Math.random() < 0.03 ? null : pick(DEPTS);          // 실 3% null 규칙 반영
      orgHq   = pick(HQS);
    }
    const organization = resolveOrganization(orgTeam, orgDept, orgHq);

    res.push({
      id: i + 1,
      asset_uid: assetUid(),
      name: assigneeName,
      assets_status: status,
      assets_types: pick(ASSET_TYPES),      // category 대신
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
      // ★ 추가된 필드
      memo1,
      memo2,
      os,
      os_ver,
      organization, // ✅ 새 필드
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
  const uniqueTotal = Math.min(total, assets.length);
  const assetPool = shuffle(assets).slice(0, uniqueTotal);

  for (let i = 0; i < assetPool.length; i++) {
    const asset = assetPool[i];
    const user = asset.user_id ? users[asset.user_id - 1] : pick(users);
    const inspector = koreanName();
    const deptConfirm = user?.organization_dept ?? pick(DEPTS);

    const when = randBetweenDays(150, 0);

    // 50%는 미검증 처리
    const is_verified = chance(0.5) ? false : true;

    const base = {
      id: i + 1,
      asset_id: asset.id,
      user_id: user?.id ?? null,
      inspector_name: inspector,
      user_team: user?.organization_team ?? pick(TEAMS),
      asset_code: asset.asset_uid,
      asset_type: pick(ASSET_TYPES),
      asset_info: {
        model_name: asset.model_name,
        usage: asset.user_id ? "개인" : "공용",
        serial_number: asset.serial_number
      },
      inspection_count: 1,
      inspection_date: iso(when),
      // maintenance_company_staff 제거됨
      department_confirm: deptConfirm,
      is_verified
    };

    if (!is_verified) {
      // 인증되지 않은 값은 null 처리
      base.inspector_name = null;
      base.user_team = null;
      base.department_confirm = null;
      base.asset_info = {
        model_name: null,
        usage: asset.user_id ? "개인" : "공용", // 용도는 유지
        serial_number: null
      };
    }

    list.push(base);
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
