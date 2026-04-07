#!/bin/bash
# OA Agent macOS 제거 스크립트
echo "=== OA Agent macOS 제거 ==="

PLIST_FILE="$HOME/Library/LaunchAgents/com.oamanager.agent.plist"
INSTALL_DIR="$HOME/Library/OAAgent"

# 서비스 중지
launchctl unload "$PLIST_FILE" 2>/dev/null

# 파일 삭제
rm -f "$PLIST_FILE"
rm -rf "$INSTALL_DIR"

echo "제거 완료!"
