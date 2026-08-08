# 앱 아키텍처 문서 — 쉐도잉랩(ShadowingLab)

> 작성: app-developer · 대상: Flutter (iOS + Android) · 기준일: 2026-08-05(STT 폐기 반영 개정)
> 코드 위치: `_workspace/02_app_code/`
> 참고: `_workspace/00_input.md`(요구사항), `_workspace/01_ux_design.md`(UX 설계, ux-designer 작성)

## 2026-08-05 아키텍처 결정 — STT(AssemblyAI 등) 완전 폐기, 100% 로컬 문장분리로 전환

이전 버전(따라/TTARA)은 업로드된 음성/영상을 AssemblyAI 같은 유료 클라우드 STT로
전사(轉寫)해 문장을 자동 분리했다. **이 결정을 뒤집는다** — 무료/유료 어떤 사용자도
개발자에게 사용자당 과금이 발생하는 제3자 API를 트리거하지 않는 것이 확정 요구사항이
됐기 때문이다(00_input.md). 문장 분리는 이제 완전히 온디바이스에서 끝나고, 네트워크
호출이 전혀 없다:

1. **음성만 업로드**: 로컬 무음/일시정지 구간 감지로 문장 경계(`startMs`/`endMs`)만
   산출한다. `SentenceSegment.text`는 `null` — 전사 자체가 없다. STT 신뢰도라는 개념이
   없으므로 `confidence` 필드는 완전히 제거했다(가짜 신뢰도 값을 지어내지 않는다).
2. **영상 + 자막(SRT/VTT) 업로드**: 사용자가 함께 첨부한 자막 파일을 그대로 파싱한다
   (`core/utils/subtitle_parser.dart`) — 자막 큐의 타임스탬프가 문장 경계, 자막 텍스트가
   `SentenceSegment.text`가 된다. 순수 파일 파싱이며 AI가 아니다.

`SegmentationRepository`는 더 이상 "업로드 → 원격 job 생성 → 폴링/웹소켓" 같은 비동기
원격 파이프라인을 모델링하지 않는다(`registerLocalMedia`/`requestSegmentation`/
`watchJobStatus`가 모두 로컬 연산 기준으로 재정의됨). `SegmentationJobState`에서
`queued`/`partial` 같은 원격 job 상태를 제거했고, 실패 사유(`SegmentationFailureReason`)도
`unsupportedSubtitleFormat`/`noClearSilenceDetected`/`unknown`처럼 로컬에서 실제로 발생
가능한 것만 남겼다 — 예전의 `STT_VENDOR_ERROR` 같은 벤더 오류 개념은 사라졌다.

또한 음성이 어디로도 전송되지 않으므로 **STT 전송 동의 플로우 자체를 완전히 삭제**했다
(`stt_consent_sheet.dart` 삭제, `LearningSettings.sttConsentAcceptedAt` 필드 제거,
파일 업로드/설정 화면의 관련 UI 전부 제거).

라이브러리(PRO) 콘텐츠는 이 결정과 무관하다 — CNN/BBC 공식 자막/트랜스크립트를
그대로 사용하므로 애초에 STT가 필요 없었고, 지금도 텍스트가 항상 존재한다.

---

## 기술 스택

| 항목 | 선택 | 근거 |
|---|---|---|
| **프레임워크** | Flutter 3.x (iOS + Android 동시 출시) | 요구사항 명시 |
| **언어** | Dart 3.x (null-safety) | Flutter 표준 |
| **상태관리** | **Riverpod** (`flutter_riverpod`, 코드젠 없는 수동 Provider) | 학습 루프(#5)처럼 여러 위젯이 동일 상태(재생 단계/반복 횟수/진행률)를 구독해야 하는 요구가 많아 Provider보다 세분화된 재구독 제어가 쉽고, Bloc 대비 보일러플레이트가 적음. `riverpod_generator`/`freezed` 코드젠은 이번 스캐폴드에서 **의도적으로 배제** — `build_runner` 실행 없이도 즉시 컴파일 가능한 프로젝트를 유지하기 위함(엔티티는 수동 `copyWith`/`toJson`, 컨트롤러는 `StateNotifier`로 구현). 프로덕션 전환 시 코드젠 도입은 선택 사항으로 남겨둠. |
| **컨트롤러 패턴** | `StateNotifier` + `StateNotifierProvider` (상호작용 상태) / `StreamProvider`·`FutureProvider` (읽기 전용·파생 데이터) | Riverpod의 신규 `Notifier`/`AsyncNotifier` API 대신 안정성이 오래 검증된 `StateNotifier`를 표준으로 채택해 버전 호환 리스크를 낮춤 |
| **네비게이션** | `go_router` (`StatefulShellRoute.indexedStack`) | 3탭(홈/라이브러리/마이) 독립 스택 유지 + 딥링크 대응. 쉐도잉 학습 화면(#5)은 셸 바깥 풀스크린 라우트로 분리해 탭바 노출 차단 |
| **로컬 DB** | `shared_preferences` 기반 JSON 저장(`LocalKvStore`) — **스캐폴드 단계 한정** | 코드젠(Drift) 없이 즉시 동작해야 하는 제약상 채택. `MediaRepository`/`StatsRepository`/`SettingsRepository`/`SubscriptionRepository` 인터페이스로 격리되어 있어, 프로덕션 전환 시 Drift(SQLite) 또는 Isar로 **구현체만** 교체하면 됨(하단 "프로덕션 전환 체크리스트" 참고) |
| **네트워크/오디오** | `just_audio` + `just_audio_background`(백그라운드 재생), `file_picker`, `permission_handler`, `wakelock_plus` | UX 문서 "앱 개발자 전달 사항" 그대로 채택. 영상도 오디오만 추출 재생(화면엔 파형만 노출 — 성능/배터리 이점) |
| **DI** | Riverpod `Provider` 컨테이너 1개 (`presentation/providers/repository_providers.dart`) | 별도 DI 프레임워크(get_it 등) 없이 Riverpod 자체를 DI 컨테이너로 사용 — Repository 인터페이스 반환값만 교체하면 Fake→Remote 전환 가능 |

---

## 프로젝트 구조

```
lib/
├── main.dart                        — 앱 엔트리포인트, 테마/라우터 조립
├── core/                             — 공통 유틸, 상수, 테마, 인프라 서비스
│   ├── theme/                        — app_colors / app_typography / app_spacing / app_motion / app_theme
│   ├── constants/app_constants.dart  — 지원 포맷, 반복횟수 기본값 등 수치 상수
│   ├── error/failure.dart            — Failure 계층(NetworkFailure, SegmentationFailure 등 — 후자는
│   │                                    이제 로컬 무음감지/자막파싱 실패를 뜻함, 벤더 오류 아님)
│   ├── audio/audio_player_service.dart — just_audio 래핑, "문장 구간 재생" 도메인 개념 노출
│   ├── ads/ad_service.dart           — 광고 SDK 연동 지점(인터페이스 + NoOpAdService)
│   ├── permissions/permission_service.dart — 마이크/파일 권한 요청 래퍼
│   ├── router/app_router.dart        — go_router 라우팅 테이블
│   ├── utils/formatters.dart         — 시간/퍼센트 포맷 유틸
│   └── utils/subtitle_parser.dart    — SRT/VTT 파서(순수 파일 파싱, AI/네트워크 없음) — 문장분리의
│                                        "영상+자막" 경로 실 구현체
├── domain/                           — 엔티티, Repository 인터페이스(순수 Dart, Flutter 비의존)
│   ├── entities/                     — MediaItem, SentenceSegment(text는 nullable — 무음감지 결과는
│   │                                    텍스트 없음), LibraryContent(source 필드로 CNN/BBC 출처 표기),
│   │                                    SubscriptionStatus, UserStats, LearningSettings,
│   │                                    SegmentationJobStatus/SegmentationFailureReason 등
│   └── repositories/                 — MediaRepository, SegmentationRepository(로컬 전용으로 재정의),
│                                        LibraryRepository, SubscriptionRepository, StatsRepository,
│                                        SettingsRepository
├── data/                              — Repository 구현체 + 로컬 저장소 + 목 데이터
│   ├── local/local_kv_store.dart     — SharedPreferences JSON 저장 공통 래퍼
│   ├── mock/                         — FakeSegmentationRepository/FakeLibraryRepository용 샘플 데이터
│   │                                    (buildMockSubtitleSentences: 자막 있음 데모,
│   │                                    buildMockSilenceSegments: 무음감지 데모 — 텍스트 없음)
│   └── repositories/                 — Local*Repository(로컬 전용), Fake*Repository(API 연동 전 목업).
│                                        FakeSegmentationRepository는 자막 파싱과 무음감지 둘 다 실제
│                                        로직으로 동작함(2026-08-05(3차): `core/audio/silence_detector.dart`
│                                        로 실 amplitude 분석 도입 완료 — 번들 asset(샘플MP3) 경로만
│                                        예외적으로 기존 타이밍 시뮬레이션 유지).
└── presentation/                     — 화면(View) + 뷰모델(Controller) + 공통 위젯
    ├── providers/repository_providers.dart — DI 루트
    ├── common_widgets/                — 디자인 시스템 컴포넌트 라이브러리(아래 표). STT 동의
    │                                     시트(stt_consent_sheet.dart)는 2026-08-05 완전 삭제됨.
    ├── onboarding/
    ├── home/                          — #1~#4 (홈, 업로드, 문장 분리 중, 문장 분리 편집)
    ├── shadowing/                     — #5, #6 (쉐도잉 학습 — Tab1/Tab2 공용 위젯, 세션 요약)
    ├── library/                       — #7, #8 (라이브러리 홈, 콘텐츠 상세/Paywall)
    └── my/                            — #9~#12 (구독관리, 마이홈, 학습기록, 설정)
```

**레이어 규칙**: `presentation` → `domain` → `data`는 단방향 의존(`data`가 `domain` 인터페이스를 구현). `domain`은 Flutter SDK에 의존하지 않는 순수 Dart로 유지해 유닛 테스트 용이성을 확보.

---

## 화면별 구현 명세

| # | 화면명 | 파일 경로 | 뷰모델 | 주요 상태 | 데이터 소스 |
|---|---|---|---|---|---|
| 0 | 온보딩 | `presentation/onboarding/onboarding_screen.dart` | (StatefulWidget 로컬 상태) | 슬라이드 인덱스, 권한 결과 | `LocalKvStore`(완료 플래그), `PermissionService` |
| 1 | 홈(목록) | `presentation/home/home_screen.dart` | `home_controller.dart` (`homeMediaListProvider` Stream + `HomeController`) | 파일 목록, 스트릭 배지 | `MediaRepository.watchAll()`, `StatsRepository` |
| 2 | 파일 업로드 | `presentation/home/file_upload_screen.dart` | `upload_controller.dart` (`UploadController` StateNotifier) | idle/awaitingSubtitleDecision(영상만)/uploading/error, 진행률 | `SegmentationRepository.registerLocalMedia`, `MediaRepository.save` |
| 3 | 문장 분리 중 | `presentation/home/ai_analyzing_screen.dart` | `analyzing_controller.dart` (`AnalyzingController`, **non-autoDispose** — 백그라운드 진행 보장) | processing/succeeded/failed, 진행률 | `SegmentationRepository.requestSegmentation/watchJobStatus`(전부 로컬 연산 — 자막파싱/무음감지) |
| 4 | 문장 분리 편집 | `presentation/home/segmentation_review_screen.dart` | `segmentation_review_controller.dart` | 문장 리스트, 드래그/병합/분리/초기화 | `SegmentationRepository.getSegments/saveEditedSegments` |
| 5 | 쉐도잉 학습 | `presentation/shadowing/shadowing_screen.dart` | `shadowing_controller.dart` (`ShadowingController`, family: `mediaId+source`) | 재생 단계(listening/speaking/complete), 반복 도트, Hands-free | `SegmentationRepository`(local) 또는 `LibraryRepository`(PRO), `AudioPlayerService` |
| 6 | 학습 완료 요약 | `presentation/shadowing/session_summary_screen.dart` | (결과는 `LearningSessionResult`를 라우트 `extra`로 전달받음) | 세션 통계, 전면광고 슬롯 | `StatsRepository.recordSession` |
| 7 | 라이브러리 홈 | `presentation/library/library_home_screen.dart` | `library_controller.dart` (FutureProvider 모음) | 오늘의 뉴스/카테고리 목록, 구독 상태 | `LibraryRepository`, `SubscriptionRepository` |
| 8 | 콘텐츠 상세/Paywall | `presentation/library/content_detail_screen.dart` | — | 미리듣기, 잠금 여부 | `LibraryRepository.getContentDetail`, `PaywallSheet` |
| 9 | 구독 결제/관리 | `presentation/my/subscription_screen.dart` | — | 구독 상태(Paywall ↔ 관리 화면 분기) | `SubscriptionRepository` |
| 10 | 마이 홈 | `presentation/my/my_home_screen.dart` | `home_controller.dart`(통계 재사용) | 스트릭 요약, 구독 유도 카드 | `StatsRepository`, `SubscriptionRepository` |
| 11 | 학습 기록 상세 | `presentation/my/learning_history_screen.dart` | — | 8주 히트맵, 누적 통계 | `StatsRepository` |
| 12 | 설정 | `presentation/my/settings_screen.dart` | `learningSettingsProvider` (Stream) | 반복횟수/속도/Hands-free/테마/알림 | `SettingsRepository` |

---

## 공통 위젯 라이브러리 (`presentation/common_widgets/`)

UX 문서 "공통 위젯화 우선순위" 7종을 모두 구현 완료:

| 컴포넌트 | 파일 | 비고 |
|---|---|---|
| `SentenceCard` | `sentence_card.dart` | `list`(#4)/`learning`(#5) variant, Idle/Playing/Recording/Completed/Warning 상태. `segment.text == null`(무음감지 결과)일 때 전용 플레이스홀더("자막 없이, 듣고 따라 말해보세요") 표시 |
| `RepeatDotIndicator` | `repeat_dot_indicator.dart` | 스케일 팝 애니메이션, "N회 중 M회 완료" 접근성 요약 발화 |
| `WaveformPlayer` | `waveform_player.dart` | Compact/Expanded, seed 기반 결정적 pseudo-waveform(실 amplitude 데이터 연동 전 임시) |
| `BoundaryHandle` | `boundary_handle.dart` | 드래그 + `SemanticsAction` increase/decrease(스크린리더 대체 경로) |
| `PaywallSheet` | `paywall_sheet.dart` | #8/#9 공용, 구매 로딩/에러 인라인 처리 |
| `PrimaryButton`/`SecondaryButton` | `primary_button.dart` | Default/Pressed/Disabled/Loading |
| `TabScaffold` | `tab_scaffold.dart` | go_router `StatefulShellRoute` 결합, 홈 탭에서만 배너 광고 슬롯 노출 |

추가 구현: `ProBadge`, `EmptyState`, `SkeletonBox`/`SkeletonCardList`, `AppToast`.

---

## 상태 관리 설계

| 상태 | 타입/Provider | 초기값 | 변경 트리거 |
|---|---|---|---|
| 홈 파일 목록 | `StreamProvider<List<MediaItem>>` (`homeMediaListProvider`) | `[]` | `MediaRepository` CRUD 시 자동 방출 |
| 업로드 진행 | `StateNotifier<UploadState>` (`uploadControllerProvider`) | `idle` | 파일 선택 → (영상이면) 자막 첨부 여부 결정 → 로컬 등록 진행률 콜백 |
| 문장분리 진행 | `StateNotifier<AnalyzingState>` (`analyzingControllerProvider.family`, non-autoDispose) | `processing` | `SegmentationRepository` 로컬 처리(자막파싱/무음감지) 진행 상태 스트림 |
| 문장 편집 상태 | `StateNotifier<SegmentationReviewState>` (`segmentationReviewProvider.family`) | 로딩중 | 드래그/병합/분리/초기화 액션 |
| 쉐도잉 세션 | `StateNotifier<ShadowingSessionState>` (`shadowingControllerProvider.family<{mediaId,source}>`) | 로딩중 | 내부 async 루프(재생→대기→반복) + 사용자 제스처(스와이프/탭/롱프레스) |
| 구독 상태 | `StreamProvider<SubscriptionStatus>` (`subscriptionStatusProvider`) | `SubscriptionStatus.free` | 구매/해지/복원 |
| 학습 통계 | `StreamProvider<UserStats>` (`userStatsProvider`) | `UserStats()` | 세션 완료 시 `recordSession` |
| 학습 설정 | `StreamProvider<LearningSettings>` (`learningSettingsProvider`) | 기본값(반복 5회, 1.0x, Hands-free ON) | 설정 화면/옵션 시트에서 업데이트 |

**쉐도잉 학습 루프 상태머신** (`ShadowingController._runSentenceLoop`): `listening → (0.3s) → speaking → repeat 미도달 시 listening 복귀 / 도달 시 sentenceComplete → Hands-free ON이면 다음 문장 자동 진행, OFF면 수동 스와이프 대기`. 모든 비동기 단계는 세대(generation) 카운터로 가드해 사용자의 수동 스킵/이전/롱프레스 개입 시 안전하게 중단된다.

---

## 에러 처리 전략

| 에러 유형 | 처리 방식 | 사용자 피드백 |
|---|---|---|
| 로컬 파일 접근 오류(#2 등록) | `ValidationFailure`류 → 재시도 버튼 노출 | #2 인라인 에러 + "다시 선택" |
| 문장분리 실패(#3, 로컬) | `SegmentationFailure` + `SegmentationFailureReason`(`unsupportedSubtitleFormat`/`noClearSilenceDetected`/`unknown`) → `AnalyzingController.retry()` | #3 화면 에러 메시지("지원하지 않는 자막 형식이에요"/"뚜렷한 무음 구간을 찾지 못했어요") + 재시도 CTA + "수동으로 나누기" |
| 오디오 재생 실패 | `ShadowingController._playWithRetry` — 1회 자동 재시도 후 실패 시 토스트 | #5 인라인 토스트(`AppToast`) |
| 마이크 권한 거부 | `micGranted=false` → "따라 말하기" 단계를 자동으로 대기시간으로 대체 | #5 1회 안내 토스트, 학습 루프는 듣기 전용으로 정상 진행 |
| 파일 형식/용량 오류 | `ValidationFailure` | #2 인라인 에러 + "다른 파일 선택" |
| 결제 실패 | `PurchaseFailure` | #8/#9 인라인 에러 + 재시도 버튼(`PaywallSheet`) |
| 데이터 파싱 오류(로컬 캐시) | `LocalKvStore.getJson`에서 예외 시 `null` 반환 → 각 Repository가 기본값으로 폴백 | 화면은 Empty 상태로 정상 렌더(크래시 방지) |
| 인증 만료 | `AuthFailure` 정의(현재 로그인 기능 미구현 — 후순위) | 로그인 화면 이동(향후 구현) |

---

## 디자인 토큰 반영 방식

01_ux_design.md의 "디자인 시스템" 섹션을 `core/theme/` 5개 파일에 1:1 매핑:

- **컬러**: `app_colors.dart`에 Light/Dark 헥스값 상수화 → `app_theme.dart`의 `ColorScheme` + 커스텀 `ThemeExtension<AppSemanticColors>`(success/warning/proGold 등 ColorScheme에 없는 토큰)로 노출.
- **타이포그래피**: `app_typography.dart`에 Display/Headline/Title/Sentence/Body/Label/Caption 7종 `TextStyle` 정의. `fontFamily: 'Pretendard'`는 폰트 파일 미배치 시 시스템 폰트(SF Pro/Roboto)로 자동 폴백(pubspec.yaml 주석 참고 — 라이선스 파일 확보 후 활성화).
- **스페이싱**: `app_spacing.dart`에 8dp 그리드(xs~2xl), 화면 마진 20dp, 카드/버튼 radius, 최소 터치 타깃 48dp, 원형 CTA 72dp 상수화.
- **모션**: `app_motion.dart`에 트랜지션 표(스택 280ms easeOutCubic, 시트 220ms easeOut 등) + `AppMotion.reduceMotion` 플래그로 OS 모션감소 설정 실시간 반영(`main.dart` builder에서 매 프레임 동기화).
- **접근성**: `Semantics` 위젯으로 원형 CTA 동적 라벨("재생, 원어민 음성 듣기" ↔ "녹음 중, 따라 말하는 중"), 반복 도트 요약 발화, 경계 핸들 increase/decrease 대체 입력 경로를 구현.

---

## api-integrator에게 전달하는 Repository 인터페이스 목록

아래 인터페이스는 모두 `domain/repositories/`에 정의되어 있고, 현재 `data/repositories/Fake*`(또는 `Local*`) 구현체로 UI가 동작 중입니다. **인터페이스 시그니처를 유지한 채 구현체만 교체**하면 presentation 레이어는 수정할 필요가 없습니다(교체 지점은 `presentation/providers/repository_providers.dart` 한 곳).

### 1. `SegmentationRepository` — **100% 로컬, api-integrator가 서버로 교체할 대상 아님**
파일: `domain/repositories/segmentation_repository.dart` / 현재 구현: `data/repositories/fake_segmentation_repository.dart`

**2026-08-05 결정으로 STT(AssemblyAI 등) 완전 폐기** — 이 인터페이스는 더 이상 원격 API를
가정하지 않는다. api-integrator 관점에서 이 Repository 계열에 대응하는 REST 엔드포인트는
**없다** — 네트워크 호출 자체가 없기 때문이다. 아래 시그니처는 전부 로컬 파일 I/O ·
로컬 연산(자막 파싱/무음 감지) 기준이다:

```dart
Future<String> registerLocalMedia({
  required String localFilePath,
  required String fileName,
  String? subtitleFilePath, // 영상+자막 업로드 시에만 값 있음(SRT/VTT)
  required void Function(double progress) onProgress,
});
Future<String> requestSegmentation(String mediaId);
Stream<SegmentationJobStatus> watchJobStatus(String jobId); // 로컬 연산 진행률, 네트워크 폴링 아님
Future<List<SentenceSegment>> getSegments(String mediaId);
Future<void> saveEditedSegments(String mediaId, List<SentenceSegment> segments);
```

- `subtitleFilePath`가 있으면 `requestSegmentation`이 `core/utils/subtitle_parser.dart`로
  실제 SRT/VTT 파싱을 수행 — `SentenceSegment.text`가 채워진다.
- 없으면 로컬 무음/일시정지 구간 감지 경로를 타며, `SentenceSegment.text`는 `null`이다.
  2026-08-05(3차)부터 `core/audio/silence_detector.dart`(`audio_waveforms` 패키지로 실제
  파형 진폭 추출 + 임계값 이하 지속시간 기반 경계 판정)가 실제 기기 파일을 분석한다 —
  번들 asset 경로(샘플MP3 체험하기, 원래 발화 없는 무음 PCM 플레이스홀더)만 예외적으로
  기존 `buildMockSilenceSegments` 타이밍 시뮬레이션을 유지한다(`WaveformPlayer`의
  pseudo-waveform 표시는 이와 별개로 아직 시각화용 임의값 — 실 진폭 연동은 선택적 후속작업).
- 실패는 `SegmentationFailureReason`(`unsupportedSubtitleFormat`/`noClearSilenceDetected`/
  `unknown`)으로 분류된다. 예전의 `STT_VENDOR_ERROR` 같은 벤더/네트워크 오류 상태는 없다.

### 2. `LibraryRepository` — PRO 큐레이션 콘텐츠
파일: `domain/repositories/library_repository.dart` / 현재 구현: `data/repositories/fake_library_repository.dart`

```dart
Future<List<LibraryContent>> getTodayContent();
Future<List<LibraryCategory>> getCategories();
Future<Paginated<LibraryContent>> getContentByCategory(String categoryId, {String? cursor, int limit});
Future<LibraryContent> getContentDetail(String contentId);
Future<List<SentenceSegment>> getContentSegments(String contentId);
Future<void> cacheForOffline(String contentId);
Future<List<LibraryContent>> getCachedContent();
```
**`LibraryContent.audioUrl`(전체 재생) vs `previewAudioUrl`(30초 미리듣기)**: QA 교차검증(🔴-1)에서 두 값을 구분 없이 `previewAudioUrl` 하나로 겸용하고 있어 PRO 학습 시 30초 이후 재생이 깨지는 버그가 발견되어 수정 완료. `audioUrl`은 nullable(`String?`)로 서버가 **구독자에게만** 서명된 URL을 채워 응답하고 비구독자에게는 `null`을 반환하는 것을 전제로 한다(03_api_integration.md 5-1절, 15분 TTL 권장). `ShadowingController`는 학습 진입 시 `content.audioUrl ?? content.previewAudioUrl`로 폴백하며, `#8 콘텐츠 상세` 화면의 "30초 미리 듣기" 버튼은 항상 `previewAudioUrl`만 사용한다.

**`LibraryContent.source`(예: `"CNN"`/`"BBC"`)**: 큐레이션 콘텐츠가 CNN/BBC 데일리 뉴스에서
공식 자막/트랜스크립트를 그대로 활용해 만들어진다는 출처를 화면에 표기하기 위한 필드.
`fromJson`/`toJson`/`mockLibraryContent`에 이미 반영되어 있고, `#7 라이브러리 홈`과
`#8 콘텐츠 상세` 카드에 `'${content.source} · ...'` 형태로 노출 중이다. 이 콘텐츠는 STT를
쓴 적이 없으므로(공식 자막 기반) `getContentSegments`가 반환하는 `SentenceSegment.text`는
항상 채워져 있다(`buildMockSubtitleSentences` 재사용).

### 3. `SubscriptionRepository` — 구독/결제 검증
파일: `domain/repositories/subscription_repository.dart` / 현재 구현: `data/repositories/fake_subscription_repository.dart`

```dart
Future<SubscriptionStatus> getStatus();
Stream<SubscriptionStatus> watchStatus();
Future<SubscriptionStatus> purchase(SubscriptionPlanType plan);
Future<SubscriptionStatus> restorePurchases();
Future<void> cancel();
```
대응: 클라이언트 StoreKit/Play Billing(`in_app_purchase` 패키지 권장) → 영수증을 `POST /subscription/verify`로 서버 검증하는 2단계 흐름을 이 인터페이스 뒤로 캡슐화할 것.

**`cancel()`은 즉시 해지가 아니다**: QA 교차검증(🔴-4)에서 지적된 대로, iOS/Android 모두 서드파티 앱이 스토어 구독을 프로그래밍적으로 취소할 수 없다(03_api_integration.md 6-3절). `FakeSubscriptionRepository.cancel()`은 `url_launcher`로 네이티브 구독 관리 화면에 딥링크만 시도하고(iOS `https://apps.apple.com/account/subscriptions`, Android Play 구독 관리 URL) `SubscriptionStatus.isActive`는 바꾸지 않는다. 실제 해지 반영은 이후 Apple/Google 웹훅을 서버가 받아 `watchStatus()` 폴링으로 클라이언트에 전달되는 흐름이며, #9 화면 버튼 라벨도 "구독 해지" → "구독 관리(스토어로 이동)"로, 완료 안내도 "해지됐어요" → "스토어 화면에서 해지를 완료해주세요"로 수정 완료.

### 4. `MediaRepository` / `StatsRepository` / `SettingsRepository` — 로컬 전용(참고용)
현재 로컬(SharedPreferences) 구현으로 충분하나, 로그인 사용자 대상 서버 동기화(`GET /user/stats` 등)를 추가할 경우 이 인터페이스를 유지한 채 "로컬 우선 + 백그라운드 sync" 데코레이터로 확장 권장.

---

## 광고/구독 SDK 연동 지점 (실 SDK 연동은 범위 밖 — 인터페이스만 준비됨)

| 지점 | 위치 | 설명 |
|---|---|---|
| 배너 광고 | `core/ads/ad_service.dart` (`AdService.bannerAdWidget`) → `TabScaffold`에서 홈 탭에만 렌더 | 현재 `NoOpAdService`(플레이스홀더 박스) |
| 전면 광고 | `AdService.showInterstitial()` → `session_summary_screen.dart`(#6 진입 시 1회) | 학습 화면(#5)에는 **의도적으로 AdService 참조 자체가 없음** — 몰입 보호 원칙(01_ux_design.md) |
| 구독 결제 | `SubscriptionRepository.purchase()` → `PaywallSheet` | 위 "Repository 인터페이스 목록" 3번 참고 |

---

## store-manager에게 전달하는 필요 권한 목록

| 권한 | iOS | Android | 용도 | 필수/선택 |
|---|---|---|---|---|
| 파일/미디어 접근 | 시스템 문서 피커 사용(별도 Info.plist 권한 불요) | `READ_MEDIA_AUDIO`/`READ_MEDIA_VIDEO`(API 33+) 또는 `READ_EXTERNAL_STORAGE` | 로컬 음성/영상 업로드(#2) | 필수 |
| 마이크 | `NSMicrophoneUsageDescription` | `RECORD_AUDIO` | 쉐도잉 "따라 말하기" 녹음(#5) | **선택** — 거부 시 듣기 전용으로 자동 대체(`PermissionService`, `ShadowingController.micGranted`) |
| 알림 | `UNUserNotificationCenter` | `POST_NOTIFICATIONS`(API 33+) | 학습 리마인더(#12, 현재 UI만 존재·스케줄링 미구현) | 선택 |
| 인앱결제 | StoreKit | Google Play Billing | PRO 구독(#8/#9) | 필수(PRO 기능 한정) |
| 백그라운드 오디오 | `UIBackgroundModes: audio` | `FOREGROUND_SERVICE`(미디어 재생) | `just_audio_background` 알림 채널 재생 | 필수 |

(README.md에도 동일 표 포함 — `_workspace/02_app_code/README.md`)

---

## 우선순위 구현 현황

| 화면 | 상태 |
|---|---|
| 온보딩(#0) | 완전 구현 |
| 홈/업로드(#1, #2) | 완전 구현 |
| 문장 분리 중(#3) | 완전 구현(자막 파싱·무음감지 모두 실 로직 + 실패/재시도 경로 — 2026-08-05(3차)부터 무음감지도 `SilenceDetector`로 실제 amplitude 분석) |
| 문장 분리 편집(#4) | 완전 구현(드래그 경계조정, 병합, 분리, 초기화, 접근성 스테퍼 — 텍스트 없는 구간도 시간 기준으로 편집 가능) |
| 쉐도잉 학습(#5) | 완전 구현(원버튼 루프, Hands-free, 반복 도트, 스와이프, 롱프레스 프리뷰, Wakelock) |
| 학습 완료 요약(#6) | 완전 구현 |
| 라이브러리(#7, #8) | 완전 구현(카테고리/오늘의 뉴스, Paywall 연동) |
| 구독 Paywall/관리(#9) | 완전 구현 |
| 마이/학습기록/설정(#10~#12) | 완전 구현 |
| 실제 음성 녹음("방금 녹음한 음성", #2) | **스텁** — 토스트로 "준비 중" 안내만, 실 녹음 패키지(예: `record`) 연동 필요 |
| 알림 리마인더 스케줄링(#12) | **스텁** — 토글 UI만 존재, `flutter_local_notifications` 등 연동 필요 |
| "수동으로 나누기"(#3 완전 실패 대체 경로) | **스텁** — 현재 편집 화면으로 그대로 진입(로컬 처리라 대부분 성공하므로 실사용 빈도 낮음), 실제 수동 타임스탬프 입력 UI는 후속 작업 |

## 프로덕션 전환 체크리스트 (후속 작업)

1. `LibraryRepository`/`SubscriptionRepository`의 Fake 구현체를 실 API/SDK 연동 구현체로 교체(`repository_providers.dart` 수정). **`SegmentationRepository`는 대상이 아니다** — 2026-08-05 결정으로 이 기능은 서버로 옮기지 않고 로컬에 남는다.
2. ~~`FakeSegmentationRepository`의 무음/일시정지 구간 감지를 실 amplitude 분석으로 교체~~ **[2026-08-05(3차) 완료]** — `core/audio/silence_detector.dart` + `audio_waveforms` 패키지로 구현, Android 에뮬레이터 실기기 검증 완료(합성 테스트 오디오로 경계 정확도 확인, `just_audio_background` MediaItem 태그 필수 요구사항 관련 버그 발견·수정). 자막 파싱 경로(`core/utils/subtitle_parser.dart`)는 이미 실 로직이라 애초에 교체 불필요였음.
3. 로컬 저장소를 `shared_preferences` → Drift(SQLite)로 전환(문장 세그먼트처럼 레코드가 많은 데이터의 쿼리 성능 확보).
4. Pretendard 폰트 라이선스 파일 배치 + `pubspec.yaml` fonts 섹션 활성화.
5. `AdService` NoOp → 실 광고 SDK 구현체 연동.
6. `flutter create`로 네이티브 러너 생성 후 이 저장소의 `lib/`를 덮어쓰기(README.md 참고), 각 권한별 Info.plist/AndroidManifest 설정 추가.
