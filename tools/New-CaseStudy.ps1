<#
.SYNOPSIS
    프로젝트 폴더 하나를 받아 포트폴리오 케이스 스터디를 만든다.

.DESCRIPTION
    이미 있는 케이스 스터디 하나를 골라 그대로 복사한다.
    페이지 구조도, 폰트·아이콘 링크도, 애널리틱스 스크립트도 참고한 쪽과 같아진다.
    바꾸는 건 신원 정보뿐이다 - 제목, 상단바 경로, 히어로 문구.
    본문은 참고한 프로젝트의 글이 그대로 들어 있으니 열어서 새로 쓰면 된다.

    - <포트폴리오>/<슬러그>/index.html  참고 페이지 복사 + 제목 교체
    - <포트폴리오>/<슬러그>/style.css   참고 페이지가 쓰는 CSS 그대로
    - <포트폴리오>/index.html           프로젝트 카드 삽입 + 번호 재정렬

    Windows 기본 PowerShell 5.1 에서 돌아간다. 설치할 것 없음.
    git 이 있으면 기간과 저장소 주소를 자동으로 읽고, 없으면 -Period / -Repo 로 직접 준다.

.EXAMPLE
    .\New-CaseStudy.ps1 -Project C:\work\my-api

.EXAMPLE
    .\New-CaseStudy.ps1 -Project C:\work\my-api -Reference harness-refactor -Title "주문 정산 API"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Project,                 # 케이스 스터디로 만들 프로젝트 폴더

    [string] $Reference,               # 본떠올 케이스 스터디 폴더명 (기본: 가장 최근에 손댄 것)
    [string] $Slug,                    # 포트폴리오 안에 만들 폴더명 (기본: 프로젝트 폴더명)
    [string] $Title,                   # 페이지 제목 (기본: 슬러그)
    [string] $Summary,                 # 한 줄 소개 (기본: README 첫 문단)
    [string] $Period,                  # "2026.08 — 2026.09" (기본: git 커밋 날짜)
    [string] $Repo,                    # GitHub 주소 (기본: git remote origin)
    [string[]] $Tags,                  # 태그 목록 (기본: 프로젝트 파일에서 추정)
    [string] $PortfolioDir,            # 포트폴리오 루트 (기본: 이 스크립트의 상위 폴더)
    [switch] $Force,                   # 이미 있는 폴더 덮어쓰기
    [switch] $DryRun                   # 파일을 쓰지 않고 무엇을 할지만 출력
)

$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────── 공통 도우미

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-TextFile([string] $Path) {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile([string] $Path, [string] $Text, [string] $Newline) {
    # HTML 은 CRLF, CSS 는 LF. 기존 파일들과 줄바꿈을 맞춘다.
    $normalized = $Text.Replace("`r`n", "`n")
    if ($Newline -eq 'CRLF') { $normalized = $normalized.Replace("`n", "`r`n") }
    if ($DryRun) {
        Write-Host ("  [dry-run] " + $Path + " (" + $normalized.Length + " chars)") -ForegroundColor DarkGray
        return
    }
    [System.IO.File]::WriteAllText($Path, $normalized, $Utf8NoBom)
}

function Test-Command([string] $Name) {
    try { $null = Get-Command $Name -ErrorAction Stop; return $true } catch { return $false }
}

function Invoke-Git([string] $RepoPath, [string[]] $GitArgs) {
    if (-not (Test-Command 'git')) { return $null }
    try {
        $out = & git -C $RepoPath @GitArgs 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($out | Out-String).Trim()
    } catch { return $null }
}

function Get-HtmlEscaped([string] $Text) {
    if ($null -eq $Text) { return '' }
    return $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

# ─────────────────────────────────────────────────────────── 입력값 확정하기

if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
    throw "프로젝트 폴더를 찾을 수 없습니다: $Project"
}
$projectPath = (Resolve-Path -LiteralPath $Project).Path

if ([string]::IsNullOrWhiteSpace($PortfolioDir)) {
    $PortfolioDir = Split-Path -Parent $PSScriptRoot   # <포트폴리오>/tools/ 안에 있다고 가정
}
if (-not (Test-Path -LiteralPath $PortfolioDir -PathType Container)) {
    throw "포트폴리오 폴더를 찾을 수 없습니다: $PortfolioDir"
}
$portfolioPath = (Resolve-Path -LiteralPath $PortfolioDir).Path
$rootIndex = Join-Path $portfolioPath 'index.html'
if (-not (Test-Path -LiteralPath $rootIndex)) {
    throw "포트폴리오 루트에 index.html 이 없습니다: $rootIndex"
}

if ([string]::IsNullOrWhiteSpace($Slug))  { $Slug = Split-Path -Leaf $projectPath }
if ([string]::IsNullOrWhiteSpace($Title)) { $Title = $Slug }

# 본떠올 케이스 스터디 고르기 — 지정이 없으면 가장 최근에 손댄 페이지
$refDir = $null
if (-not [string]::IsNullOrWhiteSpace($Reference)) {
    $candidate = Join-Path $portfolioPath $Reference
    if (-not (Test-Path -LiteralPath (Join-Path $candidate 'index.html'))) {
        throw "참고할 케이스 스터디를 찾을 수 없습니다: $candidate\index.html"
    }
    $refDir = Get-Item -LiteralPath $candidate
} else {
    $refDir = Get-ChildItem -LiteralPath $portfolioPath -Directory |
        Where-Object { $_.Name -ne $Slug -and $_.Name -ne 'tools' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'index.html')) } |
        Sort-Object { (Get-Item -LiteralPath (Join-Path $_.FullName 'index.html')).LastWriteTime } -Descending |
        Select-Object -First 1
    if ($null -eq $refDir) {
        throw '본떠올 케이스 스터디가 하나도 없습니다. -Reference 로 지정하거나 페이지를 하나 먼저 만드세요.'
    }
}
$refIndex = Join-Path $refDir.FullName 'index.html'

# 기간 — git 첫 커밋 ~ 마지막 커밋
if ([string]::IsNullOrWhiteSpace($Period)) {
    $first = Invoke-Git $projectPath @('log', '--reverse', '--format=%ad', '--date=format:%Y.%m')
    $last  = Invoke-Git $projectPath @('log', '-1', '--format=%ad', '--date=format:%Y.%m')
    if ($first -and $last) {
        $firstLine = ($first -split "`n")[0].Trim()
        $Period = "$firstLine — $last"
    } else {
        $Period = 'TODO — TODO'
        Write-Warning 'git 기록을 못 읽었습니다. -Period "2026.08 — 2026.09" 형식으로 직접 주세요.'
    }
}

# 저장소 주소 — git remote origin
if ([string]::IsNullOrWhiteSpace($Repo)) {
    $origin = Invoke-Git $projectPath @('remote', 'get-url', 'origin')
    if ($origin) {
        $Repo = $origin -replace '^git@github\.com:', 'https://github.com/'
        $Repo = $Repo -replace '\.git$', ''
    }
}

# 한 줄 소개 — README 첫 문단
if ([string]::IsNullOrWhiteSpace($Summary)) {
    $readme = Get-ChildItem -LiteralPath $projectPath -Filter 'README*' -File -ErrorAction SilentlyContinue |
              Select-Object -First 1
    if ($readme) {
        $lines = Get-Content -LiteralPath $readme.FullName -Encoding UTF8
        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -and -not $t.StartsWith('#') -and -not $t.StartsWith('!') -and -not $t.StartsWith('[')) {
                $Summary = ($t -replace '\*\*', '' -replace '`', '')
                break
            }
        }
    }
}
if ([string]::IsNullOrWhiteSpace($Summary)) { $Summary = 'TODO: 이 프로젝트가 무엇인지 두세 문장으로.' }

# 태그 — 프로젝트 안의 파일로 스택 추정
if (-not $Tags -or $Tags.Count -eq 0) {
    $found = New-Object System.Collections.ArrayList
    function Add-Tag([string] $Name) {
        if (-not $found.Contains($Name)) { [void]$found.Add($Name) }
    }
    $has = { param($rel) Test-Path -LiteralPath (Join-Path $projectPath $rel) }

    if (& $has 'composer.json') {
        Add-Tag 'PHP'
        $composer = Read-TextFile (Join-Path $projectPath 'composer.json')
        if ($composer -match 'laravel/framework') { Add-Tag 'Laravel' }
    }
    if ((& $has 'pyproject.toml') -or (& $has 'requirements.txt')) {
        Add-Tag 'Python'
        $pyText = ''
        foreach ($f in @('pyproject.toml', 'requirements.txt')) {
            $p = Join-Path $projectPath $f
            if (Test-Path -LiteralPath $p) { $pyText += (Read-TextFile $p) }
        }
        if ($pyText -match '(?i)fastapi')    { Add-Tag 'FastAPI' }
        if ($pyText -match '(?i)django')     { Add-Tag 'Django' }
        if ($pyText -match '(?i)celery')     { Add-Tag 'Celery' }
        if ($pyText -match '(?i)sqlalchemy') { Add-Tag 'SQLAlchemy' }
        if ($pyText -match '(?i)langchain')  { Add-Tag 'LangChain' }
        if ($pyText -match '(?i)playwright') { Add-Tag 'Playwright' }
    }
    if (& $has 'package.json') {
        $pkg = Read-TextFile (Join-Path $projectPath 'package.json')
        if ($pkg -match '(?i)"typescript"') { Add-Tag 'TypeScript' }
        if ($pkg -match '(?i)"next"')       { Add-Tag 'Next.js' }
        if ($pkg -match '(?i)"react"')      { Add-Tag 'React' }
    }
    if ((& $has 'Dockerfile') -or (& $has 'docker-compose.yml') -or (& $has 'compose.yml')) { Add-Tag 'Docker' }
    if (& $has '.github/workflows') { Add-Tag 'GitHub Actions' }
    if (& $has '.claude')           { Add-Tag 'Claude Code' }

    if ($found.Count -eq 0) { [void]$found.Add('TODO') }
    $Tags = $found.ToArray()
}

# 케이스 스터디 URL — 루트 index.html 에 이미 쓰인 주소 형식을 따라간다
$rootHtml = Read-TextFile $rootIndex
$baseUrl = 'https://qwerty1347.github.io/portfolio'
$m = [regex]::Match($rootHtml, 'href="(https?://[^"]+/portfolio)/[^"]*/"')
if ($m.Success) { $baseUrl = $m.Groups[1].Value }
$caseUrl = "$baseUrl/$Slug/"

# ───────────────────────────────────────────────── 케이스 스터디 폴더 만들기

$caseDir = Join-Path $portfolioPath $Slug
if ((Test-Path -LiteralPath $caseDir) -and -not $Force) {
    throw "이미 있는 폴더입니다: $caseDir  (덮어쓰려면 -Force)"
}
if (-not $DryRun) { $null = New-Item -ItemType Directory -Path $caseDir -Force }

# CSS — 참고 페이지가 쓰는 파일을 이름 그대로 복사한다.
#       style.css 인 페이지도 있고 styles.css 인 페이지도 있어서, 이름을 바꾸면 링크가 깨진다.
$cssFiles = Get-ChildItem -LiteralPath $refDir.FullName -Filter '*.css' -File
if ($cssFiles.Count -eq 0) {
    Write-Warning ("참고 페이지에 CSS 가 없습니다: " + $refDir.Name)
}
foreach ($css in $cssFiles) {
    $cssTarget = Join-Path $caseDir $css.Name
    if ($DryRun) {
        Write-Host ("  [dry-run] " + $cssTarget + "  <- " + $css.FullName) -ForegroundColor DarkGray
    } else {
        Copy-Item -LiteralPath $css.FullName -Destination $cssTarget -Force
    }
}

# ────────────────────────────────────── 참고 페이지 복사 + 신원 정보만 교체

$page = Read-TextFile $refIndex

$titleEsc = Get-HtmlEscaped $Title
$slugEsc  = Get-HtmlEscaped $Slug
$sumEsc   = Get-HtmlEscaped $Summary

# <title>
$page = [regex]::Replace($page, '(?s)(<title>).*?(</title>)', ('${1}' + $titleEsc + '${2}'))

# 상단바 경로 — ~/portfolio/<여기>
$page = [regex]::Replace($page, '(?s)(<span class="brand-cur">).*?(</span>)', ('${1}' + $slugEsc + '${2}'))

# 히어로 제목 — 커서 span 앞의 글자만
$page = [regex]::Replace($page,
    '(?s)(<h1 class="hero-title">\s*).*?(\s*<span class="cursor">)',
    ('${1}' + $titleEsc + '${2}'))

# 히어로 요약
$page = [regex]::Replace($page,
    '(?s)(<p class="hero-summary">\s*).*?(\s*</p>)',
    ('${1}' + $sumEsc + '${2}'))

$pageTarget = Join-Path $caseDir 'index.html'
if ((Test-Path -LiteralPath $pageTarget) -and -not $DryRun) {
    # 이미 써둔 글을 날리지 않도록 백업부터
    $backup = $pageTarget + '.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
    Copy-Item -LiteralPath $pageTarget -Destination $backup -Force
    Write-Host ("  기존 페이지를 백업했습니다: " + (Split-Path -Leaf $backup)) -ForegroundColor Yellow
}
Write-TextFile $pageTarget $page 'CRLF'

# ────────────────────────────────────────── 루트 index.html 에 카드 넣기

$tagRow = ($Tags | ForEach-Object { '                            <span class="project-tag">' + (Get-HtmlEscaped $_) + '</span>' }) -join "`n"

$linkBlock = @"
                    <div class="project-actions">
                        <a class="project-link primary" href="$caseUrl" target="_blank">
                            <i class="fas fa-arrow-up-right-from-square"></i>
                            <span>Case Study</span>
                            <i class="fas fa-chevron-right arrow"></i>
                        </a>
"@
if (-not [string]::IsNullOrWhiteSpace($Repo)) {
    $linkBlock += @"

                        <a class="project-link" href="$Repo" target="_blank">
                            <i class="fab fa-github"></i>
                            <span>GitHub</span>
                            <i class="fas fa-chevron-right arrow"></i>
                        </a>
"@
}
$linkBlock += "`n                    </div>"

$card = @"
                <article class="project">
                    <div class="project-num">000</div>
                    <div class="project-body">
                        <h3>$titleEsc</h3>
                        <div class="project-meta">
                            <span class="project-meta-item"><span class="meta-key">기간</span> $Period</span>
                        </div>
                        <p>
                            $sumEsc
                        </p>
                        <div class="project-tags">
$tagRow
                        </div>
                    </div>
$linkBlock
                </article>

"@

$rootText = $rootHtml.Replace("`r`n", "`n")

if ($rootText.Contains($caseUrl)) {
    Write-Host "  루트 index.html 에 이미 이 프로젝트 카드가 있어서 건너뜁니다." -ForegroundColor Yellow
} else {
    $anchor = '                <article class="project">'
    $starts = New-Object System.Collections.ArrayList
    $pos = $rootText.IndexOf($anchor)
    while ($pos -ge 0) {
        [void]$starts.Add($pos)
        $pos = $rootText.IndexOf($anchor, $pos + 1)
    }

    # 새 카드의 종료 연월과 비교해서 최신순 자리 찾기
    $newEnd = ''
    $pm = [regex]::Match($Period, '([0-9]{4}\.[0-9]{2})\s*$')
    if ($pm.Success) { $newEnd = $pm.Groups[1].Value }

    $insertAt = -1
    foreach ($s in $starts) {
        $chunkEnd = $rootText.IndexOf('</article>', $s)
        $chunk = $rootText.Substring($s, $chunkEnd - $s)
        $em = [regex]::Match($chunk, '기간</span>[^<]*?([0-9]{4}\.[0-9]{2})\s*<')
        if ($em.Success -and $newEnd -and ([string]::Compare($newEnd, $em.Groups[1].Value) -gt 0)) {
            $insertAt = $s
            break
        }
    }
    if ($insertAt -lt 0) {
        # 제일 오래된 프로젝트 → 마지막 카드 뒤에
        $lastEnd = $rootText.LastIndexOf('</article>')
        if ($lastEnd -lt 0) { throw '루트 index.html 에서 프로젝트 카드를 찾지 못했습니다.' }
        $insertAt = $lastEnd + '</article>'.Length + 2
        $card = "`n" + $card.TrimEnd() + "`n"
    }

    $rootText = $rootText.Substring(0, $insertAt) + $card + $rootText.Substring($insertAt)

    # 번호 재정렬
    $script:num = 0
    $rootText = [regex]::Replace($rootText, '<div class="project-num">\d+</div>', {
        param($match)
        $script:num++
        return ('<div class="project-num">{0:D3}</div>' -f $script:num)
    })

    Write-TextFile $rootIndex $rootText 'CRLF'
}

# ─────────────────────────────────────────────────────────────── 결과 출력

Write-Host ''
if ($DryRun) {
    Write-Host '[dry-run] 아래 내용으로 만들 예정입니다. 파일은 쓰지 않았습니다.' -ForegroundColor Yellow
} else {
    Write-Host '만들었습니다.' -ForegroundColor Green
}
Write-Host ("  폴더    : " + $caseDir)
Write-Host ("  본뜬 곳 : " + $refDir.Name)
Write-Host ("  제목    : " + $Title)
Write-Host ("  기간    : " + $Period)
Write-Host ("  저장소  : " + $(if ($Repo) { $Repo } else { '(없음)' }))
Write-Host ("  태그    : " + ($Tags -join ', '))
Write-Host ("  링크    : " + $caseUrl)

if ($DryRun) { return }

Write-Host ''
Write-Host ("본문은 아직 " + $refDir.Name + " 의 글입니다. 열어서 새로 쓰세요.") -ForegroundColor Cyan
Write-Host '  구조와 CSS 는 그대로 두고 섹션 01~05 의 내용만 바꾸면 됩니다.'
Write-Host ''
Write-Host '  기존 페이지들과 톤을 맞추려면'
Write-Host '   - 규칙을 선언하지 말고, 겪은 일을 먼저 쓴다'
Write-Host '   - 항목마다 형식을 똑같이 맞추지 않는다 (문단 수, 태그 개수)'
Write-Host '   - 굵은 글씨는 페이지 전체에서 한두 곳만'
Write-Host '   - 잘 안 된 것도 적는다'
