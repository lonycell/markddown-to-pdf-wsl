#!/usr/bin/env python3
"""
임시 마크다운 파일의 이미지 경로를 수정하는 유틸리티
WSL 환경에서 Windows 경로를 올바르게 변환
"""
import os
import re
import sys

def fix_image_paths_in_markdown(md_file):
    """마크다운 파일의 이미지 경로를 절대 경로로 수정"""
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 이미지 링크 패턴 찾기
    pattern = r'!\[Mermaid Diagram\]\(([^)]+)\)'
    
    def replace_path(match):
        img_path = match.group(1)
        
        # 이미 절대 경로인 경우
        if os.path.isabs(img_path):
            abs_path = img_path
        else:
            # 상대 경로를 절대 경로로 변환
            md_dir = os.path.dirname(os.path.abspath(md_file))
            abs_path = os.path.abspath(os.path.join(md_dir, img_path))
        
        # Windows 경로를 Unix 스타일로 변환
        abs_path = abs_path.replace('\\', '/')
        
        # WSL 환경 감지 및 경로 변환
        if os.path.exists('/proc/version') and 'microsoft' in open('/proc/version').read().lower():
            # WSL 환경
            if ':' in abs_path and not abs_path.startswith('/mnt/'):
                # Windows 경로인 경우 (D:/works/...)
                drive_letter = abs_path[0].lower()
                abs_path = f'/mnt/{drive_letter}{abs_path[2:]}'
        
        return f'![Mermaid Diagram]({abs_path})'
    
    # 경로 교체
    new_content = re.sub(pattern, replace_path, content)
    
    # 파일 저장
    with open(md_file, 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"✓ 이미지 경로 수정 완료: {md_file}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("사용법: python3 fix_image_paths.py <markdown_file>")
        sys.exit(1)
    
    fix_image_paths_in_markdown(sys.argv[1])

