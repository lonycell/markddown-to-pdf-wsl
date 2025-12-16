# 마크다운 & Mermaid → PPT/PDF 변환 가이드

## 빠른 시작

### 방법 1: Python 스크립트 사용 (추천)

```bash
# 1. 필요한 패키지 설치
pip install -r requirements.txt

# 2. Mermaid CLI 설치 (Node.js 필요)
npm install -g @mermaid-js/mermaid-cli

# 3. PDF 변환
python convert_to_pdf.py

# 4. PowerPoint 변환
python convert_to_ppt.py
```

### 방법 2: PowerShell 스크립트 사용

```powershell
# 1. Pandoc 설치
choco install pandoc

# 2. Mermaid CLI 설치
npm install -g @mermaid-js/mermaid-cli

# 3. PDF 변환
.\convert_to_pdf.ps1
```

### 방법 3: VS Code 확장 프로그램 (가장 간단)

1. VS Code에서 다음 확장 설치:
   - **Markdown PDF**
   - **Mermaid Preview**

2. 마크다운 파일 열기
3. `Ctrl+Shift+P` → "Markdown PDF: Export (pdf)"

---

## 상세 가이드

자세한 내용은 `doc/변환_가이드.md`를 참고하세요.

---

## 문제 해결

### 한글이 깨질 때
- PDF: XeLaTeX 엔진 사용 (스크립트에 포함됨)
- PPT: 폰트 설정 확인

### Mermaid 다이어그램이 표시되지 않을 때
- Mermaid CLI가 설치되어 있는지 확인
- `mmdc --version` 명령어로 확인

### LaTeX 오류
- MiKTeX 또는 TeX Live 설치 필요
- 또는 `wkhtmltopdf` 사용 (스크립트에 대안 포함)

---

## 출력 파일

변환된 파일은 원본 마크다운 파일과 같은 디렉토리에 생성됩니다:
- `doc/서비스_기획서.pdf`
- `doc/서비스_기획서.pptx`
- `doc/화면_기능_정의서.pdf`
- `doc/화면_흐름도.pdf`

Mermaid 다이어그램 이미지는 `doc/images/` 디렉토리에 저장됩니다.

