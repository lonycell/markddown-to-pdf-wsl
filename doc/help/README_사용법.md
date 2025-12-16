# PDF 변환 및 병합 스크립트 사용법

## 출력 폴더 설정

모든 스크립트는 출력 폴더를 커맨드라인 인자로 받을 수 있습니다.

### 사용법

```bash
# 출력 폴더 지정
./convert_to_pdf.sh output_folder

# 출력 폴더 미지정 (자동 생성: output_YYYYMMDD_HH-mm)
./convert_to_pdf.sh
```

## PDF 변환 스크립트

### Bash (Linux/WSL)

```bash
# 출력 폴더 지정
./convert_to_pdf.sh my_output

# 자동 폴더 생성 (예: output_20250115_14-30)
./convert_to_pdf.sh
```

### Python

```bash
# 출력 폴더 지정
python3 convert_to_pdf.py my_output

# 자동 폴더 생성
python3 convert_to_pdf.py
```

### PowerShell (Windows)

```powershell
# 출력 폴더 지정
.\convert_to_pdf.ps1 my_output

# 자동 폴더 생성
.\convert_to_pdf.ps1
```

## PDF 병합 스크립트

병합 스크립트는 변환 스크립트와 동일한 출력 폴더를 사용합니다.

### Bash

```bash
# 출력 폴더 지정 (변환 스크립트와 동일한 폴더)
./merge_pdfs.sh my_output

# 자동 폴더 생성
./merge_pdfs.sh
```

### Python

```bash
# 출력 폴더 지정
python3 merge_pdfs.py my_output

# 자동 폴더 생성
python3 merge_pdfs.py
```

### PowerShell

```powershell
# 출력 폴더 지정
.\merge_pdfs.ps1 my_output

# 자동 폴더 생성
.\merge_pdfs.ps1
```

## 전체 워크플로우 예시

### 1. PDF 변환

```bash
# 출력 폴더 지정하여 변환
./convert_to_pdf.sh output_20250115

# 결과:
# output_20250115/
#   ├── 서비스_기획서.pdf
#   ├── 화면_기능_정의서.pdf
#   ├── 화면_흐름도.pdf
#   └── images/
#       ├── diagram_0.png
#       ├── diagram_1.png
#       └── ...
```

### 2. PDF 병합

```bash
# 동일한 출력 폴더 지정하여 병합
./merge_pdfs.sh output_20250115

# 결과:
# output_20250115/
#   ├── 서비스_기획서.pdf
#   ├── 화면_기능_정의서.pdf
#   ├── 화면_흐름도.pdf
#   └── 윤이버스_한국어앱_서비스_기획서_전체.pdf  ← 병합된 파일
```

### 3. 자동 폴더 생성 사용

```bash
# 변환 (자동 폴더 생성: output_20250115_14-30)
./convert_to_pdf.sh

# 병합 (동일한 폴더명 사용)
./merge_pdfs.sh output_20250115_14-30
```

## 출력 폴더 구조

```
output_YYYYMMDD_HH-mm/
├── 서비스_기획서.pdf
├── 화면_기능_정의서.pdf
├── 화면_흐름도.pdf
├── 윤이버스_한국어앱_서비스_기획서_전체.pdf  (병합 후)
└── images/
    ├── diagram_0.png
    ├── diagram_1.png
    └── ...
```

## 주의사항

1. **병합 스크립트 실행 전**: 먼저 변환 스크립트를 실행하여 PDF 파일을 생성해야 합니다.
2. **폴더명 일치**: 병합 스크립트는 변환 스크립트와 동일한 출력 폴더를 지정해야 합니다.
3. **자동 폴더명**: 자동 생성된 폴더명은 실행 시각을 기반으로 하므로, 변환과 병합을 같은 세션에서 실행하는 것이 좋습니다.

## 예시: 한 번에 실행

```bash
# 1. 변환 (자동 폴더 생성)
OUTPUT_DIR=$(date +%Y%m%d_%H-%M)
./convert_to_pdf.sh "output_${OUTPUT_DIR}"

# 2. 병합 (동일한 폴더 사용)
./merge_pdfs.sh "output_${OUTPUT_DIR}"
```

또는:

```bash
# 변환
./convert_to_pdf.sh

# 생성된 폴더명 확인 후 병합
ls -d output_*
./merge_pdfs.sh output_20250115_14-30  # 실제 폴더명 사용
```

