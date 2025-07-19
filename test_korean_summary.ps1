# Claude Context Korean Test Summary
# Runs English test and provides Korean summary

Write-Host ""
Write-Host "=== Claude Context Windows 테스트 실행 ===" -ForegroundColor Blue
Write-Host ""

# Run the English test
$result = & powershell -ExecutionPolicy Bypass -File "test_windows_english.ps1"
$exitCode = $LASTEXITCODE

Write-Host ""
Write-Host "=== 테스트 결과 요약 ===" -ForegroundColor Blue
Write-Host ""

if ($exitCode -eq 0) {
    Write-Host "✅ 모든 테스트 통과!" -ForegroundColor Green
    Write-Host ""
    Write-Host "확인된 항목:" -ForegroundColor Yellow
    Write-Host "  ✓ 핵심 스크립트 파일 (4개)" -ForegroundColor Green
    Write-Host "  ✓ PowerShell 설치 스크립트 (5개)" -ForegroundColor Green  
    Write-Host "  ✓ PowerShell 구문 검사 통과" -ForegroundColor Green
    Write-Host "  ✓ 추가 파일 존재 확인" -ForegroundColor Green
    Write-Host "  ✓ Git Bash 사용 가능" -ForegroundColor Green
    Write-Host "  ✓ Bash 스크립트 구문 검사 통과" -ForegroundColor Green
    Write-Host "  ✓ 기본 기능 테스트 통과" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Claude Context가 Windows 환경에서 정상 작동합니다!" -ForegroundColor Green
} else {
    Write-Host "⚠️ 일부 테스트 실패" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "자세한 내용은 위의 영어 테스트 결과를 확인하세요." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "테스트 완료 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

exit $exitCode
