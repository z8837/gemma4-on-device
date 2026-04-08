# Gemma4 On-Device Studio

`on_device_ai_project`는 Flutter와 `flutter_gemma`를 사용해 만든 온디바이스 Gemma 4 멀티모달 실험 앱입니다. 앱 안에서 Gemma 4 모델을 다운로드하거나 로컬 `.litertlm` 파일을 가져와 활성화할 수 있고, 텍스트·이미지·음성 입력을 하나의 채팅 화면에서 처리합니다.

모델 실행은 기기 로컬에서 이루어지며, 대화 기록과 사용자 설정도 로컬에 저장됩니다. 네트워크는 기본 프리셋 모델을 다운로드할 때만 필요합니다.

## 주요 기능

- Gemma 4 프리셋 모델 설치
  - `gemma4 E2B` (`2.4GB`)
  - `gemma4 E4B` (`4.3GB`)
- 로컬 `.litertlm` 모델 파일 가져오기
- 텍스트, 이미지, 음성 입력을 지원하는 채팅 UI
- 스트리밍 응답 표시 및 thinking 패널 표시 옵션
- GPU 우선 실행 옵션과 CPU 폴백
- 모델별 대화 기록 및 설정 로컬 저장
- 설치된 모델 목록 조회 및 즉시 전환

## 기술 스택

| 영역 | 사용 기술 |
| --- | --- |
| App framework | Flutter `3.38.8` |
| Language | Dart `3.10.7` |
| On-device LLM | `flutter_gemma` |
| State management | `flutter_riverpod` |
| Routing | `go_router` |
| File/Image input | `file_picker`, `image_picker` |
| Audio recording | `record`, `permission_handler` |
| Local persistence | `shared_preferences`, `path_provider`, `dart:io`, `dart:convert` |
| Android build | Kotlin `2.2.20`, AGP `8.11.1`, Java 17 |

## 지원 플랫폼

- Android
  - `minSdk 24`
  - `RECORD_AUDIO`, `INTERNET` 등 권한 사용
- iOS
  - `iOS 16.0+`
  - 마이크, 사진 접근 권한 사용


## 프로젝트 구조

```text
lib/
  main.dart                       # FlutterGemma 초기화, Riverpod 루트 설정
  app/
    app.dart                      # MaterialApp.router 구성
    router/
      app_router.dart             # 단일 스튜디오 페이지 라우팅
    theme/
      app_theme.dart              # 앱 테마
  core/
    utils/
      duration_formatter.dart     # 녹음 시간 formatter
  features/
    studio/
      application/
        studio_controller.dart    # 앱 핵심 상태 변경, 모델 제어, 입력 처리
        studio_state.dart         # UI 상태 모델
      data/
        gemma_runtime_service.dart        # flutter_gemma 래퍼, 모델 실행/활성화
        studio_persistence_repository.dart # 설정/대화 저장소
      domain/
        models/
          gemma_preset.dart       # 지원 프리셋 모델 정의
          studio_message.dart     # 채팅 메시지 모델
      presentation/
        pages/
          studio_page.dart        # 메인 화면
        widgets/
          chat_composer.dart
          chat_empty_state.dart
          chat_message_bubble.dart
          studio_drawer.dart
          transient_thinking_panel.dart
test/
  widget_test.dart                # GemmaPreset 기본 테스트
android/
ios/
```
