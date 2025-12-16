"""
마크다운 파일과 Mermaid 다이어그램을 PDF로 변환하는 스크립트
"""
import os
import re
import subprocess
import sys
from pathlib import Path

def check_dependencies():
    """필요한 도구가 설치되어 있는지 확인"""
    tools = {
        'pandoc': 'pandoc --version',
        'mmdc': 'mmdc --version'
    }
    
    missing = []
    for tool, cmd in tools.items():
        try:
            subprocess.run(cmd.split(), capture_output=True, check=True)
            print(f"✓ {tool} 설치 확인됨")
        except (subprocess.CalledProcessError, FileNotFoundError):
            missing.append(tool)
            print(f"✗ {tool} 설치 필요")
    
    if missing:
        print(f"\n다음 도구를 설치해주세요: {', '.join(missing)}")
        print("설치 방법은 doc/변환_가이드.md를 참고하세요.")
        return False
    return True

def extract_mermaid_diagrams(md_file):
    """마크다운 파일에서 Mermaid 다이어그램 추출"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Mermaid 코드 블록 찾기
    pattern = r'```mermaid\n(.*?)```'
    diagrams = re.findall(pattern, content, re.DOTALL)
    
    return diagrams, content

def convert_mermaid_to_images(md_file, output_dir='doc/images'):
    """Mermaid 다이어그램을 이미지로 변환"""
    os.makedirs(output_dir, exist_ok=True)
    
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Mermaid 코드 블록 찾기
    pattern = r'```mermaid\n(.*?)```'
    matches = list(re.finditer(pattern, content, re.DOTALL))
    
    image_paths = []
    for i, match in enumerate(matches):
        diagram_code = match.group(1)
        
        # 임시 mermaid 파일 생성
        temp_mmd = f'{output_dir}/temp_{i}.mmd'
        with open(temp_mmd, 'w', encoding='utf-8') as f:
            f.write(diagram_code)
        
        # 이미지로 변환
        output_image = f'{output_dir}/diagram_{i}.png'
        cmd = f'mmdc -i {temp_mmd} -o {output_image} -b transparent'
        
        try:
            subprocess.run(cmd.split(), check=True, capture_output=True)
            image_paths.append((match.start(), match.end(), output_image))
            print(f"  ✓ 다이어그램 {i+1} 변환 완료")
        except subprocess.CalledProcessError as e:
            print(f"✗ 다이어그램 {i+1} 변환 실패: {e}")
        
        # 임시 파일 삭제
        if os.path.exists(temp_mmd):
            os.remove(temp_mmd)
    
    return image_paths

def replace_mermaid_with_images(md_file, image_paths, output_file):
    """Mermaid 코드 블록을 이미지 링크로 교체"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 역순으로 교체 (인덱스 변경 방지)
    for start, end, image_path in reversed(image_paths):
        # 절대 경로 사용 (Pandoc이 이미지를 찾을 수 있도록)
        abs_path = os.path.abspath(image_path)
        # Windows 경로를 Unix 스타일로 변환 (WSL 환경 고려)
        abs_path = abs_path.replace('\\', '/')
        # WSL에서 Windows 경로를 마운트 경로로 변환
        if abs_path.startswith('/mnt/'):
            pass  # 이미 WSL 경로
        elif ':' in abs_path:
            # Windows 경로인 경우 (D:/works/...)
            drive_letter = abs_path[0].lower()
            abs_path = f'/mnt/{drive_letter}{abs_path[2:]}'
        
        image_markdown = f'![Mermaid Diagram]({abs_path})'
        content = content[:start] + image_markdown + content[end:]
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return output_file

def preprocess_markdown_for_cover(md_file, output_file):
    """표지 페이지 처리를 위해 마크다운 전처리"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # HTML div의 page-break-after를 처리하기 위해
    # Pandoc의 raw LaTeX 블록을 사용하여 명시적으로 페이지 나누기 추가
    import re
    
    # page-break-after: always를 가진 div 뒤에 LaTeX 페이지 나누기 추가
    # Pandoc은 HTML을 LaTeX로 변환할 때 HTML div를 처리하지만,
    # page-break-after를 제대로 처리하지 못할 수 있으므로 명시적으로 추가
    pattern = r'(<div style="page-break-after: always;"></div>\n)'
    
    def replace_break(match):
        # LaTeX 명령을 raw LaTeX 블록으로 추가 (Pandoc이 이를 LaTeX로 직접 삽입)
        return match.group(1) + '\n```{=latex}\n\\clearpage\n```\n\n'
    
    content = re.sub(pattern, replace_break, content)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    return output_file

def convert_markdown_to_pdf(md_file, output_pdf, image_dir=None, theme='default'):
    """마크다운을 PDF로 변환"""
    # 이미지 경로를 위한 리소스 경로 추가
    md_dir = os.path.dirname(os.path.abspath(md_file))
    if image_dir:
        image_dir = os.path.dirname(os.path.abspath(image_dir))
    else:
        image_dir = md_dir
    
    # 마크다운 파일 전처리 (표지 페이지 처리)
    import tempfile
    preprocessed_md = tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False, encoding='utf-8')
    preprocessed_md.close()
    preprocessed_md_path = preprocess_markdown_for_cover(md_file, preprocessed_md.name)
    
    # 임시 폰트 디렉토리 변수 초기화
    temp_font_dir = None
    
    # KoPub 폰트 파일 경로 찾기
    script_dir = os.path.dirname(os.path.abspath(__file__))
    font_dir = os.path.join(script_dir, 'font', 'KoPub')
    kopub_dotum_medium = os.path.join(font_dir, 'KoPub Dotum Medium.ttf')
    kopub_dotum_bold = os.path.join(font_dir, 'KoPub Dotum Bold.ttf')
    kopub_dotum_light = os.path.join(font_dir, 'KoPub Dotum Light.ttf')
    
    # 폰트 파일 경로를 절대 경로로 변환하고 백슬래시를 슬래시로 변환 (LaTeX 호환)
    def normalize_path(path):
        abs_path = os.path.abspath(path)
        # Windows 경로를 LaTeX 호환 형식으로 변환
        return abs_path.replace('\\', '/')
    
    # 임시 LaTeX 헤더 파일 생성 (줄간격, 표지 페이지, KoPub 폰트 설정)
    header_file = tempfile.NamedTemporaryFile(mode='w', suffix='.tex', delete=False, encoding='utf-8')
    header_file.write('\\usepackage{setspace}\n')
    header_file.write('\\setstretch{1.2}\n')  # 1.2배 줄간격 (살짝 넓게)
    header_file.write('\\usepackage{geometry}\n')
    header_file.write('\\usepackage{fontspec}\n')
    
    # KoPub 폰트 파일이 존재하는 경우 사용
    if os.path.exists(kopub_dotum_medium):
        # 임시 디렉토리에 공백 없는 이름으로 폰트 파일 복사
        # 출력 폴더 내부에 폰트 디렉토리 생성 (한글 없는 경로 사용)
        import shutil
        import hashlib
        output_dir_for_fonts = os.path.dirname(os.path.abspath(output_pdf))
        # 한글 파일명을 해시로 변환하여 경로 문제 방지
        pdf_basename = os.path.basename(output_pdf).replace('.pdf', '')
        pdf_hash = hashlib.md5(pdf_basename.encode('utf-8')).hexdigest()[:8]
        temp_font_dir = os.path.join(output_dir_for_fonts, f'temp_fonts_{pdf_hash}')
        os.makedirs(temp_font_dir, exist_ok=True)
        kopub_medium_temp = os.path.join(temp_font_dir, 'KoPubDotumMedium.ttf')
        kopub_bold_temp = os.path.join(temp_font_dir, 'KoPubDotumBold.ttf')
        kopub_light_temp = os.path.join(temp_font_dir, 'KoPubDotumLight.ttf')
        
        # 원본 폰트 파일 확인
        print(f"  원본 폰트 파일 확인:")
        print(f"    Medium: {kopub_dotum_medium}")
        if os.path.exists(kopub_dotum_medium):
            file_size = os.path.getsize(kopub_dotum_medium)
            print(f"    ✓ 존재함 (크기: {file_size} bytes)")
        else:
            print(f"    ✗ 없음")
        
        # 폰트 파일 복사
        try:
            shutil.copy2(kopub_dotum_medium, kopub_medium_temp)
            if os.path.exists(kopub_dotum_bold):
                shutil.copy2(kopub_dotum_bold, kopub_bold_temp)
            if os.path.exists(kopub_dotum_light):
                shutil.copy2(kopub_dotum_light, kopub_light_temp)
            
            # 복사된 파일 확인
            print(f"  복사된 폰트 파일 확인:")
            if os.path.exists(kopub_medium_temp):
                copied_size = os.path.getsize(kopub_medium_temp)
                print(f"    ✓ Medium 복사됨: {kopub_medium_temp} (크기: {copied_size} bytes)")
            else:
                print(f"    ✗ Medium 복사 실패")
            
            if os.path.exists(kopub_medium_temp):
                # 임시 폰트 디렉토리 경로 정규화
                temp_font_dir_normalized = normalize_path(temp_font_dir)
                
                # 폰트 파일의 전체 경로 (공백 없음)
                kopub_medium_full_path = os.path.join(temp_font_dir_normalized, 'KoPubDotumMedium.ttf')
                kopub_bold_full_path = os.path.join(temp_font_dir_normalized, 'KoPubDotumBold.ttf')
                kopub_light_full_path = os.path.join(temp_font_dir_normalized, 'KoPubDotumLight.ttf')
                
                # LaTeX fontspec에서 전체 경로를 직접 지정 (가장 확실한 방법)
                # 경로를 LaTeX에서 안전하게 처리하기 위해 백슬래시를 슬래시로 변환
                temp_font_dir_tex = temp_font_dir_normalized.replace('\\', '/')
                
                # 전체 경로를 중괄호로 감싸서 LaTeX에 전달
                kopub_medium_path_tex = '{' + kopub_medium_full_path.replace('\\', '/') + '}'
                kopub_bold_path_tex = '{' + kopub_bold_full_path.replace('\\', '/') + '}' if os.path.exists(kopub_bold_temp) else None
                kopub_light_path_tex = '{' + kopub_light_full_path.replace('\\', '/') + '}' if os.path.exists(kopub_light_temp) else None
                
                if os.path.exists(kopub_bold_temp):
                    print(f"    ✓ Bold 복사됨")
                if os.path.exists(kopub_light_temp):
                    print(f"    ✓ Light 복사됨")
                
                # LaTeX 헤더에 폰트 설정 추가
                # \newfontfamily를 사용하여 폰트를 직접 로드 (더 안정적)
                # 폰트 파일을 헤더 파일과 같은 디렉토리에 복사하여 상대 경로 사용
                header_dir = os.path.dirname(header_file.name)
                font_copy_dir = os.path.join(header_dir, 'fonts')
                os.makedirs(font_copy_dir, exist_ok=True)
                
                # 헤더 파일과 같은 디렉토리에 폰트 파일 복사
                kopub_medium_header = os.path.join(font_copy_dir, 'KoPubDotumMedium.ttf')
                kopub_bold_header = os.path.join(font_copy_dir, 'KoPubDotumBold.ttf')
                kopub_light_header = os.path.join(font_copy_dir, 'KoPubDotumLight.ttf')
                
                shutil.copy2(kopub_medium_temp, kopub_medium_header)
                if os.path.exists(kopub_bold_temp):
                    shutil.copy2(kopub_bold_temp, kopub_bold_header)
                if os.path.exists(kopub_light_temp):
                    shutil.copy2(kopub_light_temp, kopub_light_header)
                
                # 상대 경로 사용 (헤더 파일 기준)
                kopub_medium_rel = 'fonts/KoPubDotumMedium.ttf'
                kopub_bold_rel = 'fonts/KoPubDotumBold.ttf' if os.path.exists(kopub_bold_temp) else None
                kopub_light_rel = 'fonts/KoPubDotumLight.ttf' if os.path.exists(kopub_light_temp) else None
                
                header_file.write('\\newfontfamily\\mainfont{KoPubDotum}[\n')
                header_file.write(f'  UprightFont={{{kopub_medium_rel}}},\n')
                if kopub_bold_rel:
                    header_file.write(f'  BoldFont={{{kopub_bold_rel}}},\n')
                if kopub_light_rel:
                    header_file.write(f'  ItalicFont={{{kopub_light_rel}}},\n')
                header_file.write(']\n')
                
                header_file.write('\\setmainfont{KoPubDotum}[\n')
                header_file.write(f'  UprightFont={{{kopub_medium_rel}}},\n')
                if kopub_bold_rel:
                    header_file.write(f'  BoldFont={{{kopub_bold_rel}}},\n')
                if kopub_light_rel:
                    header_file.write(f'  ItalicFont={{{kopub_light_rel}}},\n')
                header_file.write(']\n')
                
                header_file.write('\\setsansfont{KoPubDotum}[\n')
                header_file.write(f'  UprightFont={{{kopub_medium_rel}}},\n')
                if kopub_bold_rel:
                    header_file.write(f'  BoldFont={{{kopub_bold_rel}}},\n')
                header_file.write(']\n')
                
                print(f"  → KoPub 폰트 사용: {os.path.basename(kopub_dotum_medium)}")
                print(f"  → LaTeX에서 사용할 경로: {kopub_medium_full_path}")
                
                # 실제 파일 접근 가능 여부 확인
                if os.access(kopub_medium_full_path, os.R_OK):
                    print(f"  → ✓ 파일 읽기 권한 확인됨")
                else:
                    print(f"  → ✗ 파일 읽기 권한 없음")
            else:
                print(f"  ✗ 폰트 파일 복사 실패")
                shutil.rmtree(temp_font_dir, ignore_errors=True)
                temp_font_dir = None
        except Exception as e:
            print(f"  ✗ 폰트 파일 복사 중 오류: {e}")
            import traceback
            traceback.print_exc()
            if temp_font_dir and os.path.exists(temp_font_dir):
                shutil.rmtree(temp_font_dir, ignore_errors=True)
            temp_font_dir = None
    else:
        # KoPub 폰트가 없으면 기본 폰트 사용
        header_file.write('\\setmainfont{NanumGothic}\n')
        print("  → KoPub 폰트를 찾을 수 없어 기본 폰트(NanumGothic) 사용")
    
    # 목차 전에 명시적으로 페이지 나누기 추가
    header_file.write('\\makeatletter\n')
    header_file.write('\\let\\oldtableofcontents\\tableofcontents\n')
    header_file.write('\\renewcommand{\\tableofcontents}{%\n')
    header_file.write('  \\clearpage%\n')
    header_file.write('  \\oldtableofcontents%\n')
    header_file.write('  \\clearpage%\n')
    header_file.write('}\n')
    header_file.write('\\makeatother\n')
    header_file.close()
    header_path = header_file.name
    
    # Pandoc 명령어 구성 (전처리된 마크다운 파일 사용)
    cmd = [
        'pandoc',
        preprocessed_md_path,  # 전처리된 마크다운 파일 사용
        '-o', output_pdf,
        '--pdf-engine=xelatex',  # 한글 지원
        '--variable', 'fontsize=12pt',  # 폰트 크기 (기본값보다 조금 더 크게)
        '--variable', 'geometry:margin=2cm',
        '--include-in-header', header_path,  # 줄간격 및 폰트 설정 포함
        '--toc',  # 목차 생성
        '--toc-depth=3',
        '--highlight-style=tango',
        '--resource-path', f'{md_dir}:{image_dir}',  # 이미지 경로 지정
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print(f"✓ PDF 생성 완료: {output_pdf}")
        # 임시 파일 삭제
        if os.path.exists(header_path):
            os.remove(header_path)
        if os.path.exists(preprocessed_md_path):
            os.remove(preprocessed_md_path)
        # 헤더 파일과 함께 복사된 폰트 디렉토리 정리
        header_dir = os.path.dirname(header_path)
        font_copy_dir = os.path.join(header_dir, 'fonts')
        if os.path.exists(font_copy_dir):
            import shutil
            shutil.rmtree(font_copy_dir, ignore_errors=True)
        # 임시 폰트 디렉토리 정리
        if temp_font_dir and os.path.exists(temp_font_dir):
            import shutil
            shutil.rmtree(temp_font_dir)
        return True
    except subprocess.CalledProcessError as e:
        print(f"✗ PDF 생성 실패: {e}")
        # 임시 파일 삭제
        if os.path.exists(header_path):
            os.remove(header_path)
        if os.path.exists(preprocessed_md_path):
            os.remove(preprocessed_md_path)
        # 헤더 파일과 함께 복사된 폰트 디렉토리 정리
        header_dir = os.path.dirname(header_path)
        font_copy_dir = os.path.join(header_dir, 'fonts')
        if os.path.exists(font_copy_dir):
            import shutil
            shutil.rmtree(font_copy_dir, ignore_errors=True)
        # 임시 폰트 디렉토리 정리
        if temp_font_dir and os.path.exists(temp_font_dir):
            import shutil
            shutil.rmtree(temp_font_dir)
        print("\n대안: LaTeX 대신 다른 PDF 엔진 사용 시도")
        # 대안: wkhtmltopdf 사용
        cmd_alt = [
            'pandoc',
            md_file,  # 원본 파일 사용
            '-o', output_pdf,
            '--pdf-engine=wkhtmltopdf',
        ]
        try:
            subprocess.run(cmd_alt, check=True)
            print(f"✓ PDF 생성 완료 (wkhtmltopdf): {output_pdf}")
            return True
        except:
            print("✗ PDF 생성 실패. doc/변환_가이드.md를 참고하세요.")
            return False

def main():
    """메인 함수"""
    import sys
    import argparse
    from datetime import datetime
    from glob import glob
    
    # 명령줄 인자 파싱
    parser = argparse.ArgumentParser(description='마크다운 파일을 PDF로 변환')
    parser.add_argument('-in', '--input-dir', type=str, default='doc',
                        help='입력 폴더 (기본값: doc)')
    parser.add_argument('-o', '--output-dir', type=str, default=None,
                        help='출력 폴더 (기본값: output_YYYYMMDD_HH-MM)')
    parser.add_argument('output', nargs='?', type=str, default=None,
                        help='출력 폴더 (하위 호환성을 위한 위치 인자)')
    
    args = parser.parse_args()
    
    # 출력 폴더 설정
    if args.output_dir:
        output_dir = args.output_dir
    elif args.output:
        output_dir = args.output
    else:
        # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
        output_dir = f"output_{datetime.now().strftime('%Y%m%d_%H-%M')}"
    
    # 입력 폴더 설정
    input_dir = args.input_dir
    
    # 출력 폴더 생성
    os.makedirs(output_dir, exist_ok=True)
    
    # 변환할 마크다운 파일 목록
    if os.path.isdir(input_dir):
        # 입력 폴더에서 모든 .md 파일 찾기
        md_files = sorted(glob(os.path.join(input_dir, '**', '*.md'), recursive=True))
        if not md_files:
            print(f"✗ 입력 폴더에 .md 파일이 없습니다: {input_dir}")
            sys.exit(1)
        use_custom_input = True
    else:
        # 기본 파일 목록 (하위 호환성)
        md_files = [
            'doc/서비스_기획서.md',
            'doc/화면_기능_정의서.md',
            'doc/화면_흐름도.md',
        ]
        use_custom_input = False
    
    print("=" * 50)
    print("마크다운 → PDF 변환 도구")
    if use_custom_input:
        print(f"입력 폴더: {input_dir}")
        print(f"  → {len(md_files)}개의 마크다운 파일을 찾았습니다")
    print(f"출력 폴더: {output_dir}")
    print("=" * 50)
    
    # 의존성 확인
    if not check_dependencies():
        sys.exit(1)
    
    print("\n변환 시작...")
    
    for md_file in md_files:
        if not os.path.exists(md_file):
            print(f"✗ 파일을 찾을 수 없습니다: {md_file}")
            continue
        
        print(f"\n처리 중: {md_file}")
        
        # 이미지 저장 디렉토리 (출력 폴더 내부)
        image_dir_path = os.path.join(output_dir, 'images')
        os.makedirs(image_dir_path, exist_ok=True)
        
        # 1. Mermaid 다이어그램을 이미지로 변환
        print("  → Mermaid 다이어그램 변환 중...")
        image_paths = convert_mermaid_to_images(md_file, image_dir_path)
        
        # 2. 마크다운 파일에서 Mermaid를 이미지 링크로 교체
        temp_md = os.path.join(output_dir, os.path.basename(md_file).replace('.md', '_temp.md'))
        if image_paths:
            replace_mermaid_with_images(md_file, image_paths, temp_md)
            md_to_convert = temp_md
        else:
            md_to_convert = md_file
        
        # 3. PDF로 변환 (출력 폴더에 저장)
        print("  → PDF 변환 중...")
        md_filename = os.path.basename(md_file).replace('.md', '.pdf')
        output_pdf = os.path.join(output_dir, md_filename)
        success = convert_markdown_to_pdf(md_to_convert, output_pdf, image_dir_path)
        
        # 임시 파일 정리
        if os.path.exists(temp_md):
            os.remove(temp_md)
        
        if success:
            print(f"  ✓ 완료: {output_pdf}")
        else:
            print(f"  ✗ 실패: {md_file}")
    
    print("\n" + "=" * 50)
    print("변환 완료!")
    print("=" * 50)

if __name__ == '__main__':
    main()

