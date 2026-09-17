# ScreenPen (스크린펜)

강의, 발표, 온라인 세미나 중 화면 위에 바로 필기하고 주석을 남길 수 있는 가볍고 직관적인 화면 주석 도구입니다.  
**macOS** (Native Swift/AppKit) 및 **Windows** (Lightweight Transparent Overlay)를 모두 지원합니다.

---

## 🖥 1. macOS 설치 및 사용법

macOS에서는 메뉴 막대(Menu Bar) 아이콘과 화면 하단 플로팅 툴바로 동작합니다.

### 빠른 다운로드 및 실행
- 배포 패키지: `dist/ScreenPen-1.0.0.dmg` 또는 `dist/ScreenPen.app`
- DMG를 열고 `ScreenPen.app`을 `/Applications` 폴더로 드래그하여 설치한 후 실행합니다.

### 소스에서 직접 빌드 및 실행
```bash
# 1. 빌드 및 바로 실행
swift run ScreenPen

# 2. 로컬용 DMG 패키징 (.dmg 및 .app 생성)
./scripts/package-dmg.sh local
```
빌드된 파일은 `dist/ScreenPen.app` 및 `dist/ScreenPen-1.0.0.dmg`에 생성됩니다.

### macOS 단축키
- `Control` + `Option` + `1`: **펜 (Pen)** 토글
- `Control` + `Option` + `2`: **형광펜 (Highlighter)** 토글
- `Control` + `Option` + `3`: **스포트라이트 (Spotlight)** 토글
- `Control` + `Option` + `4`: **macOS 내장 화면 확대** 켜기/끄기
- `Control` + `Option` + `5`: **지우개 (Eraser)** 토글
- `Control` + `Option` + `~`: **전체 지우기 (Clear All)**
- `Control` + `Option` + `O`: **단축키 안내 오버레이** 표시/숨김
- `Escape` 또는 **드로잉 중 우클릭**: 일반 마우스 상태로 복귀

---

## 🪟 2. Windows 설치 및 사용법

Windows 환경에서는 별도의 무거운 런타임 없이 파이썬 기본 GUI 라이브러리를 통한 초경량 투명 오버레이로 즉시 동작합니다.

### 실행 방법
1. 저장소를 다운로드하거나 클론합니다:
   ```cmd
   git clone https://github.com/hyun2xyz/screenpen.git
   cd screenpen\windows
   ```
2. `run_windows.bat`을 더블클릭하거나 아래 명령어로 실행합니다:
   ```cmd
   python screenpen_windows.py
   ```

### 단일 .exe 파일로 만들기 (선택 사항)
```cmd
pip install pyinstaller
pyinstaller --noconsole --onefile windows/screenpen_windows.py -n ScreenPen
```
생성된 `dist/ScreenPen.exe` 파일 하나만으로 어느 Windows PC에서나 즉시 실행 가능합니다.

### Windows 단축키
- `Ctrl` + `Alt` + `1`: **펜 (Pen)**
- `Ctrl` + `Alt` + `2`: **형광펜 (Highlighter)**
- `Ctrl` + `Alt` + `3`: **스포트라이트 (Spotlight)**
- `Ctrl` + `Alt` + `5`: **지우개 (Eraser)**
- `Ctrl` + `Z`: **되돌리기 (Undo)**
- `Ctrl` + `Alt` + `~`: **전체 지우기 (Clear All)**
- `Escape` 또는 **우클릭**: 일반 클릭 모드로 복귀
- 화면 하단의 플로팅 툴바를 마우스로 드래그하여 원하는 위치로 이동할 수 있습니다.

---

## 📂 프로젝트 구조

```text
screenpen/
├── Package.swift               # macOS Swift Package 매니페스트
├── Sources/
│   ├── ScreenPen/             # AppKit 메뉴바, 툴바 및 화면 오버레이 구현체
│   └── ScreenPenCore/         # 펜 스트로크, 히스토리, 설정 비즈니스 로직
├── Tests/                      # 단위 테스트 (swift test 로 검증)
├── scripts/
│   ├── package-dmg.sh         # macOS .dmg 및 .app 자동 빌드 스크립트
│   └── create-dmg-layout.sh   # 파인더 설치 레이아웃 커스텀 스크립트
├── windows/
│   ├── screenpen_windows.py   # Windows 전용 투명 캔버스 오버레이 클라이언트
│   ├── run_windows.bat        # Windows 원클릭 실행 배치 파일
│   └── README_WINDOWS.md      # Windows 전용 상세 가이드
└── dist/                      # 빌드된 배포 산출물 (.dmg, .app)
```

---

## 📜 라이선스

이 프로젝트의 자체 코드는 자유롭게 강의 및 개인 작업에 활용하실 수 있습니다.  
커서 아이콘 출처 및 서드파티 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고하세요.
