#!/bin/bash
# 여러 PDF 파일을 하나로 병합하는 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 출력 폴더 설정
if [ -n "$1" ]; then
    OUTPUT_DIR="$1"
else
    # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
    OUTPUT_DIR="output_$(date +%Y%m%d_%H-%M)"
fi

echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}PDF 병합 도구${NC}"
echo -e "${CYAN}출력 폴더: ${OUTPUT_DIR}${NC}"
echo -e "${CYAN}================================================${NC}"

# 병합할 PDF 파일 목록 (출력 폴더에서 찾기)
pdf_files=(
    "${OUTPUT_DIR}/서비스_기획서.pdf"
    "${OUTPUT_DIR}/화면_기능_정의서.pdf"
    "${OUTPUT_DIR}/화면_흐름도.pdf"
)

# 출력 파일명 (출력 폴더에 저장)
output_file="${OUTPUT_DIR}/윤이버스_한국어앱_서비스_기획서_전체.pdf"

# 존재하는 PDF 파일만 필터링
existing_files=()
for pdf in "${pdf_files[@]}"; do
    if [ -f "$pdf" ]; then
        existing_files+=("$pdf")
        echo -e "${GREEN}✓ 발견: ${pdf}${NC}"
    else
        echo -e "${YELLOW}⚠ 파일 없음: ${pdf}${NC}"
    fi
done

if [ ${#existing_files[@]} -eq 0 ]; then
    echo -e "${RED}✗ 병합할 PDF 파일이 없습니다.${NC}"
    exit 1
fi

echo -e "\n${CYAN}병합할 파일: ${#existing_files[@]}개${NC}"

# 방법 1: pdfunite 사용 (poppler-utils)
if command -v pdfunite &> /dev/null; then
    echo -e "\n${CYAN}→ pdfunite로 병합 중...${NC}"
    if pdfunite "${existing_files[@]}" "$output_file" 2>/dev/null; then
        if [ -f "$output_file" ]; then
            echo -e "${GREEN}✓ PDF 병합 완료: ${output_file}${NC}"
            exit 0
        fi
    fi
fi

# 방법 2: Ghostscript 사용
if command -v gs &> /dev/null; then
    echo -e "\n${CYAN}→ Ghostscript로 병합 중...${NC}"
    if gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$output_file" "${existing_files[@]}" 2>/dev/null; then
        if [ -f "$output_file" ]; then
            echo -e "${GREEN}✓ PDF 병합 완료: ${output_file}${NC}"
            exit 0
        fi
    fi
fi

# 방법 3: pdftk 사용
if command -v pdftk &> /dev/null; then
    echo -e "\n${CYAN}→ pdftk로 병합 중...${NC}"
    if pdftk "${existing_files[@]}" cat output "$output_file" 2>/dev/null; then
        if [ -f "$output_file" ]; then
            echo -e "${GREEN}✓ PDF 병합 완료: ${output_file}${NC}"
            exit 0
        fi
    fi
fi

# 방법 4: Python 스크립트 사용
echo -e "\n${CYAN}→ Python으로 병합 중...${NC}"
python3 << 'PYTHON_SCRIPT'
import sys
from pathlib import Path

pdf_files = sys.argv[1:-1]
output_file = sys.argv[-1]

try:
    from PyPDF2 import PdfMerger
    
    merger = PdfMerger()
    
    for pdf_file in pdf_files:
        if Path(pdf_file).exists():
            print(f"  → 추가 중: {pdf_file}")
            merger.append(pdf_file)
    
    with open(output_file, 'wb') as output:
        merger.write(output)
    
    merger.close()
    print(f"✓ PDF 병합 완료: {output_file}")
    sys.exit(0)
except ImportError:
    print("✗ PyPDF2가 설치되지 않았습니다.")
    print("  설치: pip install PyPDF2")
    sys.exit(1)
except Exception as e:
    print(f"✗ 병합 실패: {e}")
    sys.exit(1)
PYTHON_SCRIPT "${existing_files[@]}" "$output_file"

if [ -f "$output_file" ]; then
    file_size=$(du -h "$output_file" | cut -f1)
    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN}병합 완료!${NC}"
    echo -e "${GREEN}파일: ${output_file}${NC}"
    echo -e "${GREEN}크기: ${file_size}${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "\n${RED}✗ PDF 병합 실패${NC}"
    echo -e "${YELLOW}다음 도구 중 하나를 설치해주세요:${NC}"
    echo -e "  - pdfunite: sudo apt-get install poppler-utils"
    echo -e "  - Ghostscript: sudo apt-get install ghostscript"
    echo -e "  - pdftk: sudo apt-get install pdftk"
    echo -e "  - PyPDF2: pip install PyPDF2"
    exit 1
fi

