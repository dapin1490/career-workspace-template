<#
.SYNOPSIS
    이 PC에 입사 지원 제출 증빙 검사를 설치한다(또는 제거한다). PC마다 한 번 실행.

.DESCRIPTION
    1. Git 훅 연결: 이 레포의 .githooks/ 폴더를 Git 훅 폴더로 지정한다(git config core.hooksPath).
    2. Windows 작업 스케줄러 등록: 매일 정해진 시각과 로그인할 때 검사 스크립트를 실행해,
       증빙이 없는 공고가 있으면 팝업을 띄운다.

    사용법 (레포 폴더에서 PowerShell로):
      powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1            # 설치
      powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1 -Uninstall # 제거
    레포 폴더를 옮겼다면 설치를 다시 실행한다(작업 스케줄러에 절대 경로가 저장되기 때문).
#>
param(
    [switch]$Uninstall,
    # 알림 시각 (24시간제, "HH:mm")
    [string[]]$Times = @('09:00', '13:00', '18:00', '21:00', '23:00')
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Checker = Join-Path $RepoRoot 'scripts\check-submission-proof.ps1'
$TaskName = 'career-workspace-submission-proof-check'

if ($Uninstall) {
    git -C $RepoRoot config --unset core.hooksPath 2>$null
    Write-Output '[1/2] Git 훅 연결 해제'
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Output "[2/2] 작업 스케줄러에서 '$TaskName' 삭제"
    } else {
        Write-Output '[2/2] 등록된 작업 없음'
    }
    exit 0
}

# 1. Git 훅
git -C $RepoRoot config core.hooksPath .githooks
Write-Output "[1/2] Git 훅 연결: core.hooksPath = $(git -C $RepoRoot config --get core.hooksPath)"

# 2. 작업 스케줄러
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Checker`" -Mode scheduler"
$triggers = @()
foreach ($t in $Times) { $triggers += New-ScheduledTaskTrigger -Daily -At $t }
$triggers += New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings `
    -Description '입사 지원 최종 제출 증빙이 없는 공고가 있으면 팝업으로 알림 (scripts/check-submission-proof.ps1)' | Out-Null
Write-Output "[2/2] 작업 스케줄러 등록: '$TaskName' (매일 $($Times -join ', '), 로그인할 때)"
Write-Output ''
Write-Output '확인: 작업 스케줄러 앱 > 작업 스케줄러 라이브러리에서 위 이름을 찾을 수 있습니다.'
Write-Output "지금 한 번 실행해 보기: Start-ScheduledTask -TaskName '$TaskName'"
