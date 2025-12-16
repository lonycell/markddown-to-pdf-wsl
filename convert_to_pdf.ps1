# 마크다운 파일과 Mermaid 다이어그램을 PDF로 변환하는 PowerShell 스크립트

# 명령줄 인자 파싱
$inputDir = "doc"
$outputDir = $null
$useCustomInput = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "-in" {
            $inputDir = $args[$i + 1]
            $useCustomInput = $true
            $i++
        }
        "-o" {
            $outputDir = $args[$i + 1]
            $i++
        }
        default {
            # 기존 방식 호환성: 첫 번째 인자가 출력 폴더로 간주
            if ($null -eq $outputDir) {
                $outputDir = $args[$i]
            }
        }
    }
}

# 출력 폴더 설정
if ($null -eq $outputDir) {
    # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
    $outputDir = "output_$(Get-Date -Format 'yyyyMMdd_HH-mm')"
}

# 출력 폴더 생성
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "마크다운 → PDF 변환 도구" -ForegroundColor Cyan
if ($useCustomInput) {
    Write-Host "입력 폴더: $inputDir" -ForegroundColor Cyan
}
Write-Host "출력 폴더: $outputDir" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 의존성 확인
function Test-Dependency {
    param([string]$Command, [string]$Name)
    
    try {
        $null = Get-Command $Command -ErrorAction Stop
        Write-Host "✓ $Name 설치 확인됨" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "✗ $Name 설치 필요" -ForegroundColor Red
        return $false
    }
}

$pandocInstalled = Test-Dependency "pandoc" "Pandoc"
$mmdcInstalled = Test-Dependency "mmdc" "Mermaid CLI"

if (-not $pandocInstalled -or -not $mmdcInstalled) {
    Write-Host "`n필요한 도구를 설치해주세요." -ForegroundColor Yellow
    Write-Host "설치 방법은 doc/변환_가이드.md를 참고하세요." -ForegroundColor Yellow
    exit 1
}

# 변환할 마크다운 파일 목록
if ($useCustomInput) {
    # 사용자 지정 입력 폴더에서 모든 .md 파일 찾기
    if (-not (Test-Path $inputDir)) {
        Write-Host "✗ 입력 폴더를 찾을 수 없습니다: $inputDir" -ForegroundColor Red
        exit 1
    }
    $mdFiles = Get-ChildItem -Path $inputDir -Filter "*.md" -Recurse -File | Sort-Object FullName | ForEach-Object { $_.FullName }
    if ($mdFiles.Count -eq 0) {
        Write-Host "⚠ 입력 폴더에 .md 파일이 없습니다: $inputDir" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ $($mdFiles.Count)개의 마크다운 파일을 찾았습니다" -ForegroundColor Green
} else {
    # 기본 파일 목록 (하위 호환성)
    $mdFiles = @(
        "doc\서비스_기획서.md",
        "doc\화면_기능_정의서.md",
        "doc\화면_흐름도.md"
    )
}

# 이미지 저장 디렉토리 (출력 폴더 내부)
$imageDir = Join-Path $outputDir "images"
if (-not (Test-Path $imageDir)) {
    New-Item -ItemType Directory -Path $imageDir | Out-Null
}

foreach ($mdFile in $mdFiles) {
    if (-not (Test-Path $mdFile)) {
        Write-Host "`n✗ 파일을 찾을 수 없습니다: $mdFile" -ForegroundColor Red
        continue
    }
    
    Write-Host "`n처리 중: $mdFile" -ForegroundColor Yellow
    
    # Mermaid 다이어그램 추출 및 변환
    $content = Get-Content $mdFile -Raw -Encoding UTF8
    $mermaidPattern = '(?s)```mermaid\s*\n(.*?)```'
    $matches = [regex]::Matches($content, $mermaidPattern)
    
    $imagePaths = @()
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $diagramCode = $matches[$i].Groups[1].Value
        
        # 임시 mermaid 파일 생성
        $tempMmd = "$imageDir\temp_$i.mmd"
        $diagramCode | Out-File -FilePath $tempMmd -Encoding UTF8
        
        # 이미지로 변환
        $outputImage = "$imageDir\diagram_$i.png"
        $mmdcCmd = "mmdc -i `"$tempMmd`" -o `"$outputImage`" -b transparent"
        
        try {
            Invoke-Expression $mmdcCmd
            if (Test-Path $outputImage) {
                $imagePaths += @{
                    Start = $matches[$i].Index
                    End = $matches[$i].Index + $matches[$i].Length
                    Path = $outputImage
                }
                Write-Host "  ✓ 다이어그램 $($i+1) 변환 완료" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ✗ 다이어그램 $($i+1) 변환 실패" -ForegroundColor Red
        } finally {
            if (Test-Path $tempMmd) {
                Remove-Item $tempMmd
            }
        }
    }
    
    # Mermaid 코드를 이미지 링크로 교체
    $tempMd = $mdFile -replace '\.md$', '_temp.md'
    $newContent = $content
    
    # 역순으로 교체 (인덱스 변경 방지)
    for ($i = $imagePaths.Count - 1; $i -ge 0; $i--) {
        $imgPath = $imagePaths[$i]
        # 절대 경로 사용 (Pandoc이 이미지를 찾을 수 있도록)
        $absPath = (Resolve-Path $imgPath.Path).Path
        $imageMarkdown = "![Mermaid Diagram]($absPath)"
        $newContent = $newContent.Substring(0, $imgPath.Start) + $imageMarkdown + $newContent.Substring($imgPath.End)
    }
    
    # 표지 페이지 처리를 위해 마크다운 전처리
    # HTML div의 page-break-after를 LaTeX 명령으로 변환
    $pageBreakPattern = '<div style="page-break-after: always;"></div>'
    if ($newContent -match $pageBreakPattern) {
        # page-break-after div 뒤에 LaTeX 페이지 나누기 추가
        $newContent = $newContent -replace "($([regex]::Escape($pageBreakPattern)))\s*", "`$1`n`n````{=latex}`n\clearpage`n````n`n"
    }
    
    $newContent | Out-File -FilePath $tempMd -Encoding UTF8
    
    # PDF로 변환 (출력 폴더에 저장)
    $mdFilename = [System.IO.Path]::GetFileNameWithoutExtension($mdFile)
    $outputPdf = Join-Path $outputDir "$mdFilename.pdf"
    
    Write-Host "  → PDF 변환 중..." -ForegroundColor Cyan
    
    # KoPub 폰트 파일 경로 찾기
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $fontDir = Join-Path $scriptDir "font" "KoPub"
    $kopubDotumMedium = Join-Path $fontDir "KoPub Dotum Medium.ttf"
    
    # 임시 LaTeX 헤더 파일 생성 (줄간격, 표지 페이지, KoPub 폰트 설정)
    $headerFile = [System.IO.Path]::GetTempFileName() + ".tex"
    
    if (Test-Path $kopubDotumMedium) {
        # KoPub 폰트가 있는 경우
        $fontDirAbs = (Resolve-Path $fontDir).Path
        # Windows 경로를 LaTeX 호환 형식으로 변환 (백슬래시를 슬래시로)
        $fontDirNormalized = $fontDirAbs -replace '\\', '/'
        
        $headerContent = @"
\usepackage{setspace}
\setstretch{1.2}
\usepackage{geometry}
\usepackage{fontspec}
\setmainfont{KoPubDotumMedium}[
  Path={$fontDirNormalized}/,
  Extension=.ttf,
  UprightFont={KoPub Dotum Medium},
  BoldFont={KoPub Dotum Bold},
  ItalicFont={KoPub Dotum Light},
]
\setsansfont{KoPubDotumMedium}[
  Path={$fontDirNormalized}/,
  Extension=.ttf,
  UprightFont={KoPub Dotum Medium},
  BoldFont={KoPub Dotum Bold},
]
\makeatletter
\let\oldtableofcontents\tableofcontents
\renewcommand{\tableofcontents}{%
  \clearpage%
  \oldtableofcontents%
  \clearpage%
}
\makeatother
"@
        $headerContent | Out-File -FilePath $headerFile -Encoding UTF8
        Write-Host "  → KoPub 폰트 사용: $(Split-Path -Leaf $kopubDotumMedium)" -ForegroundColor Green
    } else {
        # KoPub 폰트가 없는 경우 기본 설정
        $headerContent = @"
\usepackage{setspace}
\setstretch{1.2}
\usepackage{geometry}
\makeatletter
\let\oldtableofcontents\tableofcontents
\renewcommand{\tableofcontents}{%
  \clearpage%
  \oldtableofcontents%
  \clearpage%
}
\makeatother
"@
        $headerContent | Out-File -FilePath $headerFile -Encoding UTF8
        Write-Host "  → KoPub 폰트를 찾을 수 없어 기본 폰트 사용" -ForegroundColor Yellow
    }
    
    # Pandoc 명령어 (한글 지원)
    $mdDir = Split-Path -Parent $tempMd
    $pandocCmd = @(
        "pandoc",
        "`"$tempMd`"",
        "-o", "`"$outputPdf`"",
        "--pdf-engine=xelatex",
        "--variable", "fontsize=12pt",
        "--variable", "geometry:margin=2cm",
        "--include-in-header", "`"$headerFile`"",
        "--toc",
        "--toc-depth=3",
        "--highlight-style=tango",
        "--resource-path", "$mdDir;$imageDir"
    )
    
    try {
        & $pandocCmd[0] $pandocCmd[1..($pandocCmd.Length-1)]
        if (Test-Path $outputPdf) {
            Write-Host "  ✓ PDF 생성 완료: $outputPdf" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ PDF 생성 실패" -ForegroundColor Red
        Write-Host "    LaTeX가 설치되어 있지 않을 수 있습니다." -ForegroundColor Yellow
        Write-Host "    doc/변환_가이드.md를 참고하세요." -ForegroundColor Yellow
    } finally {
        if (Test-Path $tempMd) {
            Remove-Item $tempMd
        }
        if (Test-Path $headerFile) {
            Remove-Item $headerFile
        }
    }
}

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "변환 완료!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

