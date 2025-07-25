# Claude Context 업데이트 가이드

Claude Context는 원 커맨드로 쉽게 업데이트할 수 있는 시스템을 제공합니다.

## 빠른 업데이트

### Linux/macOS
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash
```

### Windows PowerShell
```powershell
iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
```

## 업데이트 옵션

### 환경 변수 설정

업데이트 동작을 환경 변수로 제어할 수 있습니다:

```bash
# 강제 업데이트 (버전 확인 생략)
CLAUDE_UPDATE_FORCE=true curl -sSL ... | bash

# 백업 보관 개수 설정 (기본값: 5)
CLAUDE_UPDATE_BACKUP_KEEP=10 curl -sSL ... | bash
```

### PowerShell 매개변수

```powershell
# 강제 업데이트
iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1) -Force

# 백업 보관 개수 설정
iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1) -BackupKeep 10
```

## 업데이트 확인

업데이트가 필요한지 먼저 확인하려면:

### Linux/macOS
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/check-updates.sh | bash
```

### 로컬 설치에서
```bash
# 프로젝트 루트에서
./check-updates.sh
./update.sh --check
./update.sh --info
```

## 로컬 업데이트 (개발자용)

프로젝트를 직접 클론한 경우:

```bash
# 프로젝트 루트에서
./update.sh                # 일반 업데이트
./update.sh --force         # 강제 업데이트
./update.sh --check         # 확인만
./update.sh --info          # 버전 정보 표시
```

## 백업 및 롤백

### 자동 백업

업데이트 시 기존 설치가 자동으로 백업됩니다:
- **위치**: `~/.claude/backups/`
- **형식**: `claude-context-<버전>-<타임스탬프>`
- **보관**: 기본 5개 (설정 가능)

### 수동 롤백

문제 발생 시 수동으로 롤백할 수 있습니다:

```bash
# 백업 목록 확인
ls ~/.claude/backups/

# 특정 백업으로 롤백
rm -rf ~/.claude/hooks/claude-context
cp -r ~/.claude/backups/claude-context-1.0.0-20240125_143022 ~/.claude/hooks/claude-context

# Claude Code 재시작
```

## 버전 관리

### 현재 버전 확인

```bash
cat ~/.claude/hooks/claude-context/VERSION
```

### 버전 비교

업데이트 스크립트는 Semantic Versioning을 지원합니다:
- `1.0.0` → `1.0.1`: 패치 업데이트
- `1.0.0` → `1.1.0`: 마이너 업데이트  
- `1.0.0` → `2.0.0`: 메이저 업데이트

## 업데이트 프로세스

1. **버전 확인**: GitHub에서 최신 버전 정보 가져오기
2. **백업 생성**: 현재 설치 백업
3. **소스 다운로드**: 최신 소스 코드 다운로드
4. **설정 보존**: 기존 사용자 설정 백업
5. **업데이트 적용**: 새 버전 설치
6. **설정 복원**: 사용자 설정 복원
7. **백업 정리**: 오래된 백업 제거

## 안전 기능

### 설정 보존

업데이트 시 다음 설정이 보존됩니다:
- **모드 설정**: basic, history, oauth, auto, advanced
- **훅 타입**: UserPromptSubmit, PreToolUse
- **사용자 정의 설정**: config.sh의 커스터마이징

### 실패 시 자동 롤백

업데이트 중 오류 발생 시:
1. 자동으로 이전 버전으로 롤백
2. 오류 메시지 표시
3. 문제 해결 방법 안내

## 문제 해결

### 업데이트 실패

```bash
# 의존성 확인
command -v curl git jq

# 네트워크 연결 확인  
curl -I https://github.com

# 권한 확인
ls -la ~/.claude/hooks/

# 강제 업데이트 시도
CLAUDE_UPDATE_FORCE=true curl -sSL ... | bash
```

### 백업 복원

```bash
# 백업 목록 확인
find ~/.claude/backups -name "claude-context-*" -type d | sort

# 최신 백업으로 복원
LATEST_BACKUP=$(find ~/.claude/backups -name "claude-context-*" -type d | sort | tail -1)
rm -rf ~/.claude/hooks/claude-context
cp -r "$LATEST_BACKUP" ~/.claude/hooks/claude-context
```

### 권한 문제

```bash
# 실행 권한 확인
find ~/.claude/hooks/claude-context -name "*.sh" -not -executable

# 권한 수정
chmod +x ~/.claude/hooks/claude-context/src/core/*.sh
chmod +x ~/.claude/hooks/*.sh
```

## 개발자 정보

### 버전 태그

GitHub 릴리즈를 통해 버전을 관리합니다:
```bash
git tag v1.0.1
git push origin v1.0.1
```

### VERSION 파일

프로젝트 루트의 `VERSION` 파일이 기준 버전입니다:
```bash
echo "1.0.1" > VERSION
git add VERSION
git commit -m "feat: 버전 1.0.1로 업데이트"
```

## 자주 묻는 질문

**Q: 업데이트 시 기존 CLAUDE.md 파일이 삭제되나요?**  
A: 아니요. CLAUDE.md 파일은 사용자 데이터로 간주되어 보존됩니다.

**Q: 다운그레이드가 가능한가요?**  
A: 백업을 통해 이전 버전으로 롤백할 수 있습니다.

**Q: 업데이트 후 Claude Code를 재시작해야 하나요?**  
A: 네, 훅 설정이 변경되므로 Claude Code 재시작이 필요합니다.

**Q: 네트워크 없이 업데이트할 수 있나요?**  
A: 로컬에 소스가 있다면 `./update.sh`를 사용할 수 있습니다.

---

더 자세한 정보는 [GitHub Issues](https://github.com/physics91/claude-context/issues)에서 확인하거나 질문해주세요.