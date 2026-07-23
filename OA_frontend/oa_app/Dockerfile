# ================================================================
# Stage 1: Flutter Web Build
# ================================================================
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# 의존성 먼저 복사 (레이어 캐시 최적화)
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# 소스 코드 복사
COPY . .

# 코드 생성 (riverpod_generator 등)
RUN dart run build_runner build --delete-conflicting-outputs

# 빌드 인자 (docker-compose build args로 전달)
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY

# Flutter 웹 빌드
RUN flutter build web --release \
    --no-tree-shake-icons \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

# 캐시 무효화 패턴(main.<id>.dart.js) 제거됨.
# 캐시 정책은 nginx.conf의 no-cache 헤더에 일임.
# index.html의 placeholder만 정리.
RUN sed -i 's#flutter_bootstrap.js?v=__BUILD_ID__#flutter_bootstrap.js#g' /app/build/web/index.html || true

# Flutter가 생성한 SW를 자가 소멸 SW로 교체 (옛 SW가 새 SW를 받은 직후 자기 자신 unregister)
RUN cat > /app/build/web/flutter_service_worker.js <<'EOF_SW'
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
      .then(() => self.registration.unregister())
      .then(() => self.clients.matchAll())
      .then((clients) => clients.forEach((c) => c.navigate(c.url)))
  );
});
EOF_SW

# 정적 파일 사전 gzip 압축 (nginx gzip_static 서빙용)
RUN find /app/build/web -type f \( \
    -name "*.js" -o -name "*.css" -o -name "*.html" \
    -o -name "*.json" -o -name "*.svg" -o -name "*.ttf" \
    \) -exec gzip -k -9 {} \;

# ================================================================
# Stage 2: nginx로 정적 파일 서빙
# ================================================================
FROM nginx:alpine

# 빌드 결과물 복사
COPY --from=builder /app/build/web /usr/share/nginx/html

# SPA 라우팅 nginx 설정
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
