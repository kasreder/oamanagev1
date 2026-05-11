#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo " OAManager v1 - Docker 시작"
echo " 도메인: oa.terraforming.info"
echo "============================================"

# 1. .env 파일 확인
if [ ! -f .env ]; then
    echo "[ERROR] .env 파일이 없습니다. .env.example을 복사하여 설정해주세요."
    echo "  cp .env.example .env"
    exit 1
fi

# 2. 기존 COSMOSX Traefik 네트워크 확인
if ! docker network inspect cosmosx_traefik-public >/dev/null 2>&1; then
    echo "[WARN] cosmosx_traefik-public 네트워크가 없습니다."
    echo "       기존 COSMOSX가 먼저 실행되어야 합니다."
    echo "       또는 수동으로 네트워크를 생성합니다:"
    echo ""
    read -p "  cosmosx_traefik-public 네트워크를 수동 생성할까요? (y/N) " answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        docker network create cosmosx_traefik-public
        echo "  → 네트워크 생성 완료"
    else
        echo "  → COSMOSX를 먼저 시작해주세요."
        exit 1
    fi
fi

# 3. 빌드 & 시작
echo ""
echo "[1/3] Docker 이미지 빌드 중..."
docker compose build

echo ""
echo "[2/3] 서비스 시작 중..."
docker compose up -d

echo ""
echo "[3/3] 서비스 상태 확인..."
sleep 5
docker compose ps

echo ""
echo "============================================"
echo " 시작 완료!"
echo ""
echo " Frontend : https://oa.terraforming.info"
echo " API      : https://api.oa.terraforming.info"
echo " DB       : localhost:5433"
echo "============================================"
