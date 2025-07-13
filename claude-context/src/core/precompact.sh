#!/usr/bin/env bash
set -euo pipefail

# Claude Context - 통합 PreCompact Hook
# 대화 압축 시 컨텍스트 보호 및 요약 주입

# 스크립트 디렉토리 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 통합 injector 사용 (precompact 모드로 실행)
exec "${SCRIPT_DIR}/injector.sh" precompact