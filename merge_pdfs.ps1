# 여러 PDF 파일을 하나로 병합하는 PowerShell 스크립트

# 출력 폴더 설정
if ($args.Count -gt 0) {
    $outputDir = $args[0]
} else {
    # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
    $outputDir = "output_$(Get-Date -Format 'yyyyMMdd_HH-mm')"
}

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "PDF 병합 도구" -ForegroundColor Cyan
Write-Host "출력 폴더: $outputDir" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# 병합할 PDF 파일 목록 (출력 폴더에서 찾기)
$pdfFiles = @(
    Join-Path $outputDir "서비스_기획서.pdf",
    Join-Path $outputDir "화면_기능_정의서.pdf",
    Join-Path $outputDir "화면_흐름도.pdf"
)

# 출력 파일명 (출력 폴더에 저장)
$outputFile = Join-Path $outputDir "윤이버스_한국어앱_서비스_기획서_전체.pdf"

# 존재하는 PDF 파일만 필터링
$existingFiles = @()
foreach ($pdf in $pdfFiles) {
    if (Test-Path $pdf) {
        $existingFiles += $pdf
        Write-Host "✓ 발견: $pdf" -ForegroundColor Green
    } else {
        Write-Host "⚠ 파일 없음: $pdf" -ForegroundColor Yellow
    }
}

if ($existingFiles.Count -eq 0) {
    Write-Host "✗ 병합할 PDF 파일이 없습니다." -ForegroundColor Red
    exit 1
}

Write-Host "`n병합할 파일: $($existingFiles.Count)개" -ForegroundColor Cyan
Write-Host "출력 파일: $outputFile" -ForegroundColor Cyan

# Python 스크립트 사용
Write-Host "`n→ Python으로 병합 중..." -ForegroundColor Cyan

$pythonScript = @"
import sys
from pathlib import Path

pdf_files = sys.argv[1:-1]
output_file = sys.argv[-1]

try:
    try:
        import pypdf
        merger = pypdf.PdfMerger()
    except ImportError:
        from PyPDF2 import PdfMerger
        merger = PdfMerger()
    
    for pdf_file in pdf_files:
        if Path(pdf_file).exists():
            print(f'  → 추가 중: {pdf_file}')
            merger.append(pdf_file)
    
    with open(output_file, 'wb') as output:
        merger.write(output)
    
    merger.close()
    print(f'✓ PDF 병합 완료: {output_file}')
    sys.exit(0)
except ImportError:
    print('✗ PyPDF2 또는 pypdf가 설치되지 않았습니다.')
    print('  설치: pip install pypdf')
    sys.exit(1)
except Exception as e:
    print(f'✗ 병합 실패: {e}')
    sys.exit(1)
"@

$pdfFilesArg = $existingFiles -join ' '
$result = python -c $pythonScript $pdfFilesArg $outputFile

if (Test-Path $outputFile) {
    $fileSize = (Get-Item $outputFile).Length / 1MB
    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "병합 완료!" -ForegroundColor Green
    Write-Host "파일: $outputFile" -ForegroundColor Green
    Write-Host "크기: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
} else {
    Write-Host "`n✗ PDF 병합 실패" -ForegroundColor Red
    Write-Host "다음 패키지를 설치해주세요:" -ForegroundColor Yellow
    Write-Host "  pip install pypdf" -ForegroundColor Yellow
    exit 1
}

