-- =============================================================================
-- OA Manager v1 — 더미 데이터 (개발/테스트용)
-- =============================================================================

-- 도면 5건
INSERT INTO public.drawings (building, floor, grid_rows, grid_cols, description) VALUES
  ('본관', '1F', 10, 12, '본관 1층 도면'),
  ('본관', '2F', 10, 12, '본관 2층 도면'),
  ('본관', '3F', 10, 12, '본관 3층 도면'),
  ('별관', '1F',  8, 10, '별관 1층 도면'),
  ('별관', '2F',  8, 10, '별관 2층 도면');

-- =============================================================================
-- 자산 50건
-- =============================================================================
INSERT INTO public.assets (
  asset_uid, name, assets_status, supply_type, category,
  serial_number, model_name, vendor, building, floor,
  owner_name, owner_department, user_name, user_department,
  admin_name, admin_department, user_id, specifications,
  last_active_at
) VALUES
  -- 데스크탑 11대
  ('BDT00001','iMac 24 M3',          '사용','지급','데스크탑','SN-DT-001','iMac 24 M3','Apple','본관','3F','김철수','IT본부','김철수','IT본부','박관리','IT본부',1,'{"cpu":"M3","ram":"16GB","storage":"512GB SSD","os":"macOS Sonoma"}',now()-interval '10 min'),
  ('BDT00002','iMac 24 M3',          '사용','지급','데스크탑','SN-DT-002','iMac 24 M3','Apple','본관','3F','이영희','IT본부','이영희','IT본부','박관리','IT본부',1,'{"cpu":"M3","ram":"16GB","storage":"512GB SSD","os":"macOS Sonoma"}',now()-interval '5 min'),
  ('BDT00003','Dell OptiPlex 7010',  '사용','지급','데스크탑','SN-DT-003','OptiPlex 7010','Dell','본관','2F','박지민','경영지원부','박지민','경영지원부','박관리','IT본부',1,'{"cpu":"i5-13500","ram":"16GB","storage":"256GB SSD","os":"Windows 11 Pro"}',now()-interval '2 hours'),
  ('RDT00004','Dell OptiPlex 7010',  '사용','렌탈','데스크탑','SN-DT-004','OptiPlex 7010','Dell','본관','2F','최수진','마케팅부','최수진','마케팅부','박관리','IT본부',1,'{"cpu":"i5-13500","ram":"8GB","storage":"256GB SSD","os":"Windows 11 Pro"}',now()-interval '30 min'),
  ('BDT00005','HP EliteDesk 800 G9', '가용','지급','데스크탑','SN-DT-005','EliteDesk 800 G9','HP','별관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"cpu":"i7-12700","ram":"32GB","storage":"512GB SSD","os":"Windows 11 Pro"}',NULL),
  ('BDT00006','Lenovo ThinkCentre',  '사용','지급','데스크탑','SN-DT-006','ThinkCentre M70q','Lenovo','본관','1F','정민호','인사팀','정민호','인사팀','박관리','IT본부',1,'{"cpu":"i5-12400","ram":"16GB","storage":"256GB SSD","os":"Windows 10 Pro"}',now()-interval '3 hours'),
  ('BDT00007','Mac Mini M2',         '사용','지급','데스크탑','SN-DT-007','Mac Mini M2','Apple','본관','3F','한지은','IT본부','한지은','IT본부','박관리','IT본부',1,'{"cpu":"M2","ram":"16GB","storage":"256GB SSD","os":"macOS Ventura"}',now()-interval '1 hour'),
  ('BDT00008','Dell OptiPlex 5000',  '고장','지급','데스크탑','SN-DT-008','OptiPlex 5000','Dell','별관','2F','오준혁','재무부','오준혁','재무부','박관리','IT본부',1,'{"cpu":"i5-12500","ram":"8GB","storage":"256GB SSD","os":"Windows 11 Pro"}',now()-interval '7 days'),
  ('SDT00009','Dell OptiPlex 7010',  '점검필요','창고(점검)','데스크탑','SN-DT-009','OptiPlex 7010','Dell','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"cpu":"i5-13500","ram":"16GB","storage":"256GB SSD","os":"Windows 11 Pro"}',NULL),
  ('BDT00010','HP ProDesk 400 G9',   '가용','창고(대기)','데스크탑','SN-DT-010','ProDesk 400 G9','HP','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"cpu":"i3-12100","ram":"8GB","storage":"256GB SSD","os":"Windows 11 Pro"}',NULL),
  ('RDT00011','Dell OptiPlex 7010',  '사용','렌탈','데스크탑','SN-DT-011','OptiPlex 7010','Dell','본관','2F','정민호','인사팀','정민호','인사팀','박관리','IT본부',1,'{"cpu":"i5-13500","ram":"16GB","storage":"256GB SSD","os":"Windows 11 Pro"}',now()-interval '1 hour'),

  -- 노트북 11대
  ('BNB00001','MacBook Pro 14 M3',   '사용','지급','노트북','SN-NB-001','MacBook Pro 14','Apple','본관','3F','김철수','IT본부','김철수','IT본부','박관리','IT본부',1,'{"cpu":"M3 Pro","ram":"18GB","storage":"512GB SSD","os":"macOS Sonoma","display":"14.2 Liquid Retina XDR"}',now()-interval '15 min'),
  ('BNB00002','MacBook Air 15 M2',   '사용','지급','노트북','SN-NB-002','MacBook Air 15','Apple','본관','3F','이영희','IT본부','이영희','IT본부','박관리','IT본부',1,'{"cpu":"M2","ram":"16GB","storage":"256GB SSD","os":"macOS Ventura","display":"15.3 Liquid Retina"}',now()-interval '20 min'),
  ('RNB00003','Lenovo ThinkPad X1',  '사용','렌탈','노트북','SN-NB-003','ThinkPad X1 Carbon','Lenovo','본관','2F','박지민','경영지원부','박지민','경영지원부','박관리','IT본부',1,'{"cpu":"i7-1365U","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Pro","display":"14 WUXGA"}',now()-interval '45 min'),
  ('BNB00004','Dell Latitude 5540',  '사용','지급','노트북','SN-NB-004','Latitude 5540','Dell','별관','2F','송하나','디자인팀','송하나','디자인팀','박관리','IT본부',1,'{"cpu":"i7-1365U","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Pro","display":"15.6 FHD"}',now()-interval '1 hour'),
  ('BNB00005','HP EliteBook 840 G10','가용','지급','노트북','SN-NB-005','EliteBook 840 G10','HP','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"cpu":"i7-1355U","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Pro","display":"14 WUXGA"}',NULL),
  ('BNB00006','LG Gram 17',          '사용','지급','노트북','SN-NB-006','Gram 17Z90R','LG','본관','2F','최수진','마케팅부','최수진','마케팅부','박관리','IT본부',1,'{"cpu":"i7-1360P","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Home","display":"17 WQXGA"}',now()-interval '90 min'),
  ('RNB00007','Dell Latitude 7440',  '사용','렌탈','노트북','SN-NB-007','Latitude 7440','Dell','별관','1F','강민서','영업부','강민서','영업부','박관리','IT본부',1,'{"cpu":"i7-1365U","ram":"16GB","storage":"256GB SSD","os":"Windows 11 Pro","display":"14 FHD+"}',now()-interval '2 hours'),
  ('BNB00008','MacBook Pro 16 M3',   '사용','지급','노트북','SN-NB-008','MacBook Pro 16','Apple','본관','3F','한지은','IT본부','한지은','IT본부','박관리','IT본부',1,'{"cpu":"M3 Max","ram":"36GB","storage":"1TB SSD","os":"macOS Sonoma","display":"16.2 Liquid Retina XDR"}',now()-interval '8 min'),
  ('BNB00009','Samsung Galaxy Book3', '이동','지급','노트북','SN-NB-009','Galaxy Book3 Pro','Samsung','본관','2F','윤서연','법무팀','윤서연','법무팀','박관리','IT본부',1,'{"cpu":"i7-1360P","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Home","display":"14 AMOLED"}',now()-interval '5 hours'),
  ('BNB00010','HP EliteBook 860 G10','고장','지급','노트북','SN-NB-010','EliteBook 860 G10','HP','별관','2F','오준혁','재무부','오준혁','재무부','박관리','IT본부',1,'{"cpu":"i7-1355U","ram":"32GB","storage":"512GB SSD","os":"Windows 11 Pro","display":"16 WUXGA"}',now()-interval '14 days'),
  ('RNB00011','Lenovo ThinkPad T14s','사용','렌탈','노트북','SN-NB-011','ThinkPad T14s G4','Lenovo','별관','2F','윤서연','법무팀','윤서연','법무팀','박관리','IT본부',1,'{"cpu":"i7-1365U","ram":"16GB","storage":"512GB SSD","os":"Windows 11 Pro","display":"14 WUXGA"}',now()-interval '3 hours'),

  -- 모니터 8대
  ('BMN00001','Dell U2723QE',        '사용','지급','모니터','SN-MN-001','U2723QE','Dell','본관','3F','김철수','IT본부','김철수','IT본부','박관리','IT본부',1,'{"size":"27","resolution":"4K UHD","panel":"IPS","port":"USB-C, HDMI, DP"}',NULL),
  ('BMN00002','LG 27UK850',          '사용','지급','모니터','SN-MN-002','27UK850-W','LG','본관','3F','이영희','IT본부','이영희','IT본부','박관리','IT본부',1,'{"size":"27","resolution":"4K UHD","panel":"IPS","port":"USB-C, HDMI, DP"}',NULL),
  ('BMN00003','Samsung Odyssey G5',  '사용','지급','모니터','SN-MN-003','C34G55T','Samsung','본관','2F','박지민','경영지원부','박지민','경영지원부','박관리','IT본부',1,'{"size":"34","resolution":"UWQHD","panel":"VA","port":"HDMI, DP"}',NULL),
  ('BMN00004','Dell P2422H',         '가용','지급','모니터','SN-MN-004','P2422H','Dell','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"size":"24","resolution":"FHD","panel":"IPS","port":"HDMI, DP, VGA"}',NULL),
  ('BMN00005','LG 32UN880',          '사용','지급','모니터','SN-MN-005','32UN880-B','LG','별관','2F','송하나','디자인팀','송하나','디자인팀','박관리','IT본부',1,'{"size":"32","resolution":"4K UHD","panel":"IPS","port":"USB-C, HDMI"}',NULL),
  ('BMN00006','HP E24 G5',           '사용','지급','모니터','SN-MN-006','E24 G5','HP','본관','2F','최수진','마케팅부','최수진','마케팅부','박관리','IT본부',1,'{"size":"24","resolution":"FHD","panel":"IPS","port":"HDMI, DP, USB-C"}',NULL),
  ('BMN00007','BenQ PD2705U',        '사용','지급','모니터','SN-MN-007','PD2705U','BenQ','본관','3F','한지은','IT본부','한지은','IT본부','박관리','IT본부',1,'{"size":"27","resolution":"4K UHD","panel":"IPS","port":"USB-C, HDMI, DP"}',NULL),
  ('BMN00008','Dell P2723QE',        '점검필요','창고(점검)','모니터','SN-MN-008','P2723QE','Dell','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"size":"27","resolution":"4K UHD","panel":"IPS","port":"USB-C, HDMI, DP"}',NULL),

  -- 프린터 3대
  ('BPR00001','HP LaserJet M404',    '사용','지급','프린터','SN-PR-001','M404dn','HP','본관','2F','경영지원부','경영지원부',NULL,NULL,'박관리','IT본부',1,'{"type":"레이저","color":"흑백","speed":"38ppm","duplex":true}',NULL),
  ('RPR00002','Canon MF746Cdw',      '사용','렌탈','프린터','SN-PR-002','MF746Cdw','Canon','별관','1F','총무부','총무부',NULL,NULL,'박관리','IT본부',1,'{"type":"레이저","color":"컬러","speed":"27ppm","duplex":true}',NULL),
  ('BPR00003','Epson WF-C5890',      '고장','지급','프린터','SN-PR-003','WF-C5890','Epson','본관','3F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"type":"잉크젯","color":"컬러","speed":"25ppm","duplex":true}',NULL),

  -- 태블릿 3대
  ('BTB00001','iPad Pro 12.9 M2',    '사용','지급','태블릿','SN-TB-001','iPad Pro 12.9 M2','Apple','본관','3F','김철수','IT본부','김철수','IT본부','박관리','IT본부',1,'{"cpu":"M2","ram":"8GB","storage":"256GB","os":"iPadOS 17","display":"12.9 Liquid Retina XDR"}',now()-interval '25 min'),
  ('BTB00002','Galaxy Tab S9+',      '사용','지급','태블릿','SN-TB-002','Galaxy Tab S9+','Samsung','본관','2F','최수진','마케팅부','최수진','마케팅부','박관리','IT본부',1,'{"cpu":"Snapdragon 8 Gen 2","ram":"12GB","storage":"256GB","os":"Android 14","display":"12.4 AMOLED"}',now()-interval '40 min'),
  ('BTB00003','iPad Air 5',          '가용','지급','태블릿','SN-TB-003','iPad Air 5','Apple','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"cpu":"M1","ram":"8GB","storage":"64GB","os":"iPadOS 17","display":"10.9 Liquid Retina"}',NULL),

  -- IP전화기 4대
  ('BIP00001','Cisco 8841',          '사용','지급','IP전화기','SN-IP-001','CP-8841','Cisco','본관','3F','김철수','IT본부','김철수','IT본부','박관리','IT본부',1,'{"lines":5,"poe":true,"display":"5인치 컬러"}',NULL),
  ('BIP00002','Cisco 8841',          '사용','지급','IP전화기','SN-IP-002','CP-8841','Cisco','본관','2F','박지민','경영지원부','박지민','경영지원부','박관리','IT본부',1,'{"lines":5,"poe":true,"display":"5인치 컬러"}',NULL),
  ('BIP00003','Yealink T54W',        '사용','지급','IP전화기','SN-IP-003','SIP-T54W','Yealink','별관','1F','강민서','영업부','강민서','영업부','박관리','IT본부',1,'{"lines":16,"poe":true,"display":"4.3인치 컬러"}',NULL),
  ('BIP00004','Cisco 7821',          '가용','지급','IP전화기','SN-IP-004','CP-7821','Cisco','본관','1F',NULL,NULL,NULL,NULL,'박관리','IT본부',1,'{"lines":2,"poe":true,"display":"3.5인치"}',NULL),

  -- 네트워크장비 3대
  ('BNW00001','Cisco Catalyst 9200', '사용','지급','네트워크장비','SN-NW-001','C9200L-24P','Cisco','본관','1F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"type":"L2 스위치","ports":24,"poe":true,"management":"Web/CLI"}',now()-interval '1 min'),
  ('BNW00002','Aruba AP-505',        '사용','지급','네트워크장비','SN-NW-002','AP-505','Aruba','본관','2F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"type":"무선 AP","standard":"Wi-Fi 6","band":"2.4/5GHz","poe":true}',now()-interval '1 min'),
  ('BNW00003','FortiGate 60F',       '사용','지급','네트워크장비','SN-NW-003','FG-60F','Fortinet','본관','1F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"type":"방화벽","throughput":"10Gbps","vpn":true,"ips":true}',now()-interval '1 min'),

  -- 서버 2대
  ('BSV00001','Dell PowerEdge R750', '사용','지급','서버','SN-SV-001','PowerEdge R750','Dell','본관','1F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"cpu":"Xeon Gold 6338","ram":"128GB","storage":"4x 1.92TB SSD","os":"Ubuntu 22.04 LTS","rack":"A-01"}',now()-interval '30 sec'),
  ('BSV00002','HP ProLiant DL380',   '사용','지급','서버','SN-SV-002','DL380 Gen10 Plus','HP','본관','1F','IT본부','IT본부',NULL,NULL,'박관리','IT본부',1,'{"cpu":"Xeon Silver 4314","ram":"64GB","storage":"2x 960GB SSD","os":"Windows Server 2022","rack":"A-02"}',now()-interval '30 sec'),

  -- 스캐너 2대
  ('BSC00001','Fujitsu fi-800R',     '사용','지급','스캐너','SN-SC-001','fi-800R','Fujitsu','본관','2F','경영지원부','경영지원부',NULL,NULL,'박관리','IT본부',1,'{"type":"급지형","speed":"40ppm","duplex":true,"adf":true}',NULL),
  ('BSC00002','Epson DS-530 II',     '사용','지급','스캐너','SN-SC-002','DS-530 II','Epson','별관','1F','총무부','총무부',NULL,NULL,'박관리','IT본부',1,'{"type":"급지형","speed":"35ppm","duplex":true,"adf":true}',NULL);

-- 렌탈 만료일
UPDATE public.assets SET supply_end_date = now() + interval '5 days'   WHERE asset_uid = 'RDT00011';
UPDATE public.assets SET supply_end_date = now() + interval '3 days'   WHERE asset_uid = 'RNB00011';
UPDATE public.assets SET supply_end_date = now() + interval '45 days'  WHERE asset_uid = 'RDT00004';
UPDATE public.assets SET supply_end_date = now() + interval '90 days'  WHERE asset_uid = 'RNB00003';
UPDATE public.assets SET supply_end_date = now() + interval '180 days' WHERE asset_uid = 'RNB00007';
UPDATE public.assets SET supply_end_date = now() + interval '60 days'  WHERE asset_uid = 'RPR00002';

-- 배정 상태
UPDATE public.assets SET assignment_status = 'confirmed', assignment_confirmed_at = now() - interval '7 days'
  WHERE asset_uid IN ('BDT00001','BDT00002','BNB00001','BNB00002');
UPDATE public.assets SET assignment_status = 'pending'
  WHERE asset_uid IN ('BDT00003','BNB00004','BNB00009');

-- =============================================================================
-- 실사 기록 15건
-- =============================================================================
INSERT INTO public.asset_inspections (
  asset_id, user_id, inspector_name, user_team, asset_code, asset_type,
  inspection_date, inspection_building, inspection_floor, inspection_position,
  status, memo, synced
) VALUES
  ((SELECT id FROM public.assets WHERE asset_uid='BDT00001'),1,'Test User','IT본부','BDT00001','데스크탑',now()-interval '30 days','본관','3F','A구역','완료','정상 사용 확인',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BDT00002'),1,'Test User','IT본부','BDT00002','데스크탑',now()-interval '30 days','본관','3F','A구역','완료','모니터 연결 확인',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BDT00003'),1,'Test User','IT본부','BDT00003','데스크탑',now()-interval '28 days','본관','2F','B구역','완료',NULL,true),
  ((SELECT id FROM public.assets WHERE asset_uid='BDT00008'),1,'Test User','IT본부','BDT00008','데스크탑',now()-interval '25 days','별관','2F','C구역','완료','화면 깜빡임 → 고장 처리',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNB00001'),1,'Test User','IT본부','BNB00001','노트북',now()-interval '29 days','본관','3F','A구역','완료','배터리 상태 양호',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNB00002'),1,'Test User','IT본부','BNB00002','노트북',now()-interval '29 days','본관','3F','A구역','완료',NULL,true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNB00008'),1,'Test User','IT본부','BNB00008','노트북',now()-interval '27 days','본관','3F','A구역','완료','M3 Max 정상 동작',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BMN00001'),1,'Test User','IT본부','BMN00001','모니터',now()-interval '26 days','본관','3F','A구역','완료','4K 해상도 정상',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BPR00001'),1,'Test User','IT본부','BPR00001','프린터',now()-interval '20 days','본관','2F','B구역','완료','토너 교체 필요',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BSV00001'),1,'Test User','IT본부','BSV00001','서버',now()-interval '15 days','본관','1F','서버실','완료','RAID 정상, CPU 온도 정상',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BSV00002'),1,'Test User','IT본부','BSV00002','서버',now()-interval '15 days','본관','1F','서버실','완료','디스크 사용률 45%',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNW00001'),1,'Test User','IT본부','BNW00001','네트워크장비',now()-interval '15 days','본관','1F','통신실','완료','포트 24개 전부 활성',true),
  -- 2차 실사
  ((SELECT id FROM public.assets WHERE asset_uid='BDT00001'),1,'Test User','IT본부','BDT00001','데스크탑',now()-interval '2 days','본관','3F','A구역','완료','2차 실사 - 정상',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNB00001'),1,'Test User','IT본부','BNB00001','노트북',now()-interval '2 days','본관','3F','A구역','완료','2차 실사 - 배터리 91%',true),
  ((SELECT id FROM public.assets WHERE asset_uid='BNB00010'),1,'Test User','IT본부','BNB00010','노트북',now()-interval '1 day','별관','2F','C구역',NULL,'수리 의뢰 접수 예정',true);
