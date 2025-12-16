#!/bin/bash
# 마크다운 파일과 Mermaid 다이어그램을 PDF로 변환하는 Bash 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 명령줄 인자 파싱
INPUT_DIR=""
OUTPUT_DIR=""
USE_CUSTOM_INPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -in)
            INPUT_DIR="$2"
            USE_CUSTOM_INPUT=true
            shift 2
            ;;
        -o)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            # 기존 방식 호환성: 첫 번째 인자가 출력 폴더로 간주
            if [ -z "$OUTPUT_DIR" ]; then
                OUTPUT_DIR="$1"
            fi
            shift
            ;;
    esac
done

# 출력 폴더 설정
if [ -z "$OUTPUT_DIR" ]; then
    # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
    OUTPUT_DIR="output_$(date +%Y%m%d_%H-%M)"
fi

# 입력 폴더 설정
if [ -z "$INPUT_DIR" ]; then
    INPUT_DIR="doc"
fi

# 출력 폴더 생성
mkdir -p "$OUTPUT_DIR"
echo -e "${CYAN}================================================${NC}"
echo -e "${CYAN}마크다운 → PDF 변환 도구${NC}"
echo -e "${CYAN}출력 폴더: ${OUTPUT_DIR}${NC}"
echo -e "${CYAN}================================================${NC}"

# 의존성 확인 함수
test_dependency() {
    local command=$1
    local name=$2
    
    if command -v "$command" &> /dev/null; then
        echo -e "${GREEN}✓ ${name} 설치 확인됨${NC}"
        return 0
    else
        echo -e "${RED}✗ ${name} 설치 필요${NC}"
        return 1
    fi
}

# 의존성 확인
pandoc_installed=false
mmdc_installed=false

if test_dependency "pandoc" "Pandoc"; then
    pandoc_installed=true
fi

if test_dependency "mmdc" "Mermaid CLI"; then
    mmdc_installed=true
fi

if [ "$pandoc_installed" = false ] || [ "$mmdc_installed" = false ]; then
    echo -e "\n${YELLOW}필요한 도구를 설치해주세요.${NC}"
    echo -e "${YELLOW}설치 방법은 doc/변환_가이드.md를 참고하세요.${NC}"
    exit 1
fi

# 변환할 마크다운 파일 목록
if [ "$USE_CUSTOM_INPUT" = true ]; then
    # 사용자 지정 입력 폴더에서 모든 .md 파일 찾기
    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${RED}✗ 입력 폴더를 찾을 수 없습니다: ${INPUT_DIR}${NC}"
        exit 1
    fi
    echo -e "${CYAN}입력 폴더: ${INPUT_DIR}${NC}"
    # find 명령으로 모든 .md 파일 찾기
    mapfile -t md_files < <(find "$INPUT_DIR" -type f -name "*.md" | sort)
    if [ ${#md_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ 입력 폴더에 .md 파일이 없습니다: ${INPUT_DIR}${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ ${#md_files[@]}개의 마크다운 파일을 찾았습니다${NC}"
else
    # 기본 파일 목록 (하위 호환성)
    md_files=(
        "doc/서비스_기획서.md"
        "doc/화면_기능_정의서.md"
        "doc/화면_흐름도.md"
    )
fi

# 이미지 저장 디렉토리 (출력 폴더 내부)
image_dir="$OUTPUT_DIR/images"
mkdir -p "$image_dir"

# 각 마크다운 파일 처리
for md_file in "${md_files[@]}"; do
    if [ ! -f "$md_file" ]; then
        echo -e "\n${RED}✗ 파일을 찾을 수 없습니다: ${md_file}${NC}"
        continue
    fi
    
    echo -e "\n${YELLOW}처리 중: ${md_file}${NC}"
    
    # Python을 사용한 Mermaid 추출 및 교체 (더 안정적)
    md_filename=$(basename "$md_file" .md)
    temp_md="$OUTPUT_DIR/${md_filename}_temp.md"
    
    # 현재 디렉토리 저장 (절대 경로 계산용)
    current_dir=$(pwd)
    
    # Python 스크립트 실행 (heredoc 사용)
    python3 << PYTHON_SCRIPT
import re
import os
import subprocess
import sys
from pathlib import Path

md_file = "$md_file"
image_dir = "$image_dir"
temp_md = "$temp_md"
current_dir = "$current_dir"
output_dir = "$OUTPUT_DIR"

# 파일 읽기
with open(md_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Mermaid 다이어그램 찾기
pattern = r'\`\`\`mermaid\s*\n(.*?)\`\`\`'
matches = list(re.finditer(pattern, content, re.DOTALL))

image_paths = []
for i, match in enumerate(matches):
    diagram_code = match.group(1)
    
    # 임시 mermaid 파일 생성
    temp_mmd = f'{image_dir}/temp_{i}.mmd'
    with open(temp_mmd, 'w', encoding='utf-8') as f:
        f.write(diagram_code)
    
    # 이미지로 변환
    output_image = f'{image_dir}/diagram_{i}.png'
    try:
        result = subprocess.run(
            ['mmdc', '-i', temp_mmd, '-o', output_image, '-b', 'transparent'],
            capture_output=True,
            check=True
        )
        if os.path.exists(output_image):
            image_paths.append({
                'start': match.start(),
                'end': match.end(),
                'path': output_image
            })
            print(f"  ✓ 다이어그램 {i+1} 변환 완료")
    except subprocess.CalledProcessError:
        print(f"  ✗ 다이어그램 {i+1} 변환 실패")
    finally:
        if os.path.exists(temp_mmd):
            os.remove(temp_mmd)

# Mermaid 코드를 이미지 링크로 교체
new_content = content
for img_info in reversed(image_paths):
    # 절대 경로 사용 (Pandoc이 이미지를 찾을 수 있도록)
    abs_path = os.path.abspath(img_info['path'])
    # Windows 경로를 Unix 스타일로 변환 (pathlib 사용)
    abs_path = str(Path(abs_path).as_posix())
    
    # WSL 환경 감지 및 경로 변환
    is_wsl = False
    if os.path.exists('/proc/version'):
        try:
            with open('/proc/version', 'r') as f:
                if 'microsoft' in f.read().lower():
                    is_wsl = True
        except:
            pass
    
    if is_wsl and ':' in abs_path and not abs_path.startswith('/mnt/'):
        # WSL에서 Windows 경로를 마운트 경로로 변환
        drive_letter = abs_path[0].lower()
        abs_path = f'/mnt/{drive_letter}{abs_path[2:]}'
    
    # 경로가 존재하는지 확인
    if not os.path.exists(abs_path):
        # 상대 경로로 시도
        rel_path = os.path.relpath(img_info['path'], os.path.dirname(temp_md))
        if os.path.exists(os.path.join(os.path.dirname(temp_md), rel_path)):
            abs_path = os.path.abspath(os.path.join(os.path.dirname(temp_md), rel_path))
            abs_path = str(Path(abs_path).as_posix())
    
    image_markdown = f"![Mermaid Diagram]({abs_path})"
    new_content = new_content[:img_info['start']] + image_markdown + new_content[img_info['end']:]

# 표지 페이지 처리를 위해 마크다운 전처리
# HTML div의 page-break-after를 LaTeX 명령으로 변환
import re
page_break_pattern = r'(<div style="page-break-after: always;"></div>\n)'
def replace_break(match):
    # 백틱을 문자열로 구성하여 Bash가 해석하지 않도록 함
    backtick = chr(96)  # 백틱 문자를 ASCII 코드로 생성
    latex_block = '\n' + backtick + backtick + backtick + '{=latex}\n\\clearpage\n' + backtick + backtick + backtick + '\n\n'
    return match.group(1) + latex_block
new_content = re.sub(page_break_pattern, replace_break, new_content)

# 임시 마크다운 파일 저장
with open(temp_md, 'w', encoding='utf-8') as f:
    f.write(new_content)
PYTHON_SCRIPT
    
    if [ ! -f "$temp_md" ]; then
        echo -e "  ${RED}✗ 임시 파일 생성 실패${NC}"
        continue
    fi
    
    # PDF로 변환 (출력 폴더에 저장)
    md_filename=$(basename "$md_file" .md)
    output_pdf="$OUTPUT_DIR/${md_filename}.pdf"
    
    echo -e "  ${CYAN}→ PDF 변환 중...${NC}"
    
    # KoPub 폰트 파일 경로 찾기
    script_dir=$(cd "$(dirname "$0")" && pwd)
    font_dir="$script_dir/font/KoPub"
    kopub_dotum_medium="$font_dir/KoPub Dotum Medium.ttf"
    
    # 임시 LaTeX 헤더 파일 생성 (줄간격, 표지 페이지, KoPub 폰트 설정)
    header_file=$(mktemp --suffix=.tex)
    
    if [ -f "$kopub_dotum_medium" ]; then
        # KoPub 폰트가 있는 경우
        font_dir_abs=$(cd "$font_dir" && pwd)
        
        # WSL 환경 감지 및 경로 변환
        if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
            # WSL 환경
            if [[ "$font_dir_abs" =~ ^[A-Za-z]: ]]; then
                # Windows 스타일 경로인 경우 (D:/works/...)
                drive_letter=$(echo "$font_dir_abs" | cut -c1 | tr '[:upper:]' '[:lower:]')
                font_dir_normalized="/mnt/${drive_letter}${font_dir_abs:2}"
            elif [[ "$font_dir_abs" =~ ^/mnt/ ]]; then
                # 이미 WSL 마운트 경로인 경우
                font_dir_normalized="$font_dir_abs"
            else
                # 상대 경로인 경우
                font_dir_normalized="$font_dir_abs"
            fi
        else
            # 일반 Linux 환경
            font_dir_normalized="$font_dir_abs"
        fi
        
        # 경로의 백슬래시를 슬래시로 변환
        font_dir_normalized=$(echo "$font_dir_normalized" | sed 's|\\|/|g')
        
        # 폰트 경로가 실제로 존재하는지 확인
        if [ ! -d "$font_dir_normalized" ]; then
            echo -e "  ${YELLOW}⚠ 폰트 경로를 찾을 수 없습니다: $font_dir_normalized${NC}"
            echo -e "  ${YELLOW}  원본 경로: $font_dir_abs${NC}"
            # 기본 폰트 사용으로 폴백
            font_dir_normalized=""
        fi
        
        if [ -n "$font_dir_normalized" ] && [ -d "$font_dir_normalized" ]; then
            # 폰트 파일 경로 확인
            kopub_medium_file="$font_dir_normalized/KoPub Dotum Medium.ttf"
            kopub_bold_file="$font_dir_normalized/KoPub Dotum Bold.ttf"
            kopub_light_file="$font_dir_normalized/KoPub Dotum Light.ttf"
            
            # LaTeX에서 경로에 공백이 있으면 중괄호로 감싸야 함
            # 또한 파일명도 중괄호로 감싸야 함
            font_dir_escaped="{$font_dir_normalized}"
            
            cat > "$header_file" << EOF
\usepackage{setspace}
\setstretch{1.2}
\usepackage{geometry}
\usepackage{fontspec}
EOF
            
            # 폰트 파일이 존재하는지 확인하고 설정
            if [ -f "$kopub_medium_file" ]; then
                # 임시 디렉토리에 공백 없는 이름으로 폰트 파일 복사
                # 출력 폴더 내부에 폰트 디렉토리 생성 (한글 없는 경로 사용)
                output_dir_for_fonts=$(dirname "$output_pdf")
                pdf_basename=$(basename "$output_pdf" .pdf)
                # 한글 파일명을 해시로 변환하여 경로 문제 방지
                pdf_hash=$(echo -n "$pdf_basename" | md5sum | cut -d' ' -f1 | cut -c1-8)
                temp_font_dir="$output_dir_for_fonts/temp_fonts_${pdf_hash}"
                mkdir -p "$temp_font_dir"
                kopub_medium_temp="$temp_font_dir/KoPubDotumMedium.ttf"
                kopub_bold_temp="$temp_font_dir/KoPubDotumBold.ttf"
                kopub_light_temp="$temp_font_dir/KoPubDotumLight.ttf"
                
                # 폰트 파일 복사
                echo -e "  ${CYAN}  원본 폰트 파일 확인:${NC}"
                echo -e "  ${CYAN}    Medium: $kopub_medium_file${NC}"
                if [ -f "$kopub_medium_file" ]; then
                    file_size=$(stat -f%z "$kopub_medium_file" 2>/dev/null || stat -c%s "$kopub_medium_file" 2>/dev/null || echo "unknown")
                    echo -e "  ${GREEN}    ✓ 존재함 (크기: $file_size bytes)${NC}"
                else
                    echo -e "  ${RED}    ✗ 없음${NC}"
                fi
                
                if cp "$kopub_medium_file" "$kopub_medium_temp" 2>&1; then
                    if [ -f "$kopub_bold_file" ]; then
                        cp "$kopub_bold_file" "$kopub_bold_temp" 2>&1
                    fi
                    if [ -f "$kopub_light_file" ]; then
                        cp "$kopub_light_file" "$kopub_light_temp" 2>&1
                    fi
                    
                    # 복사된 파일 확인
                    echo -e "  ${CYAN}  복사된 폰트 파일 확인:${NC}"
                    if [ -f "$kopub_medium_temp" ]; then
                        copied_size=$(stat -f%z "$kopub_medium_temp" 2>/dev/null || stat -c%s "$kopub_medium_temp" 2>/dev/null || echo "unknown")
                        echo -e "  ${GREEN}    ✓ Medium 복사됨: $kopub_medium_temp (크기: $copied_size bytes)${NC}"
                    else
                        echo -e "  ${RED}    ✗ Medium 복사 실패${NC}"
                    fi
                    
                    if [ -f "$kopub_medium_temp" ]; then
                        # 임시 폰트 디렉토리 경로 정규화
                        temp_font_dir_normalized=$(cd "$temp_font_dir" && pwd)
                        
                        # 폰트 파일의 전체 경로 (공백 없음)
                        kopub_medium_full_path="$temp_font_dir_normalized/KoPubDotumMedium.ttf"
                        kopub_bold_full_path="$temp_font_dir_normalized/KoPubDotumBold.ttf"
                        kopub_light_full_path="$temp_font_dir_normalized/KoPubDotumLight.ttf"
                        
                        # LaTeX fontspec에서 전체 경로를 직접 지정 (가장 확실한 방법)
                        # 경로를 LaTeX에서 안전하게 처리하기 위해 백슬래시를 슬래시로 변환
                        kopub_medium_path_tex="{$kopub_medium_full_path}"
                        kopub_bold_path_tex=""
                        kopub_light_path_tex=""
                        
                        if [ -f "$kopub_bold_temp" ]; then
                            kopub_bold_path_tex="{$kopub_bold_full_path}"
                            echo -e "  ${GREEN}    ✓ Bold 복사됨${NC}"
                        fi
                        if [ -f "$kopub_light_temp" ]; then
                            kopub_light_path_tex="{$kopub_light_full_path}"
                            echo -e "  ${GREEN}    ✓ Light 복사됨${NC}"
                        fi
                        
                        # LaTeX 헤더에 폰트 설정 추가
                        # 폰트 파일을 헤더 파일과 같은 디렉토리에 복사하여 상대 경로 사용
                        header_dir=$(dirname "$header_file")
                        font_copy_dir="$header_dir/fonts"
                        mkdir -p "$font_copy_dir"
                        
                        # 헤더 파일과 같은 디렉토리에 폰트 파일 복사
                        kopub_medium_header="$font_copy_dir/KoPubDotumMedium.ttf"
                        kopub_bold_header="$font_copy_dir/KoPubDotumBold.ttf"
                        kopub_light_header="$font_copy_dir/KoPubDotumLight.ttf"
                        
                        cp "$kopub_medium_temp" "$kopub_medium_header" 2>/dev/null
                        if [ -f "$kopub_bold_temp" ]; then
                            cp "$kopub_bold_temp" "$kopub_bold_header" 2>/dev/null
                        fi
                        if [ -f "$kopub_light_temp" ]; then
                            cp "$kopub_light_temp" "$kopub_light_header" 2>/dev/null
                        fi
                        
                        # 상대 경로 사용 (헤더 파일 기준)
                        kopub_medium_rel="fonts/KoPubDotumMedium.ttf"
                        kopub_bold_rel=""
                        kopub_light_rel=""
                        
                        if [ -f "$kopub_bold_header" ]; then
                            kopub_bold_rel="fonts/KoPubDotumBold.ttf"
                        fi
                        if [ -f "$kopub_light_header" ]; then
                            kopub_light_rel="fonts/KoPubDotumLight.ttf"
                        fi
                        
                        cat >> "$header_file" << EOF
\newfontfamily\mainfont{KoPubDotum}[
  UprightFont={$kopub_medium_rel},
EOF
                        if [ -n "$kopub_bold_rel" ]; then
                            echo "  BoldFont={$kopub_bold_rel}," >> "$header_file"
                        fi
                        if [ -n "$kopub_light_rel" ]; then
                            echo "  ItalicFont={$kopub_light_rel}," >> "$header_file"
                        fi
                        cat >> "$header_file" << EOF
]
\setmainfont{KoPubDotum}[
  UprightFont={$kopub_medium_rel},
EOF
                        if [ -n "$kopub_bold_rel" ]; then
                            echo "  BoldFont={$kopub_bold_rel}," >> "$header_file"
                        fi
                        if [ -n "$kopub_light_rel" ]; then
                            echo "  ItalicFont={$kopub_light_rel}," >> "$header_file"
                        fi
                        cat >> "$header_file" << EOF
]
\setsansfont{KoPubDotum}[
  UprightFont={$kopub_medium_rel},
EOF
                        if [ -n "$kopub_bold_rel" ]; then
                            echo "  BoldFont={$kopub_bold_rel}," >> "$header_file"
                        fi
                        echo "]" >> "$header_file"
                        
                        echo -e "  ${GREEN}→ KoPub 폰트 사용: $(basename "$kopub_medium_file")${NC}"
                        echo -e "  ${CYAN}  LaTeX에서 사용할 경로: $kopub_medium_full_path${NC}"
                        
                        # 실제 파일 접근 가능 여부 확인
                        if [ -r "$kopub_medium_full_path" ]; then
                            echo -e "  ${GREEN}  ✓ 파일 읽기 권한 확인됨${NC}"
                        else
                            echo -e "  ${RED}  ✗ 파일 읽기 권한 없음${NC}"
                        fi
                        
                        # 임시 폰트 디렉토리를 나중에 정리하기 위해 변수 저장
                        export TEMP_FONT_DIR="$temp_font_dir"
                    else
                        echo -e "  ${RED}✗ 폰트 파일 복사 실패${NC}"
                        rm -rf "$temp_font_dir"
                        temp_font_dir=""
                    fi
                else
                    echo -e "  ${RED}✗ 폰트 파일 복사 실패: $kopub_medium_file${NC}"
                    rm -rf "$temp_font_dir"
                    temp_font_dir=""
                fi
            else
                echo -e "  ${YELLOW}⚠ KoPub 폰트 파일을 찾을 수 없습니다: $kopub_medium_file${NC}"
                # 기본 폰트 사용으로 폴백
                cat >> "$header_file" << 'EOF'
\setmainfont{Noto Sans CJK KR}
EOF
            fi
            
            cat >> "$header_file" << 'EOF'
\makeatletter
\let\oldtableofcontents\tableofcontents
\renewcommand{\tableofcontents}{%
  \clearpage%
  \oldtableofcontents%
  \clearpage%
}
\makeatother
EOF
            echo -e "  ${GREEN}→ KoPub 폰트 사용: $(basename "$kopub_dotum_medium")${NC}"
            echo -e "  ${CYAN}  폰트 경로: $font_dir_normalized${NC}"
        else
            # 폰트 경로를 찾을 수 없는 경우 기본 폰트 사용
            cat > "$header_file" << 'EOF'
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
EOF
            echo -e "  ${YELLOW}→ KoPub 폰트 경로를 찾을 수 없어 기본 폰트 사용${NC}"
        fi
    else
        # KoPub 폰트가 없는 경우 기본 설정
        cat > "$header_file" << 'EOF'
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
EOF
        echo -e "  ${YELLOW}→ KoPub 폰트를 찾을 수 없어 기본 폰트 사용${NC}"
    fi
    
    # Pandoc 명령어 (한글 지원)
    # Ubuntu에서 한글 폰트 확인 및 설정
    # 이미지 경로를 위한 리소스 경로 추가
    md_dir=$(dirname "$temp_md")
    
    # 에러 로그 파일 생성
    error_log=$(mktemp --suffix=.log)
    
    if pandoc "$temp_md" -o "$output_pdf" \
        --pdf-engine=xelatex \
        --variable=fontsize:12pt \
        --variable=geometry:margin=2cm \
        --include-in-header="$header_file" \
        --toc \
        --toc-depth=3 \
        --highlight-style=tango \
        --resource-path="$md_dir:$image_dir" 2>"$error_log"; then
        if [ -f "$output_pdf" ]; then
            echo -e "  ${GREEN}✓ PDF 생성 완료: ${output_pdf}${NC}"
        fi
        rm -f "$error_log"
    else
        # 에러 로그 출력
        echo -e "  ${RED}✗ PDF 생성 실패${NC}"
        echo -e "  ${YELLOW}오류 내용:${NC}"
        tail -20 "$error_log" | sed 's/^/    /'
        
        # XeLaTeX 실패 시 기본 PDF 엔진 시도 (KoPub 폰트 없이)
        echo -e "  ${CYAN}→ 기본 폰트로 재시도 중...${NC}"
        # 기본 폰트용 헤더 파일 생성
        header_file_default=$(mktemp --suffix=.tex)
        cat > "$header_file_default" << 'EOF'
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
EOF
        
        if pandoc "$temp_md" -o "$output_pdf" \
            --pdf-engine=xelatex \
            --variable=CJKmainfont:"Noto Sans CJK KR" \
            --variable=fontsize:12pt \
            --variable=geometry:margin=2cm \
            --include-in-header="$header_file_default" \
            --toc \
            --toc-depth=3 \
            --highlight-style=tango \
            --resource-path="$md_dir:$image_dir" 2>"$error_log"; then
            if [ -f "$output_pdf" ]; then
                echo -e "  ${GREEN}✓ PDF 생성 완료 (기본 폰트): ${output_pdf}${NC}"
            fi
            rm -f "$header_file_default"
        else
            echo -e "  ${RED}✗ 기본 폰트로도 생성 실패${NC}"
            echo -e "    ${YELLOW}LaTeX가 설치되어 있지 않을 수 있습니다.${NC}"
            echo -e "    ${YELLOW}doc/변환_가이드.md를 참고하세요.${NC}"
            tail -10 "$error_log" | sed 's/^/    /'
        fi
        rm -f "$error_log"
    fi
    
    # 임시 파일 정리
    rm -f "$temp_md"
    rm -f "$header_file"
    # 헤더 파일과 함께 복사된 폰트 디렉토리 정리
    if [ -n "$header_file" ]; then
        header_dir=$(dirname "$header_file")
        font_copy_dir="$header_dir/fonts"
        if [ -d "$font_copy_dir" ]; then
            rm -rf "$font_copy_dir"
        fi
    fi
    # 임시 폰트 디렉토리 정리
    if [ -n "$TEMP_FONT_DIR" ] && [ -d "$TEMP_FONT_DIR" ]; then
        rm -rf "$TEMP_FONT_DIR"
    fi
done

echo -e "\n${CYAN}================================================${NC}"
echo -e "${CYAN}변환 완료!${NC}"
echo -e "${CYAN}================================================${NC}"

