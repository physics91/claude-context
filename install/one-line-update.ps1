# Claude Context 원클릭 업데이트 스크립트 (PowerShell)
# 사용법: iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
# 
# 환경 변수로 옵션 설정 가능:
# $env:CLAUDE_UPDATE_FORCE = "true"  # 강제 업데이트
# $env:CLAUDE_UPDATE_BACKUP_KEEP = "10"  # 백업 보관 개수

param(
    [switch]$Force,
    [switch]$CheckOnly,
    [int]$BackupKeep = 5
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# 설정
$GITHUB_USER = "physics91"
$GITHUB_REPO = "claude-context"
$GITHUB_BRANCH = "main"

# 환경 변수 확인
$FORCE_UPDATE = if ($env:CLAUDE_UPDATE_FORCE -eq "true" -or $Force) { $true } else { $false }
$BACKUP_KEEP = if ($env:CLAUDE_UPDATE_BACKUP_KEEP) { [int]$env:CLAUDE_UPDATE_BACKUP_KEEP } else { $BackupKeep }

# 색상 함수
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        'Red' = 'Red'
        'Green' = 'Green'
        'Yellow' = 'Yellow'
        'Blue' = 'Cyan'
        'White' = 'White'
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

function Write-Header {
    Write-ColorOutput "╔════════════════════════════════════════╗" -Color Blue
    Write-ColorOutput "║     Claude Context 업데이트             ║" -Color Blue  
    Write-ColorOutput "╚════════════════════════════════════════╝" -Color Blue
    Write-Host ""
}

# PowerShell 보안 설정 검증 및 설정
function Set-SecurePowerShellPolicy {
    try {
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        
        if ($currentPolicy -eq "Bypass" -or $currentPolicy -eq "Unrestricted") {
            Write-ColorOutput "경고: 현재 PowerShell 실행 정책이 비보안적입니다: $currentPolicy" -Color Yellow
            Write-Host "보안을 위해 RemoteSigned로 변경합니다..."
            
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-ColorOutput "✓ PowerShell 실행 정책이 RemoteSigned로 설정되었습니다" -Color Green
        }
    } catch {
        Write-ColorOutput "경고: PowerShell 실행 정책 설정에 실패했습니다: $_" -Color Yellow
    }
}

# 입력 값 검증 함수
function Test-InputValidation {
    param(
        [int]$BackupKeep
    )
    
    # BACKUP_KEEP 값 검증 (1-50 범위)
    if ($BackupKeep -lt 1 -or $BackupKeep -gt 50) {
        Write-ColorOutput "Error: BACKUP_KEEP 값이 잘못되었습니다. 1-50 범위여야 합니다: $BackupKeep" -Color Red
        exit 1
    }
    
    return $true
}

# 보안 강화된 임시 디렉토리 생성
function New-SecureTempDirectory {
    try {
        $tempDir = New-TemporaryFile | ForEach-Object { 
            Remove-Item $_
            New-Item -ItemType Directory -Path $_ 
        }
        
        # 소유자만 접근 가능하도록 권한 설정
        $acl = Get-Acl $tempDir
        $acl.SetAccessRuleProtection($true, $false)
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $tempDir -AclObject $acl
        
        return $tempDir
    } catch {
        Write-ColorOutput "Error: 보안 임시 디렉토리 생성 실패: $_" -Color Red
        throw
    }
}

# Git 저장소 보안 검증
function Test-GitSecurity {
    param(
        [string]$RepoPath,
        [string]$ExpectedUser = $GITHUB_USER,
        [string]$ExpectedRepo = $GITHUB_REPO
    )
    
    if (-not (Test-Path "$RepoPath\.git")) {
        Write-ColorOutput "Error: 유효한 Git 저장소가 아닙니다: $RepoPath" -Color Red
        return $false
    }
    
    try {
        Set-Location $RepoPath
        
        # 원격 저장소 URL 검증
        $remoteUrl = & git config --get remote.origin.url 2>$null
        $expectedUrls = @(
            "https://github.com/$ExpectedUser/$ExpectedRepo.git",
            "git@github.com:$ExpectedUser/$ExpectedRepo.git"
        )
        
        if ($remoteUrl -notin $expectedUrls) {
            Write-ColorOutput "Error: 저장소 URL 검증 실패: $remoteUrl" -Color Red
            return $false
        }
        
        # 최신 커밋 검증
        try {
            $apiUrl = "https://api.github.com/repos/$ExpectedUser/$ExpectedRepo/commits/$GITHUB_BRANCH"
            $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
            $expectedSha = $response.sha
            
            $actualSha = & git rev-parse HEAD 2>$null
            
            if ($actualSha -ne $expectedSha) {
                Write-ColorOutput "Error: 커밋 해시 검증 실패: expected $expectedSha, got $actualSha" -Color Red
                return $false
            }
            
            Write-Host "✓ Git 보안 검증 완료: $actualSha"
        } catch {
            Write-ColorOutput "경고: 커밋 해시 검증을 수행할 수 없습니다" -Color Yellow
        }
        
        return $true
    } catch {
        Write-ColorOutput "Error: Git 보안 검증 중 오류 발생: $_" -Color Red
        return $false
    }
}

# 필수 도구 확인
function Test-Dependencies {
    $missing = @()
    
    # Git 확인
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "git"
    }
    
    if ($missing.Count -gt 0) {
        Write-ColorOutput "Error: 다음 도구가 설치되어 있지 않습니다: $($missing -join ', ')" -Color Red
        Write-Host "Git for Windows를 설치해주세요: https://git-scm.com/download/win"
        exit 1
    }
}

# Claude Context 설치 확인
function Test-Installation {
    $installDir = "$env:USERPROFILE\.claude\hooks\claude-context"
    
    if (-not (Test-Path $installDir)) {
        Write-ColorOutput "Error: Claude Context가 설치되어 있지 않습니다." -Color Red
        Write-Host "먼저 설치를 진행하세요:"
        Write-Host "iex (irm https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/install/one-line-install.ps1)"
        exit 1
    }
}

# 현재 버전 가져오기
function Get-CurrentVersion {
    $installDir = "$env:USERPROFILE\.claude\hooks\claude-context"
    $versionFile = Join-Path $installDir "VERSION"
    
    if (Test-Path $versionFile) {
        return (Get-Content $versionFile -Raw).Trim()
    } else {
        return "unknown"
    }
}

# 최신 버전 가져오기
function Get-LatestVersion {
    try {
        # GitHub API에서 최신 릴리즈 확인
        $apiUrl = "https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction SilentlyContinue
        
        if ($response.tag_name) {
            return $response.tag_name -replace '^v', ''
        }
    } catch {
        # API 호출 실패 시 무시하고 계속
    }
    
    try {
        # 릴리즈가 없으면 메인 브랜치의 VERSION 파일 확인
        $versionUrl = "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/VERSION"
        $version = (Invoke-WebRequest -Uri $versionUrl -ErrorAction Stop).Content.Trim()
        return $version
    } catch {
        Write-ColorOutput "최신 버전 정보를 가져올 수 없습니다." -Color Red
        throw
    }
}

# 버전 비교
function Compare-Versions {
    param(
        [string]$Version1,
        [string]$Version2
    )
    
    if ($Version1 -eq "unknown") { return "older" }
    if ($Version2 -eq "unknown") { return "newer" }
    if ($Version1 -eq $Version2) { return "same" }
    
    $v1Parts = $Version1.Split('.') | ForEach-Object { [int]($_ -replace '[^0-9].*') }
    $v2Parts = $Version2.Split('.') | ForEach-Object { [int]($_ -replace '[^0-9].*') }
    
    for ($i = 0; $i -lt 3; $i++) {
        $v1Part = if ($i -lt $v1Parts.Length) { $v1Parts[$i] } else { 0 }
        $v2Part = if ($i -lt $v2Parts.Length) { $v2Parts[$i] } else { 0 }
        
        if ($v1Part -lt $v2Part) { return "older" }
        if ($v1Part -gt $v2Part) { return "newer" }
    }
    
    return "same"
}

# 업데이트 필요 여부 확인
function Test-UpdateNeeded {
    Write-Host "버전 정보를 확인하는 중..."
    
    try {
        $currentVersion = Get-CurrentVersion
        $latestVersion = Get-LatestVersion
        $comparison = Compare-Versions $currentVersion $latestVersion
        
        Write-Host ""
        Write-ColorOutput "═══════════════════════════════════════" -Color Blue
        Write-ColorOutput "        버전 정보                        " -Color Blue
        Write-ColorOutput "═══════════════════════════════════════" -Color Blue
        Write-ColorOutput "현재 버전: $currentVersion" -Color Yellow
        Write-ColorOutput "최신 버전: $latestVersion" -Color Yellow
        Write-Host ""
        
        switch ($comparison) {
            "older" {
                Write-ColorOutput "✨ 새로운 버전이 있습니다!" -Color Green
                return $true
            }
            "newer" {
                Write-ColorOutput "ℹ️  현재 버전이 최신보다 높습니다" -Color Blue
                if (-not $FORCE_UPDATE) {
                    Write-Host "강제 업데이트를 원하면 -Force 또는 `$env:CLAUDE_UPDATE_FORCE = 'true'를 설정하세요."
                    exit 0
                }
                Write-Host "강제 업데이트를 진행합니다."
                return $true
            }
            "same" {
                Write-ColorOutput "✅ 이미 최신 버전을 사용하고 있습니다" -Color Green
                if (-not $FORCE_UPDATE) {
                    exit 0
                }
                Write-Host "강제 업데이트를 진행합니다."
                return $true
            }
            default {
                Write-ColorOutput "❌ 버전 비교 중 오류가 발생했습니다" -Color Red
                exit 1
            }
        }
    } catch {
        Write-ColorOutput "Error: $_" -Color Red
        Write-Host "네트워크 연결을 확인하고 다시 시도해주세요."
        exit 1
    }
}

# 권한 문제 처리 함수
function Repair-Permissions {
    param(
        [string]$Path,
        [string]$Operation
    )
    
    Write-ColorOutput "경고: $Operation 중 권한 문제 발생: $Path" -Color Yellow
    Write-Host "권한 문제 복구를 시도하는 중..."
    
    try {
        # 소유권 및 권한 설정
        $acl = Get-Acl $Path
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            "FullControl",
            "ContainerInherit,ObjectInherit",
            "None",
            "Allow"
        )
        $acl.SetAccessRule($accessRule)
        Set-Acl -Path $Path -AclObject $acl
        
        Write-ColorOutput "✓ 권한 복구 성공" -Color Green
        return $true
    } catch {
        Write-ColorOutput "Error: 권한 복구 실패: $_" -Color Red
        Write-ColorOutput "수동 복구 방법:" -Color Yellow
        Write-Host "1. 관리자 권한으로 PowerShell 실행"
        Write-Host "2. takeown /F `"$Path`" /R /D Y"
        Write-Host "3. icacls `"$Path`" /grant `$env:USERNAME`:F /T"
        return $false
    }
}

# 강화된 백업 생성
function New-Backup {
    $installDir = "$env:USERPROFILE\.claude\hooks\claude-context"
    $backupBase = "$env:USERPROFILE\.claude\backups"
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $currentVersion = Get-CurrentVersion
    $backupDir = Join-Path $backupBase "claude-context-$currentVersion-$timestamp"
    
    Write-Host "기존 설치를 백업하는 중..."
    
    # 백업 디렉토리 생성 및 권한 설정
    if (-not (Test-Path $backupBase)) {
        try {
            New-Item -Path $backupBase -ItemType Directory -Force | Out-Null
        } catch {
            if (-not (Repair-Permissions -Path (Split-Path $backupBase -Parent) -Operation "backup directory creation")) {
                throw "Failed to create backup directory: $backupBase"
            }
            New-Item -Path $backupBase -ItemType Directory -Force | Out-Null
        }
    }
    
    try {
        Copy-Item -Path $installDir -Destination $backupDir -Recurse -Force
        Write-ColorOutput "✓ 백업 완료: $backupDir" -Color Green
        return $backupDir
    } catch {
        Write-ColorOutput "Error: 백업 생성 실패" -Color Red
        
        # 권한 문제 복구 시도
        if (Repair-Permissions -Path $installDir -Operation "backup creation") {
            try {
                Copy-Item -Path $installDir -Destination $backupDir -Recurse -Force
                Write-ColorOutput "✓ 권한 복구 후 백업 완료: $backupDir" -Color Green
                return $backupDir
            } catch {
                Write-ColorOutput "Error: 권한 복구 후에도 백업 실패" -Color Red
            }
        }
        
        throw "Backup creation failed"
    }
}

# 오래된 백업 정리
function Remove-OldBackups {
    $backupBase = "$env:USERPROFILE\.claude\backups"
    
    if (-not (Test-Path $backupBase)) {
        return
    }
    
    $backups = Get-ChildItem -Path $backupBase -Directory -Name | Where-Object { $_ -match "^claude-context-" } | Sort-Object
    
    if ($backups.Count -gt $BACKUP_KEEP) {
        $excess = $backups.Count - $BACKUP_KEEP
        $backupsToRemove = $backups | Select-Object -First $excess
        
        foreach ($backup in $backupsToRemove) {
            Remove-Item -Path (Join-Path $backupBase $backup) -Recurse -Force
        }
        
        Write-ColorOutput "✓ 오래된 백업 $excess개 정리 완료" -Color Green
    }
}

# 현재 설정 정보 가져오기
function Get-CurrentSettings {
    $installDir = "$env:USERPROFILE\.claude\hooks\claude-context"
    $configFile = Join-Path $installDir "config.ps1"
    $claudeConfig = "$env:USERPROFILE\.claude\settings.json"
    
    $settings = @{
        Mode = "basic"
        HookType = "UserPromptSubmit"
    }
    
    # config.ps1에서 모드 읽기
    if (Test-Path $configFile) {
        $configContent = Get-Content $configFile -Raw
        if ($configContent -match '\$CLAUDE_CONTEXT_MODE\s*=\s*["\']([^"\']+)["\']') {
            $settings.Mode = $Matches[1]
        }
    }
    
    # Claude 설정에서 훅 타입 확인
    if (Test-Path $claudeConfig) {
        try {
            $claudeSettings = Get-Content $claudeConfig -Raw | ConvertFrom-Json
            if ($claudeSettings.hooks.UserPromptSubmit) {
                $settings.HookType = "UserPromptSubmit"
            } elseif ($claudeSettings.hooks.PreToolUse) {
                $settings.HookType = "PreToolUse"
            }
        } catch {
            # JSON 파싱 오류 시 기본값 사용
        }
    }
    
    return $settings
}

# 업데이트 수행
function Start-Update {
    # 1. 백업 생성
    try {
        $backupDir = New-Backup
    } catch {
        Write-ColorOutput "Error: 백업 실패로 업데이트를 중단합니다" -Color Red
        exit 1
    }
    
    # 2. 현재 설정 백업
    $currentSettings = Get-CurrentSettings
    
    # 3. 보안 강화된 임시 디렉토리에 최신 소스 다운로드
    $tempDir = New-SecureTempDirectory
    
    try {
        Write-Host "최신 소스를 다운로드하는 중..."
        Set-Location $tempDir
        
        $gitUrl = "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
        
        # SSL 인증서 검증 활성화
        & git config --global http.sslVerify true
        
        & git clone --depth 1 --branch $GITHUB_BRANCH $gitUrl 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Git clone failed"
        }
        
        $repoPath = Join-Path $tempDir $GITHUB_REPO
        
        # Git 보안 검증 수행
        if (-not (Test-GitSecurity -RepoPath $repoPath)) {
            Remove-Item -Path $repoPath -Recurse -Force
            throw "Git security verification failed"
        }
        
        Write-ColorOutput "✓ 다운로드 및 보안 검증 완료" -Color Green
        
        # 4. 새 버전 설치
        Write-Host "새 버전을 설치하는 중..."
        Set-Location (Join-Path $tempDir $GITHUB_REPO)
        
        $installScript = "install\install.ps1"
        if (Test-Path $installScript) {
            $installArgs = @(
                "-Mode", $currentSettings.Mode
                "-HookType", $currentSettings.HookType
                "-Silent"
            )
            
            & powershell.exe -ExecutionPolicy RemoteSigned -File $installScript @installArgs
            
            if ($LASTEXITCODE -ne 0) {
                throw "Installation failed"
            }
            
            Write-ColorOutput "✓ 설치 완료" -Color Green
        } else {
            throw "Installation script not found"
        }
        
    } catch {
        Write-ColorOutput "Error: 업데이트 중 오류가 발생했습니다" -Color Red
        Write-Host "안전한 롤백을 시작합니다..."
        
        # 강화된 롤백 메커니즘
        $installDir = "$env:USERPROFILE\.claude\hooks\claude-context"
        $tempRestoreDir = "$installDir.restore.$PID"
        
        try {
            # 1단계: 임시 위치에 복원
            Copy-Item -Path $backupDir -Destination $tempRestoreDir -Recurse -Force
            Write-Host "✓ 임시 복원 완료"
            
            # 2단계: 기존 설치 제거
            if (Test-Path $installDir) {
                Remove-Item -Path $installDir -Recurse -Force
            }
            Write-Host "✓ 기존 설치 제거 완료"
            
            # 3단계: 최종 위치로 이동
            Move-Item -Path $tempRestoreDir -Destination $installDir
            Write-ColorOutput "✓ 안전한 복원 완료" -Color Green
            
        } catch {
            Write-ColorOutput "Error: 안전한 복원에 실패했습니다" -Color Red
            Write-Host "빠른 복원을 시도합니다..."
            
            try {
                # 임시 파일 정리
                if (Test-Path $tempRestoreDir) {
                    Remove-Item -Path $tempRestoreDir -Recurse -Force
                }
                
                # 빠른 복원
                if (Test-Path $installDir) {
                    Remove-Item -Path $installDir -Recurse -Force
                }
                Copy-Item -Path $backupDir -Destination $installDir -Recurse -Force
                Write-ColorOutput "✓ 빠른 복원 완룼" -Color Yellow
                
            } catch {
                Write-ColorOutput "경고: 모든 복원 시도가 실패했습니다!" -Color Red
                Write-ColorOutput "수동 복원 방법:" -Color Yellow
                Write-Host "1. 백업 디렉토리: $backupDir"
                Write-Host "2. 설치 디렉토리: $installDir"
                Write-Host "3. 명령어: Copy-Item -Path `"$backupDir`" -Destination `"$installDir`" -Recurse -Force"
            }
        }
        
        exit 1
    } finally {
        # 임시 디렉토리 정리
        Set-Location $env:USERPROFILE
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
    }
    
    # 5. 백업 정리
    Remove-OldBackups
}

# 메인 실행
function Main {
    Write-Header
    
    # 입력 값 검증
    Test-InputValidation -BackupKeep $BACKUP_KEEP
    
    # PowerShell 보안 설정
    Set-SecurePowerShellPolicy
    
    # 의존성 확인
    Test-Dependencies
    
    # 설치 확인
    Test-Installation
    
    # 업데이트 필요 여부 확인
    $updateNeeded = Test-UpdateNeeded
    
    if (-not $updateNeeded) {
        return
    }
    
    # 사용자 확인 (강제 업데이트가 아닌 경우)
    if (-not $FORCE_UPDATE) {
        Write-Host ""
        $confirm = Read-Host "업데이트를 진행하시겠습니까? [y/N]"
        if ($confirm -notmatch "^[Yy]$") {
            Write-Host "업데이트가 취소되었습니다."
            return
        }
    }
    
    # 업데이트 실행
    Write-Host ""
    Write-Host "업데이트를 시작합니다..."
    Start-Update
    
    # 완료 메시지
    Write-Host ""
    Write-ColorOutput "🎉 Claude Context가 성공적으로 업데이트되었습니다!" -Color Green
    Write-Host ""
    
    $newVersion = Get-CurrentVersion
    Write-ColorOutput "업데이트된 버전: $newVersion" -Color Blue
    Write-Host ""
    Write-ColorOutput "다음 단계:" -Color Blue
    Write-Host "1. Claude Code를 재시작하세요"
    Write-Host "2. 설정이 올바르게 적용되었는지 확인하세요"
    Write-Host ""
    Write-ColorOutput "백업 위치: $env:USERPROFILE\.claude\backups\" -Color Blue
    Write-ColorOutput "롤백 방법: 백업 디렉토리의 내용을 $env:USERPROFILE\.claude\hooks\claude-context\로 복사" -Color Blue
    Write-Host ""
    Write-Host "자세한 사용법: https://github.com/$GITHUB_USER/$GITHUB_REPO"
    Write-Host "문제 발생 시: https://github.com/$GITHUB_USER/$GITHUB_REPO/issues"
}

# 스크립트 실행
Main