#!/usr/bin/env python3
"""
여러 PDF 파일을 하나로 병합하는 Python 스크립트
"""
import sys
import os
from pathlib import Path

def merge_pdfs_pypdf2(pdf_files, output_file):
    """PyPDF2를 사용하여 PDF 병합"""
    try:
        from PyPDF2 import PdfMerger
        
        merger = PdfMerger()
        
        for pdf_file in pdf_files:
            if not os.path.exists(pdf_file):
                print(f"⚠ 파일 없음: {pdf_file}")
                continue
            
            print(f"  → 추가 중: {pdf_file}")
            merger.append(pdf_file)
        
        with open(output_file, 'wb') as output:
            merger.write(output)
        
        merger.close()
        return True
    except ImportError:
        print("✗ PyPDF2가 설치되지 않았습니다.")
        print("  설치: pip install PyPDF2")
        return False
    except Exception as e:
        print(f"✗ 병합 실패: {e}")
        return False

def merge_pdfs_pypdf(pdf_files, output_file):
    """PyPDF를 사용하여 PDF 병합 (PyPDF2의 후속 버전)"""
    try:
        import pypdf
        
        merger = pypdf.PdfMerger()
        
        for pdf_file in pdf_files:
            if not os.path.exists(pdf_file):
                print(f"⚠ 파일 없음: {pdf_file}")
                continue
            
            print(f"  → 추가 중: {pdf_file}")
            merger.append(pdf_file)
        
        with open(output_file, 'wb') as output:
            merger.write(output)
        
        merger.close()
        return True
    except ImportError:
        return False
    except Exception as e:
        print(f"✗ 병합 실패: {e}")
        return False

def main():
    """메인 함수"""
    import sys
    from datetime import datetime
    
    # 출력 폴더 설정
    if len(sys.argv) > 1:
        output_dir = sys.argv[1]
    else:
        # 현재 시각으로 폴더명 생성 (YYYYMMDD_HH-mm)
        output_dir = f"output_{datetime.now().strftime('%Y%m%d_%H-%M')}"
    
    # 출력 폴더 생성
    os.makedirs(output_dir, exist_ok=True)
    
    print("=" * 50)
    print("PDF 병합 도구")
    print(f"출력 폴더: {output_dir}")
    print("=" * 50)
    
    # 병합할 PDF 파일 목록 (출력 폴더에서 찾기)
    pdf_files = [
        os.path.join(output_dir, '서비스_기획서.pdf'),
        os.path.join(output_dir, '화면_기능_정의서.pdf'),
        os.path.join(output_dir, '화면_흐름도.pdf'),
    ]
    
    # 출력 파일명 (출력 폴더에 저장)
    output_file = os.path.join(output_dir, '윤이버스_한국어앱_서비스_기획서_전체.pdf')
    
    # 존재하는 파일만 필터링
    existing_files = []
    for pdf in pdf_files:
        if os.path.exists(pdf):
            existing_files.append(pdf)
            print(f"✓ 발견: {pdf}")
        else:
            print(f"⚠ 파일 없음: {pdf}")
    
    if not existing_files:
        print("✗ 병합할 PDF 파일이 없습니다.")
        sys.exit(1)
    
    print(f"\n병합할 파일: {len(existing_files)}개")
    print(f"출력 파일: {output_file}")
    
    # PyPDF 또는 PyPDF2 사용
    print("\n→ PDF 병합 중...")
    
    # 먼저 pypdf 시도 (최신 버전)
    if merge_pdfs_pypdf(existing_files, output_file):
        print(f"✓ PDF 병합 완료: {output_file}")
        file_size = os.path.getsize(output_file) / (1024 * 1024)  # MB
        print(f"  파일 크기: {file_size:.2f} MB")
        sys.exit(0)
    
    # PyPDF2 시도
    if merge_pdfs_pypdf2(existing_files, output_file):
        print(f"✓ PDF 병합 완료: {output_file}")
        file_size = os.path.getsize(output_file) / (1024 * 1024)  # MB
        print(f"  파일 크기: {file_size:.2f} MB")
        sys.exit(0)
    
    print("\n✗ PDF 병합 실패")
    print("다음 패키지 중 하나를 설치해주세요:")
    print("  pip install pypdf")
    print("  또는")
    print("  pip install PyPDF2")
    sys.exit(1)

if __name__ == '__main__':
    main()

