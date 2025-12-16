#!/bin/bash
# 마크다운 파일과 Mermaid 다이어그램을 PowerPoint 프레젠테이션으로 변환하는 Bash 스크립트

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
echo -e "${CYAN}마크다운 → PowerPoint 변환 도구${NC}"
if [ "$USE_CUSTOM_INPUT" = true ]; then
    echo -e "${CYAN}입력 폴더: ${INPUT_DIR}${NC}"
fi
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

# Python 확인 (현재 활성화된 환경 우선)
PYTHON_CMD=""
if command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
else
    echo -e "${RED}✗ Python이 설치되지 않았습니다.${NC}"
    exit 1
fi

# Python 버전 및 경로 확인
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
PYTHON_PATH=$(which $PYTHON_CMD 2>/dev/null || command -v $PYTHON_CMD)

echo -e "${GREEN}✓ Python 설치 확인됨${NC}"
echo -e "  버전: ${PYTHON_VERSION}"
echo -e "  경로: ${PYTHON_PATH}"

# python-pptx 확인
echo -e "\n${CYAN}python-pptx 모듈 확인 중...${NC}"
if $PYTHON_CMD -c "import pptx" 2>/dev/null; then
    PPTX_VERSION=$($PYTHON_CMD -c "import pptx; print(pptx.__version__)" 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓ python-pptx 설치 확인됨 (버전: ${PPTX_VERSION})${NC}"
else
    echo -e "${RED}✗ python-pptx 모듈을 찾을 수 없습니다${NC}"
    echo -e "\n${YELLOW}해결 방법:${NC}"
    echo -e "  1. 현재 Python 환경에 설치:"
    echo -e "     ${PYTHON_CMD} -m pip install python-pptx"
    echo -e "  2. 또는 conda 환경이 활성화된 경우:"
    echo -e "     conda install -c conda-forge python-pptx"
    echo -e "  3. 또는 pip 직접 사용:"
    echo -e "     pip install python-pptx"
    echo -e "\n${YELLOW}현재 Python 환경 정보:${NC}"
    echo -e "  Python: ${PYTHON_PATH}"
    echo -e "  버전: ${PYTHON_VERSION}"
    $PYTHON_CMD -c "import sys; print(f'  실행 경로: {sys.executable}')" 2>/dev/null || true
    $PYTHON_CMD -c "import sys; [print(f'  경로: {p}') for p in sys.path[:3]]" 2>/dev/null || true
    exit 1
fi

# Mermaid CLI 확인
if ! test_dependency "mmdc" "Mermaid CLI"; then
    echo -e "\n${YELLOW}Mermaid CLI가 필요합니다.${NC}"
    echo -e "${YELLOW}설치: npm install -g @mermaid-js/mermaid-cli${NC}"
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
    
    # Python 스크립트로 PPT 변환
    md_filename=$(basename "$md_file" .md)
    output_ppt="$OUTPUT_DIR/${md_filename}.pptx"
    
    $PYTHON_CMD - "$md_file" "$image_dir" "$output_ppt" "$OUTPUT_DIR" << 'PYTHON_EOF'
import re
import os
import subprocess
import sys
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.dml.color import RGBColor

md_file = sys.argv[1]
image_dir = sys.argv[2]
output_ppt = sys.argv[3]
output_dir = sys.argv[4]

# 파일 읽기
with open(md_file, 'r', encoding='utf-8') as f:
    content = f.read()

# YAML front matter 제거
if content.startswith('---'):
    parts = content.split('---', 2)
    if len(parts) >= 3:
        content = parts[2].strip()

# Mermaid 다이어그램 찾기 및 변환
pattern = r'```mermaid\s*\n(.*?)```'
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
            ['mmdc', '-i', temp_mmd, '-o', output_image, '-b', 'transparent', '-w', '1920', '-H', '1080'],
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

# HTML 태그 제거
new_content = re.sub(r'<div[^>]*>', '', content)
new_content = re.sub(r'</div>', '', new_content)
new_content = re.sub(r'<style[^>]*>.*?</style>', '', new_content, flags=re.DOTALL)

# Mermaid 코드를 이미지 링크로 교체
for img_info in reversed(image_paths):
    # 이미지 파일명만 사용 (output_dir/images에 있음)
    img_filename = os.path.basename(img_info['path'])
    # 상대 경로는 output_ppt 기준으로 images 폴더
    rel_path = os.path.join('images', img_filename)
    image_markdown = f"![Mermaid Diagram]({rel_path})"
    new_content = new_content[:img_info['start']] + image_markdown + new_content[img_info['end']:]

# 슬라이드 파싱
slides = []
current_slide = {'title': '', 'content': [], 'level': 0}

lines = new_content.split('\n')
for line in lines:
    # 빈 줄 또는 구분선 무시
    if not line.strip() or line.strip() == '---':
        continue
    
    # 제목 감지
    if line.startswith('#'):
        level = len(line) - len(line.lstrip('#'))
        title = line.lstrip('#').strip()
        # HTML 태그 제거
        title = re.sub(r'<[^>]+>', '', title)
        
        # 이전 슬라이드 저장
        if current_slide['title'] or current_slide['content']:
            slides.append(current_slide)
        
        # 새 슬라이드 시작
        current_slide = {
            'title': title,
            'content': [],
            'level': level
        }
    # 이미지 링크 감지
    elif line.strip().startswith('!['):
        match = re.match(r'!\[.*?\]\((.*?)\)', line)
        if match:
            img_path = match.group(1)
            # 상대 경로를 절대 경로로 변환
            if not os.path.isabs(img_path):
                # 먼저 output_dir/images에서 찾기
                img_path_in_output = os.path.join(output_dir, 'images', os.path.basename(img_path))
                if os.path.exists(img_path_in_output):
                    img_path = os.path.abspath(img_path_in_output)
                else:
                    # 없으면 원본 마크다운 파일 기준으로 찾기
                    img_path = os.path.join(os.path.dirname(md_file), img_path)
                    img_path = os.path.abspath(img_path)
            else:
                img_path = os.path.abspath(img_path)
            current_slide['content'].append({
                'type': 'image',
                'path': img_path
            })
    # 일반 내용
    elif line.strip() and not line.strip().startswith('```'):
        # HTML 태그 제거
        text = re.sub(r'<[^>]+>', '', line)
        text = text.replace('&nbsp;', ' ').replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&')
        if text.strip():  # 빈 텍스트가 아닌 경우만 추가
            current_slide['content'].append({
                'type': 'text',
                'text': text.strip()
            })

# 마지막 슬라이드 저장
if current_slide['title'] or current_slide['content']:
    slides.append(current_slide)

# 색상 테마 정의
theme_colors = {
    'primary': RGBColor(0, 51, 102),
    'text': RGBColor(51, 51, 51),
    'light_text': RGBColor(102, 102, 102)
}

def get_image_size(img_path, max_width, max_height):
    """이미지 크기를 슬라이드에 맞게 조정"""
    try:
        from PIL import Image
        img = Image.open(img_path)
        img_width, img_height = img.size
        width_ratio = max_width / Inches(img_width / 96)
        height_ratio = max_height / Inches(img_height / 96)
        ratio = min(width_ratio, height_ratio, 1.0)
        return Inches(img_width * ratio / 96), Inches(img_height * ratio / 96)
    except:
        return max_width, max_height

# PowerPoint 프레젠테이션 생성
prs = Presentation()
prs.slide_width = Inches(10)
prs.slide_height = Inches(7.5)

for i, slide_data in enumerate(slides):
    # 빈 슬라이드 사용 (더 많은 제어 가능)
    slide_layout = prs.slide_layouts[6]
    slide = prs.slides.add_slide(slide_layout)
    
    # 제목 설정
    if slide_data['title']:
        title_left = Inches(0.5)
        title_top = Inches(0.3)
        title_width = Inches(9)
        title_height = Inches(0.8)
        
        title_box = slide.shapes.add_textbox(title_left, title_top, title_width, title_height)
        title_frame = title_box.text_frame
        title_frame.word_wrap = True
        title_frame.vertical_anchor = MSO_ANCHOR.TOP
        
        p = title_frame.paragraphs[0]
        p.text = slide_data['title']
        p.font.size = Pt(28 if slide_data['level'] == 1 else 24)
        p.font.bold = True
        p.font.color.rgb = theme_colors['primary']
        p.alignment = PP_ALIGN.LEFT
    
    # 내용 추가
    if slide_data['content']:
        content_top = Inches(1.3)
        content_left = Inches(0.5)
        content_width = Inches(9)
        content_height = Inches(5.8)
        
        # 이미지와 텍스트 분리
        images = [item for item in slide_data['content'] if item.get('type') == 'image']
        texts = [item for item in slide_data['content'] if item.get('type') == 'text']
        
        has_image = len(images) > 0
        has_text = len(texts) > 0
        
        # 텍스트 추가
        if has_text:
            if has_image:
                text_width = Inches(4.5)
            else:
                text_width = content_width
            
            text_box = slide.shapes.add_textbox(content_left, content_top, text_width, content_height)
            text_frame = text_box.text_frame
            text_frame.word_wrap = True
            text_frame.vertical_anchor = MSO_ANCHOR.TOP
            text_frame.margin_left = Inches(0.1)
            text_frame.margin_right = Inches(0.1)
            text_frame.margin_top = Inches(0.1)
            text_frame.margin_bottom = Inches(0.1)
            
            for content_item in texts:
                p = text_frame.add_paragraph()
                text = content_item['text']
                
                # 리스트 감지
                if re.match(r'^[\s]*[-*+]\s+', text) or re.match(r'^[\s]*\d+\.\s+', text):
                    text = re.sub(r'^[\s]*[-*+]\s+', '• ', text)
                    text = re.sub(r'^[\s]*\d+\.\s+', '', text)
                    p.level = 0
                    p.space_before = Pt(4)
                    p.font.size = Pt(13)
                else:
                    p.font.size = Pt(14)
                
                p.text = text
                p.space_after = Pt(8)
                p.font.color.rgb = theme_colors['text']
                p.alignment = PP_ALIGN.LEFT
        
        # 이미지 추가
        for img_item in images:
            img_path = img_item['path']
            if os.path.exists(img_path):
                try:
                    # 이미지 크기 자동 조정
                    if has_text:
                        max_width = Inches(4.5)
                        max_height = Inches(5.5)
                        img_left = Inches(5)
                    else:
                        max_width = Inches(9)
                        max_height = Inches(5.8)
                        img_left = content_left
                    
                    try:
                        img_width, img_height = get_image_size(img_path, max_width, max_height)
                        img_top = content_top + (max_height - img_height) / 2
                        slide.shapes.add_picture(img_path, img_left, img_top, width=img_width, height=img_height)
                    except Exception as e:
                        # get_image_size 실패 시 기본 크기 사용
                        slide.shapes.add_picture(img_path, img_left, content_top, width=max_width, height=max_height)
                except Exception as e:
                    print(f"  ⚠ 이미지 추가 실패: {img_path} - {e}")
            else:
                print(f"  ⚠ 이미지 파일 없음: {img_path}")
    
    # 슬라이드 번호 추가
    slide_num_left = Inches(9.2)
    slide_num_top = Inches(7.2)
    slide_num_box = slide.shapes.add_textbox(slide_num_left, slide_num_top, Inches(0.8), Inches(0.3))
    slide_num_frame = slide_num_box.text_frame
    slide_num_frame.text = f"{i+1}"
    slide_num_frame.paragraphs[0].font.size = Pt(10)
    slide_num_frame.paragraphs[0].font.color.rgb = theme_colors['light_text']
    slide_num_frame.paragraphs[0].alignment = PP_ALIGN.RIGHT

# 프레젠테이션 저장
prs.save(output_ppt)
print(f"  ✓ PowerPoint 생성 완료: {output_ppt}")
PYTHON_EOF

    if [ -f "$output_ppt" ]; then
        echo -e "${GREEN}✓ 완료: ${output_ppt}${NC}"
    else
        echo -e "${RED}✗ 실패: ${md_file}${NC}"
    fi
done

echo -e "\n${CYAN}================================================${NC}"
echo -e "${CYAN}변환 완료!${NC}"
echo -e "${CYAN}출력 폴더: ${OUTPUT_DIR}${NC}"
echo -e "${CYAN}================================================${NC}"

