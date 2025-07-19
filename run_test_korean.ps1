# Korean Test Runner for Claude Context
# This script runs the English test and provides Korean output

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "=== Claude Context Windows 테스트 시작 ===" -ForegroundColor Blue
Write-Host ""

# Run the English test script and capture output
$testResult = & powershell -ExecutionPolicy Bypass -File "test_windows_clean.ps1"
$exitCode = $LASTEXITCODE

# Display the output with Korean headers
Write-Host "테스트 실행 결과:" -ForegroundColor Yellow
Write-Host ""

# Parse and translate key parts of the output
$lines = $testResult -split "`n"
foreach ($line in $lines) {
    if ($line -match "=== (.+) ===") {
        $section = $matches[1]
        switch ($section) {
            "Claude Context Windows Test Suite" { 
                Write-Host "=== Claude Context Windows 테스트 스위트 ===" -ForegroundColor Blue 
            }
            "Test Results" { 
                Write-Host "=== 테스트 결과 ===" -ForegroundColor Blue 
            }
            default { 
                Write-Host $line -ForegroundColor Blue 
            }
        }
    }
    elseif ($line -match "^\d+\. (.+)") {
        $sectionName = $matches[1]
        switch ($sectionName) {
            "Core Script Files" { 
                Write-Host "1. 핵심 스크립트 파일" -ForegroundColor Yellow 
            }
            "PowerShell Scripts" { 
                Write-Host "2. PowerShell 스크립트" -ForegroundColor Yellow 
            }
            "PowerShell Syntax Check" { 
                Write-Host "3. PowerShell 구문 검사" -ForegroundColor Yellow 
            }
            "Additional Files" { 
                Write-Host "4. 추가 파일" -ForegroundColor Yellow 
            }
            "Git Bash Check" { 
                Write-Host "5. Git Bash 확인" -ForegroundColor Yellow 
            }
            "Basic Functionality Test" { 
                Write-Host "6. 기본 기능 테스트" -ForegroundColor Yellow 
            }
            default { 
                Write-Host $line -ForegroundColor Yellow 
            }
        }
    }
    elseif ($line -match "Total Tests: (\d+)") {
        Write-Host "총 테스트: $($matches[1])"
    }
    elseif ($line -match "Passed: (\d+)") {
        Write-Host "성공: $($matches[1])" -ForegroundColor Green
    }
    elseif ($line -match "Failed: (\d+)") {
        Write-Host "실패: $($matches[1])" -ForegroundColor Red
    }
    elseif ($line -match "Coverage: (\d+%)") {
        Write-Host "커버리지: $($matches[1])" -ForegroundColor Green
    }
    elseif ($line -match "All tests passed!") {
        Write-Host "🎉 모든 테스트 통과!" -ForegroundColor Green
    }
    elseif ($line -match "Some tests failed") {
        Write-Host "❌ 일부 테스트 실패" -ForegroundColor Red
    }
    elseif ($line -match "exists") {
        $translatedLine = $line -replace "exists", "존재"
        Write-Host $translatedLine -ForegroundColor Green
    }
    elseif ($line -match "syntax OK") {
        $translatedLine = $line -replace "syntax OK", "구문 정상"
        Write-Host $translatedLine -ForegroundColor Green
    }
    elseif ($line -match "available") {
        $translatedLine = $line -replace "available", "사용 가능"
        Write-Host $translatedLine -ForegroundColor Green
    }
    elseif ($line -match "created") {
        $translatedLine = $line -replace "created", "생성됨"
        Write-Host $translatedLine -ForegroundColor Green
    }
    else {
        Write-Host $line
    }
}

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "✅ 테스트 완료 - 모든 기능이 정상 작동합니다!" -ForegroundColor Green
} else {
    Write-Host "⚠️ 테스트 완료 - 일부 문제가 발견되었습니다." -ForegroundColor Yellow
}

exit $exitCode
