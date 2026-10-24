<#
.SYNOPSIS
    입사 지원 최종 제출 증빙 검사 (AGENTS.md 행동 규칙 8번)

.DESCRIPTION
    JD/ 바로 아래의 진행 중인 공고(Submitted, DEPRECATED 제외)를 훑어,
    최종 제출 증빙이 없는 공고를 찾아 알린다.

    검사 대상
      1. 메인 문서 프론트매터에 `제출 대기: true`가 있는 공고
      2. `단계`가 `지원 완료`인데 아직 JD/ 바로 아래에 있는 공고
    제외
      - 프론트매터 `증빙 면제:`에 사유가 적힌 공고
      - 공고 폴더의 submitted/ 안에 이름에 '제출 완료 증빙'이 들어간 파일이 있는 공고

    이 파일 하나를 여러 경로에서 호출한다.
      -Mode claude     : Claude Code 훅(SessionStart, UserPromptSubmit). JSON 출력
      -Mode git        : Git 훅(post-commit). 콘솔 경고
      -Mode scheduler  : Windows 작업 스케줄러. 팝업 창
      -Mode manual     : 사람이나 다른 에이전트가 직접 실행. 콘솔 출력 (기본값)

    문제가 없으면 claude, git, scheduler 모드에서는 아무것도 출력하지 않는다.
    어떤 모드에서도 작업을 막지 않는다(항상 종료 코드 0, manual 모드만 문제가 있으면 1).
#>
param(
    [ValidateSet('claude', 'git', 'scheduler', 'manual')]
    [string]$Mode = 'manual',
    # 테스트용: scheduler 모드에서 팝업 대신 콘솔에 출력
    [switch]$NoPopup
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$JdRoot = Join-Path $RepoRoot 'JD'
$Today = (Get-Date).Date
$ProofPattern = '*제출 완료 증빙*'

function Read-Frontmatter([string]$Path) {
    $lines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
    $fm = @{ '단계' = @() }
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') { return $null }
    $currentKey = $null
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line.Trim() -eq '---') { return $fm }
        if ($line -match '^\s+-\s*(.*)$' -and $currentKey) {
            if ($currentKey -eq '단계') { $fm['단계'] += $Matches[1].Trim() }
            continue
        }
        if ($line -match '^([^:\s][^:]*):\s*(.*)$') {
            $currentKey = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($currentKey -ne '단계') { $fm[$currentKey] = $value }
        }
    }
    return $null
}

function Get-Deadline([string]$Value) {
    if ($Value -match '(\d{4})\D+(\d{1,2})\D+(\d{1,2})') {
        try { return (Get-Date -Year $Matches[1] -Month $Matches[2] -Day $Matches[3]).Date } catch { }
    }
    return $null
}

function Get-MainDoc([IO.DirectoryInfo]$Dir) {
    $same = Join-Path $Dir.FullName ($Dir.Name + '.md')
    if (Test-Path -LiteralPath $same) { return $same }
    foreach ($md in Get-ChildItem -LiteralPath $Dir.FullName -Filter '*.md' -File) {
        $fm = Read-Frontmatter $md.FullName
        if ($fm -and $fm.ContainsKey('마감일')) { return $md.FullName }
    }
    return $null
}

# 검사할 공고 목록: (이름, 메인 문서 경로, 공고 폴더 경로 또는 $null)
$postings = @()
foreach ($dir in Get-ChildItem -LiteralPath $JdRoot -Directory) {
    if ($dir.Name -in @('Submitted', 'DEPRECATED')) { continue }
    $main = Get-MainDoc $dir
    if ($main) { $postings += [pscustomobject]@{ Name = $dir.Name; Doc = $main; Folder = $dir.FullName } }
}
foreach ($file in Get-ChildItem -LiteralPath $JdRoot -Filter '*.md' -File) {
    if ($file.Name -like 'template*' -or $file.Name -eq 'README.md') { continue }
    $postings += [pscustomobject]@{ Name = $file.BaseName; Doc = $file.FullName; Folder = $null }
}

$issues = @()
foreach ($p in $postings) {
    $fm = Read-Frontmatter $p.Doc
    if (-not $fm -or -not $fm.ContainsKey('마감일')) { continue }

    $waiting = ($fm['제출 대기'] -eq 'true')
    $markedDone = ($fm['단계'] -contains '지원 완료')
    if (-not ($waiting -or $markedDone)) { continue }
    if ($fm['증빙 면제']) { continue }

    $hasProof = $false
    if ($p.Folder) {
        $sub = Join-Path $p.Folder 'submitted'
        if (Test-Path -LiteralPath $sub) {
            $hasProof = [bool](Get-ChildItem -LiteralPath $sub -Filter $ProofPattern -File)
        }
    }
    if ($hasProof) { continue }

    $deadline = Get-Deadline $fm['마감일']
    $days = if ($deadline) { ($deadline - $Today).Days } else { $null }
    $when = if ($null -eq $days) { '마감일 미상' }
            elseif ($days -lt 0) { "마감일 지남($($fm['마감일']))" }
            elseif ($days -eq 0) { '오늘 마감' }
            elseif ($days -eq 1) { '내일 마감' }
            else { "D-$days" }

    $reason = if ($markedDone -and -not $waiting) { '단계가 지원 완료인데 증빙이 없음' } else { '제출 대기 중, 증빙 없음' }
    $where = if ($p.Folder) { "JD/$($p.Name)/submitted/" } else { "공고를 폴더로 승격한 뒤 submitted/" }

    $issues += [pscustomobject]@{
        Days   = if ($null -eq $days) { 9999 } else { $days }
        Line   = "[$when] $($p.Name): $reason. 저장 위치: $where"
        Urgent = ($null -ne $days -and $days -le 1)
    }
}

$issues = @($issues | Sort-Object Days)

if ($issues.Count -eq 0) {
    if ($Mode -eq 'manual') { Write-Output '제출 증빙 검사: 문제 없음' }
    exit 0
}

$urgent = @($issues | Where-Object Urgent).Count -gt 0
$header = if ($urgent) { '[제출 증빙 필요, 마감 임박] 최종 제출을 누르고 지원 완료 화면이나 확인 이메일을 캡처하세요.' }
          else { '[제출 증빙 필요] 최종 제출을 누르고 지원 완료 화면이나 확인 이메일을 캡처하세요.' }
$body = ($issues | ForEach-Object { '- ' + $_.Line }) -join "`n"
$footer = "캡처 파일 이름에 '제출 완료 증빙'을 넣어 저장하세요. 저장본이나 미리보기 PDF는 증빙이 아닙니다."
$text = "$header`n$body`n$footer"

switch ($Mode) {
    'claude' {
        $hookEvent = 'UserPromptSubmit'
        try {
            $raw = [Console]::In.ReadToEnd()
            if ($raw) { $hookEvent = ($raw | ConvertFrom-Json).hook_event_name }
        } catch { }
        $context = "$text`n(AGENTS.md 행동 규칙 8번: 증빙을 확인할 때까지 응답 끝에 증빙을 요구하고, 지원 완료 처리와 Submitted 이동을 하지 말 것)"
        $out = @{
            systemMessage      = $text
            hookSpecificOutput = @{ hookEventName = $hookEvent; additionalContext = $context }
        }
        Write-Output ($out | ConvertTo-Json -Depth 4 -Compress)
    }
    'git' {
        [Console]::Error.WriteLine("`n$text`n")
    }
    'scheduler' {
        if ($NoPopup) { Write-Output $text; break }
        Add-Type -AssemblyName System.Windows.Forms
        $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false }
        [void][System.Windows.Forms.MessageBox]::Show($owner, $text, '입사 지원 제출 증빙 확인', 'OK', 'Warning')
        $owner.Dispose()
    }
    'manual' {
        Write-Output $text
        exit 1
    }
}
exit 0
