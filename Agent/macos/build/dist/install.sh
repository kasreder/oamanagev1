#!/bin/bash
# OA Agent macOS 설치 스크립트
echo "=== OA Agent macOS 설치 ==="

INSTALL_DIR="$HOME/Library/OAAgent"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.oamanager.agent.plist"

# 설치 디렉토리 생성
mkdir -p "$INSTALL_DIR"
mkdir -p "$PLIST_DIR"

# JAR 복사
cp "$(dirname "$0")/macos.jar" "$INSTALL_DIR/oaagent.jar"

# 실행 스크립트 생성
cat > "$INSTALL_DIR/oaagent.sh" << 'SCRIPT'
#!/bin/bash
exec java -jar "$HOME/Library/OAAgent/oaagent.jar" "$@"
SCRIPT
chmod +x "$INSTALL_DIR/oaagent.sh"

# launchd plist 생성 (로그인 시 자동 실행)
cat > "$PLIST_FILE" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.oamanager.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>java</string>
        <string>-jar</string>
        <string>${INSTALL_DIR}/oaagent.jar</string>
        <string>--service</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/oaagent.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/oaagent_error.log</string>
</dict>
</plist>
PLIST

echo ""
echo "설치 완료!"
echo "  설치 위치: $INSTALL_DIR"
echo ""
echo "실행 방법:"
echo "  1) GUI 모드: $INSTALL_DIR/oaagent.sh"
echo "  2) 백그라운드 서비스: launchctl load $PLIST_FILE"
echo "  3) 즉시 전송: $INSTALL_DIR/oaagent.sh --send-now"
echo ""
echo "서비스 시작하려면:"
echo "  launchctl load $PLIST_FILE"
