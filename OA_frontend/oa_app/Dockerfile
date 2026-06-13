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
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

# main.dart.js / flutter_bootstrap.js는 CDN에 강하게 캐시될 수 있어,
# 배포마다 파일명/쿼리를 바꿔 캐시를 우회한다.
RUN set -eux; \
    build_id="$(date +%s)"; \
    main_cache_bust="main.${build_id}.dart.js"; \
    bootstrap_cache_bust="flutter_bootstrap.${build_id}.js"; \
    cp /app/build/web/main.dart.js "/app/build/web/${main_cache_bust}"; \
    cp /app/build/web/flutter_bootstrap.js "/app/build/web/${bootstrap_cache_bust}"; \
    sed -i "s#\"mainJsPath\":\"main.dart.js\"#\"mainJsPath\":\"${main_cache_bust}\"#g" "/app/build/web/${bootstrap_cache_bust}"; \
    sed -i "s#flutter_bootstrap.js?v=__BUILD_ID__#${bootstrap_cache_bust}#g" /app/build/web/index.html; \
    rm /app/build/web/main.dart.js /app/build/web/flutter_bootstrap.js

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
