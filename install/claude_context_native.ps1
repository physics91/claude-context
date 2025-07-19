# Claude Context Native PowerShell Injector
# 이 스크립트는 bash 의존성 없이 PowerShell만으로 컨텍스트를 주입합니다.
# 더 나은 Windows 호환성과 성능을 제공합니다.

param(
    [Parameter(Mandatory=$false)]
    [string]$HookType = "pretooluse"
)

# 오류 발생 시 중단
$ErrorActionPreference = "Stop"

# 설정 로드
function Load-ClaudeConfig {
    $claudeHome = $env:CLAUDE_HOME ?? "$env:USERPROFILE\.claude"
    $configPath = Join-Path $claudeHome "hooks\claude-context\config.ps1"
    
    if (Test-Path $configPath) {
        try {
            . $configPath
            Write-Verbose "Configuration loaded from: $configPath"
        } catch {
            Write-Warning "Failed to load configuration: $_"
        }
    }
    
    # 기본값 설정
    if (-not $env:CLAUDE_CONTEXT_MODE) { $env:CLAUDE_CONTEXT_MODE = "basic" }
    if (-not $env:CLAUDE_ENABLE_CACHE) { $env:CLAUDE_ENABLE_CACHE = "true" }
    if (-not $env:CLAUDE_INJECT_PROBABILITY) { $env:CLAUDE_INJECT_PROBABILITY = "1.0" }
}

# 디렉토리 생성
function Ensure-Directory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        $null = New-Item -ItemType Directory -Path $Path -Force
        Write-Verbose "Created directory: $Path"
    }
}

# 확률 체크
function Test-ShouldInject {
    $probability = [double]($env:CLAUDE_INJECT_PROBABILITY ?? "1.0")
    $random = Get-Random -Minimum 0.0 -Maximum 1.0
    return $random -le $probability
}

# CLAUDE.md 내용 읽기
function Get-ClaudeContent {
    $content = ""
    $claudeHome = $env:CLAUDE_HOME ?? "$env:USERPROFILE\.claude"
    
    # 전역 CLAUDE.md
    $globalClaudeMd = Join-Path $claudeHome "CLAUDE.md"
    if (Test-Path $globalClaudeMd) {
        $globalContent = Get-Content $globalClaudeMd -Raw -ErrorAction SilentlyContinue
        if ($globalContent) {
            $content += $globalContent.TrimEnd()
            $content += "`n`n"
            Write-Verbose "Loaded global CLAUDE.md: $globalClaudeMd"
        }
    }
    
    # 프로젝트 CLAUDE.md (현재 디렉토리)
    $projectClaudeMd = Join-Path (Get-Location) "CLAUDE.md"
    if (Test-Path $projectClaudeMd) {
        $projectContent = Get-Content $projectClaudeMd -Raw -ErrorAction SilentlyContinue
        if ($projectContent) {
            $content += "# Project Context`n"
            $content += $projectContent.TrimEnd()
            $content += "`n`n"
            Write-Verbose "Loaded project CLAUDE.md: $projectClaudeMd"
        }
    }
    
    return $content.TrimEnd()
}

# 세션 정보 추가 (History 모드)
function Get-SessionInfo {
    if ($env:CLAUDE_CONTEXT_MODE -notin @("history", "oauth", "auto", "advanced")) {
        return ""
    }
    
    $historyDir = $env:CLAUDE_HISTORY_DIR ?? "$env:USERPROFILE\.claude\history"
    $sessionId = $env:CLAUDE_SESSION_ID ?? (Get-Date -Format "yyyyMMdd_HHmmss")
    
    if (-not (Test-Path $historyDir)) {
        return ""
    }
    
    $sessionFiles = Get-ChildItem -Path $historyDir -Filter "session_*.jsonl" -ErrorAction SilentlyContinue
    if ($sessionFiles) {
        $recentSessions = $sessionFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        $sessionInfo = "# Recent Sessions`n"
        foreach ($session in $recentSessions) {
            $sessionName = $session.BaseName -replace "^session_", ""
            $sessionInfo += "- Session: $sessionName ($(Get-Date $session.LastWriteTime -Format 'yyyy-MM-dd HH:mm'))`n"
        }
        $sessionInfo += "`n"
        return $sessionInfo
    }
    
    return ""
}

# 캐시 처리
function Get-CachedContent {
    param(
        [string]$Content,
        [string]$CacheDir
    )
    
    if ($env:CLAUDE_ENABLE_CACHE -ne "true") {
        return $null
    }
    
    Ensure-Directory $CacheDir
    
    # 내용 해시 생성
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Content))
    $hashString = [System.BitConverter]::ToString($hash) -replace '-', ''
    $cacheFile = Join-Path $CacheDir "$hashString.cache"
    
    # 캐시 유효성 검사
    $maxAge = [int]($env:CLAUDE_CACHE_MAX_AGE ?? "3600")
    if (Test-Path $cacheFile) {
        $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($cacheAge.TotalSeconds -lt $maxAge) {
            Write-Verbose "Using cached content: $cacheFile"
            return Get-Content $cacheFile -Raw
        }
    }
    
    # 캐시에 저장
    Set-Content -Path $cacheFile -Value $Content -Encoding UTF8
    Write-Verbose "Content cached: $cacheFile"
    
    return $Content
}

# 메인 처리 함수
function Invoke-ClaudeContextInjection {
    param([string]$Type)
    
    Write-Verbose "Starting Claude Context injection (Type: $Type, Mode: $($env:CLAUDE_CONTEXT_MODE))"
    
    # 확률 체크
    if (-not (Test-ShouldInject)) {
        Write-Verbose "Injection skipped (probability check)"
        return
    }
    
    # 디렉토리 생성
    $claudeHome = $env:CLAUDE_HOME ?? "$env:USERPROFILE\.claude"
    $cacheDir = $env:CLAUDE_CACHE_DIR ?? "$env:LOCALAPPDATA\claude-context"
    $logDir = $env:CLAUDE_LOG_DIR ?? "$claudeHome\logs"
    
    Ensure-Directory $claudeHome
    Ensure-Directory $cacheDir
    Ensure-Directory $logDir
    
    # 컨텐츠 생성
    $content = Get-ClaudeContent
    
    if (-not $content) {
        Write-Verbose "No CLAUDE.md content found"
        return
    }
    
    # 세션 정보 추가
    $sessionInfo = Get-SessionInfo
    if ($sessionInfo) {
        $content = $sessionInfo + $content
    }
    
    # 캐시 처리
    $finalContent = Get-CachedContent -Content $content -CacheDir $cacheDir
    
    if ($finalContent) {
        # 출력 (Claude Code가 읽을 수 있도록)
        Write-Output $finalContent
        Write-Verbose "Context injection completed ($(($finalContent -split "`n").Count) lines)"
    }
}

# 메인 실행
try {
    Load-ClaudeConfig
    Invoke-ClaudeContextInjection -Type $HookType
} catch {
    Write-Error "Claude Context injection failed: $_"
    exit 1
}
