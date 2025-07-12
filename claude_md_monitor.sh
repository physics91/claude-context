#!/usr/bin/env bash
# CLAUDE.md Hook 모니터링 도구

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수: 로그 분석
analyze_logs() {
    echo -e "${BLUE}=== 로그 분석 ===${NC}"
    local log_file="/tmp/claude_md_injector.log"
    
    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}로그 파일이 없습니다.${NC}"
        return
    fi
    
    # 통계
    local total_calls=$(grep -c "Script completed successfully" "$log_file" 2>/dev/null || echo 0)
    local cache_hits=$(grep -c "Cache is valid" "$log_file" 2>/dev/null || echo 0)
    local cache_misses=$(grep -c "No cache found\|Cache is invalid" "$log_file" 2>/dev/null || echo 0)
    local errors=$(grep -c "ERROR:" "$log_file" 2>/dev/null || echo 0)
    
    # 변수 정리 (개행 문자 제거)
    total_calls=${total_calls//[[:space:]]/}
    cache_hits=${cache_hits//[[:space:]]/}
    cache_misses=${cache_misses//[[:space:]]/}
    errors=${errors//[[:space:]]/}
    
    echo "총 호출 횟수: $total_calls"
    echo "캐시 히트: $cache_hits ($(( cache_hits * 100 / (total_calls + 1) ))%)"
    echo "캐시 미스: $cache_misses"
    echo "오류 발생: $errors"
    
    # 최근 프로젝트들
    echo -e "\n${YELLOW}최근 작업한 프로젝트:${NC}"
    grep "Project root:" "$log_file" | tail -10 | sort | uniq -c | sort -rn | head -5
    
    # 오류가 있다면 표시
    if [[ "$errors" -gt 0 ]]; then
        echo -e "\n${RED}최근 오류:${NC}"
        grep "ERROR:" "$log_file" | tail -5
    fi
}

# 함수: 캐시 상태 확인
check_cache() {
    echo -e "\n${BLUE}=== 캐시 상태 ===${NC}"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
    
    if [[ ! -d "$cache_dir" ]]; then
        echo -e "${RED}캐시 디렉토리가 없습니다.${NC}"
        return
    fi
    
    local cache_count=$(ls -1 "$cache_dir" | wc -l)
    local cache_size=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
    
    echo "캐시 파일 수: $cache_count"
    echo "캐시 크기: $cache_size"
    
    # 최근 캐시 파일들
    echo -e "\n${YELLOW}최근 캐시 파일:${NC}"
    ls -lt "$cache_dir" | head -6 | tail -5
}

# 함수: 실시간 모니터링
live_monitor() {
    echo -e "${BLUE}=== 실시간 모니터링 (Ctrl+C로 종료) ===${NC}"
    local log_file="/tmp/claude_md_injector.log"
    
    tail -f "$log_file" | while read -r line; do
        if [[ "$line" =~ "Script completed successfully" ]]; then
            echo -e "${GREEN}✓${NC} $line"
        elif [[ "$line" =~ "ERROR:" ]]; then
            echo -e "${RED}✗${NC} $line"
        elif [[ "$line" =~ "Cache is valid" ]]; then
            echo -e "${BLUE}↻${NC} $line"
        elif [[ "$line" =~ "Project root:" ]]; then
            echo -e "${YELLOW}📁${NC} $line"
        else
            echo "  $line"
        fi
    done
}

# 함수: 특정 프로젝트 확인
check_project() {
    local project_path="${1:-$PWD}"
    echo -e "${BLUE}=== 프로젝트 확인: $project_path ===${NC}"
    
    # 테스트 페이로드 생성
    local payload=$(jq -n --arg wd "$project_path" '{"working_directory": $wd}')
    
    # 스크립트 실행 및 결과 분석
    local result=$(echo "$payload" | /home/physics91/.claude/hooks/claude_md_injector.sh)
    
    echo -e "\n${YELLOW}메타데이터:${NC}"
    echo "$result" | jq -C '.metadata'
    
    echo -e "\n${YELLOW}주입될 내용 (첫 500자):${NC}"
    echo "$result" | jq -r '.prepend_system' | head -c 500
    echo "..."
}

# 함수: 캐시 정리
clean_cache() {
    echo -e "${BLUE}=== 캐시 정리 ===${NC}"
    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
    
    if [[ ! -d "$cache_dir" ]]; then
        echo "캐시 디렉토리가 없습니다."
        return
    fi
    
    echo -n "정말로 캐시를 정리하시겠습니까? (y/N): "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf "$cache_dir"/*
        echo -e "${GREEN}캐시가 정리되었습니다.${NC}"
    else
        echo "취소되었습니다."
    fi
}

# 메인 메뉴
show_menu() {
    echo -e "\n${BLUE}=== CLAUDE.md Hook 모니터링 도구 ===${NC}"
    echo "1) 로그 분석"
    echo "2) 캐시 상태 확인"
    echo "3) 실시간 모니터링"
    echo "4) 특정 프로젝트 확인"
    echo "5) 캐시 정리"
    echo "6) 종료"
    echo -n "선택: "
}

# 메인 루프
if [[ $# -eq 0 ]]; then
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1) analyze_logs ;;
            2) check_cache ;;
            3) live_monitor ;;
            4) 
                echo -n "프로젝트 경로 (Enter=현재 디렉토리): "
                read -r path
                check_project "$path"
                ;;
            5) clean_cache ;;
            6) echo "종료합니다."; exit 0 ;;
            *) echo -e "${RED}잘못된 선택입니다.${NC}" ;;
        esac
        
        echo -e "\n계속하려면 Enter를 누르세요..."
        read -r
    done
else
    # 명령줄 인수 처리
    case "$1" in
        log) analyze_logs ;;
        cache) check_cache ;;
        live) live_monitor ;;
        project) check_project "${2:-}" ;;
        clean) clean_cache ;;
        *) echo "사용법: $0 [log|cache|live|project|clean]" ;;
    esac
fi