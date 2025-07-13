#!/usr/bin/env bash
set -euo pipefail

# 기존 설치에서 새 구조로 마이그레이션

echo "Claude Context 마이그레이션 시작..."

OLD_DIR="$HOME/.claude/hooks"
BACKUP_DIR="$HOME/.claude/hooks_backup_$(date +%s)"

# 백업 생성
if [[ -d "$OLD_DIR" ]] && [[ ! -d "$OLD_DIR/src" ]]; then
    echo "기존 설치 발견. 백업 중..."
    cp -r "$OLD_DIR" "$BACKUP_DIR"
    echo "백업 완료: $BACKUP_DIR"
    
    # 새 설치 실행
    echo "새 버전 설치 중..."
    if [[ -f "$OLD_DIR/install.sh" ]]; then
        "$OLD_DIR/install.sh"
    else
        echo "설치 스크립트를 찾을 수 없습니다."
        echo "수동으로 재설치해주세요."
        exit 1
    fi
    
    echo "마이그레이션 완료!"
    echo "이전 설정은 $BACKUP_DIR 에 백업되었습니다."
else
    echo "마이그레이션이 필요하지 않습니다."
fi