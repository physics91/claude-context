# Claude Context 마이그레이션 가이드

## 🔄 레거시 버전에서 통합 버전으로 업그레이드

### 주요 변경사항

1. **통합된 구조**
   - 여러 개의 injector와 precompact 파일이 하나로 통합
   - 환경 변수 기반 모드 제어
   - 공통 함수 라이브러리 분리

2. **새로운 설정 방식**
   - `config.sh` 파일로 중앙 집중식 설정
   - 3가지 모드 선택 가능 (basic, history, advanced)

3. **간소화된 설치**
   - 하나의 설치 스크립트로 모든 모드 지원
   - 대화형 설치 프로세스

### 마이그레이션 단계

#### 1. 백업 생성
```bash
cd ~/.claude/hooks
cp -r . ../hooks_backup_$(date +%Y%m%d)
```

#### 2. 통합 버전 설치
```bash
# 저장소 업데이트
git pull origin main

# 새 설치 스크립트 실행
./install/install.sh
```

#### 3. 기존 설정 마이그레이션

**기본 사용자 (CLAUDE.md만 사용)**
- 추가 작업 불필요, Basic 모드 선택

**토큰 모니터링 사용자**
- Advanced 모드 선택
- Gemini API 키 확인

**대화 기록 사용자**
- History 또는 Advanced 모드 선택
- 기존 대화 기록은 자동으로 유지됨

### 파일 매핑

| 레거시 파일 | 통합 버전 |
|---------|---------|
| `claude_md_injector.sh` | `src/core/injector.sh` |
| `claude_md_injector_with_history.sh` | `src/core/injector.sh` (history 모드) |
| `claude_md_injector_with_monitor.sh` | `src/core/injector.sh` (advanced 모드) |
| `claude_md_precompact.sh` | `src/core/precompact.sh` |
| `claude_md_enhanced_precompact.sh` | `src/core/precompact.sh` |

### 설정 변경

#### 레거시 (개별 스크립트 사용)
```json
{
  "hooks": {
    "PreToolUse": "~/.claude/hooks/claude_md_injector_with_monitor.sh",
    "PreCompact": "~/.claude/hooks/claude_md_enhanced_precompact.sh"
  }
}
```

#### 통합 버전 (통합 스크립트 + config.sh)
```json
{
  "hooks": {
    "PreToolUse": "~/.claude/hooks/src/core/injector.sh",
    "PreCompact": "~/.claude/hooks/src/core/precompact.sh"
  }
}
```

```bash
# config.sh
CLAUDE_CONTEXT_MODE="advanced"  # 또는 "basic", "history"
```

### 문제 해결

**Q: 기존 대화 기록이 사라졌어요**
A: 대화 기록은 `~/.claude/history/`에 그대로 있습니다. History 또는 Advanced 모드를 선택했는지 확인하세요.

**Q: 토큰 모니터링이 작동하지 않아요**
A: Advanced 모드를 선택했는지, Gemini가 설치되어 있는지 확인하세요.

**Q: 설정을 변경하고 싶어요**
A: `~/.claude/hooks/install/configure_hooks.sh` 실행하여 모드를 변경할 수 있습니다.

### 롤백 방법

문제가 발생한 경우:
```bash
# 백업에서 복원
rm -rf ~/.claude/hooks
mv ~/.claude/hooks_backup_* ~/.claude/hooks

# Claude 설정 복원
cp ~/.config/claude/claude_desktop/settings.json.backup.* \
   ~/.config/claude/claude_desktop/settings.json
```

## 🎉 통합 버전의 장점

1. **단순화된 유지보수**: 통합된 코드베이스
2. **유연한 설정**: 모드 간 쉬운 전환
3. **향상된 성능**: 공통 함수 재사용
4. **더 나은 테스트**: 통합 테스트 스위트
5. **명확한 구조**: src/, tests/, docs/ 분리

질문이 있으시면 [이슈](https://github.com/physics91/claude-context/issues)를 등록해주세요!