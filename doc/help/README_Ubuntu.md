# Ubuntu에서 마크다운 → PDF 변환 가이드

## 빠른 시작

### 1. 필요한 도구 설치

```bash
# Pandoc 설치
sudo apt-get update
sudo apt-get install -y pandoc

# LaTeX 설치 (PDF 생성용)
sudo apt-get install -y texlive-xetex texlive-lang-korean

# 또는 전체 LaTeX 설치 (더 많은 폰트 지원)
# sudo apt-get install -y texlive-full

# Mermaid CLI 설치 (Node.js 필요)
# Node.js 설치 (nvm 사용 권장)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install node

# Mermaid CLI 설치
npm install -g @mermaid-js/mermaid-cli

# Python3 (이미 설치되어 있을 가능성 높음)
# sudo apt-get install -y python3
```

### 2. 스크립트 실행 권한 부여

```bash
chmod +x convert_to_pdf.sh
```

### 3. 스크립트 실행

```bash
./convert_to_pdf.sh
```

## 한글 폰트 설정

Ubuntu에서 한글이 제대로 표시되려면 한글 폰트가 필요합니다.

### Noto Sans CJK KR 설치 (권장)

```bash
sudo apt-get install -y fonts-noto-cjk
```

### 나눔고딕 설치 (선택사항)

```bash
# 나눔고딕 다운로드 및 설치
wget https://github.com/naver/nanumfont/releases/download/VER5.0/NanumFont_TTF_ALL.zip
unzip NanumFont_TTF_ALL.zip
sudo mkdir -p /usr/share/fonts/truetype/nanum
sudo cp NanumFont_TTF_ALL/*.ttf /usr/share/fonts/truetype/nanum/
sudo fc-cache -f -v
rm -rf NanumFont_TTF_ALL*
```

스크립트는 기본적으로 "Noto Sans CJK KR" 폰트를 사용합니다.
다른 폰트를 사용하려면 스크립트의 `--variable=CJKmainfont` 부분을 수정하세요.

## 문제 해결

### Mermaid CLI가 작동하지 않을 때

```bash
# Mermaid CLI 재설치
npm uninstall -g @mermaid-js/mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# 버전 확인
mmdc --version
```

### LaTeX 오류

```bash
# XeLaTeX 설치 확인
xelatex --version

# 설치되지 않은 경우
sudo apt-get install -y texlive-xetex
```

### 한글이 깨질 때

```bash
# 사용 가능한 한글 폰트 확인
fc-list :lang=ko

# 폰트 캐시 갱신
fc-cache -f -v
```

### Python3가 없을 때

```bash
sudo apt-get install -y python3
```

## 출력 파일

변환된 파일은 원본 마크다운 파일과 같은 디렉토리에 생성됩니다:
- `doc/서비스_기획서.pdf`
- `doc/화면_기능_정의서.pdf`
- `doc/화면_흐름도.pdf`

Mermaid 다이어그램 이미지는 `doc/images/` 디렉토리에 저장됩니다.

## 대안: Python 스크립트 사용

bash 스크립트 대신 Python 스크립트를 직접 사용할 수도 있습니다:

```bash
python3 convert_to_pdf.py
```

이 경우 `requirements.txt`의 패키지가 필요하지 않습니다 (스크립트 내에서만 사용).

