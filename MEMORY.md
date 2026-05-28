# CamBar Memory

## 목적

재택근무 중이거나 바쁠 때 RTSP 홈캠을 빠르게 확인하는 macOS 메뉴바 앱.

핵심 UX는 `앱 실행 -> 메뉴바 아이콘 클릭 -> 바로 라이브 미리보기 확인`이다. 별도 큰 창을 여는 흐름보다 메뉴바 미리보기 안에서 대부분의 조작을 끝내는 방향이 맞다.

## 현재 방향

- 메뉴바 아이콘은 아기 얼굴 아이콘.
- 미리보기 패널은 메뉴바 바로 아래에 붙는 반투명 glass 스타일.
- 큰화면은 주 플로우에서 제거하는 방향.
- 미리보기 안에 필요한 조작을 모은다:
  - 탭 전환
  - 탭 추가
  - 탭 삭제
  - URL 수정
  - 재생
  - 음소거
  - 볼륨 조절
  - 새로고침/재연결
  - 앱 종료

## RTSP/Tapo 설정

Tapo 카메라는 보통 Tapo 앱에서 별도 camera account를 만들어야 RTSP가 열린다.

형식:

```text
rtsp://USERNAME:PASSWORD@CAMERA_IP:554/stream1
rtsp://USERNAME:PASSWORD@CAMERA_IP:554/stream2
```

- `stream1`: 보통 메인 고화질 스트림.
- `stream2`: 보통 저해상도/가벼운 스트림.
- VLC에서 먼저 열어보면 디버깅이 쉽다.
- 카메라 IP는 정적 IP 또는 공유기 DHCP 예약으로 고정하는 게 좋다.

## 구현 상태

- `CameraPopoverViewController`
  - 현재 핵심 화면.
  - 여러 카메라 URL별 `VLCMediaPlayer`를 캐시한다.
  - 탭 전환 시 이미 연결된 플레이어를 재사용하는 방향.
  - URL 필드는 메뉴바 패널 안에서도 편집/붙여넣기가 되도록 `FirstMouseTextField`를 사용한다.
  - 미리보기 안에 볼륨 슬라이더와 재연결 버튼이 있다.

- `AppDelegate`
  - 메뉴바 상태 아이템과 preview panel 관리.
  - preview panel은 `EditablePreviewPanel`.
  - 상태바 아이콘 hover/open highlight는 `StatusItemHoverController`가 관리한다.

- `CameraSettings`
  - camera streams, selected index, mute, volume, preview keep-alive 설정을 `UserDefaults`에 저장한다.

- `LargeCameraWindowController`
  - 아직 파일은 남아 있지만, 현재 제품 방향에서는 핵심 플로우가 아니다.
  - 정리할 때는 이벤트/Notification 의존성까지 같이 제거해야 한다.

## 최근 UX 결정

- 탭 이름 변경은 일단 보류.
- `+` 버튼은 새 탭을 `CAM1`, `CAM2`, `CAM3` 식으로 만든다.
- 탭 삭제는 탭 안의 `x`로 처리한다.
- 큰화면 버튼과 비디오 클릭 큰화면 진입은 제거하는 방향.
- 탭 선택/hover 색은 파란 macOS accent color를 피하고 기존 glass/green 톤을 유지한다.
- URL에는 실제 사용자 계정/비밀번호를 문서에 남기지 않는다.

## 빌드/재실행

```bash
cd CamBar
scripts/build_app.sh
pkill -f CamBar || true
open -n build/Manual/CamBar.app
pgrep -fl CamBar
```

## 검증 포인트

- 메뉴바 아이콘 hover/open highlight가 macOS 시스템 아이콘처럼 보이는지.
- 미리보기 URL 필드 클릭 후 수정/붙여넣기가 되는지.
- URL 수정 후 현재 탭에 저장되는지.
- 탭 전환 시 이미 연결된 스트림이 불필요하게 다시 connecting 되지 않는지.
- `+`로 새 탭이 생성되고 `x`로 삭제되는지.
- 미리보기 안에서 음소거, 볼륨, 재연결이 동작하는지.
- 앱을 닫았다 다시 열어도 설정이 유지되는지.

## 다음 정리 후보

- `LargeCameraWindowController` 제거 또는 feature flag 처리.
- `StreamStatus.largeCameraDidOpen` 이벤트 제거.
- 탭 rename 관련 죽은 코드 제거.
- 기본 카메라 URL이 개발자 개인 환경으로 하드코딩되어 있는지 점검하고 placeholder로 바꾸기.
