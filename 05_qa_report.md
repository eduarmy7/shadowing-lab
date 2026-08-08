# QA 검증 보고서 — 쉐도잉랩(ShadowingLab, 구 따라/TTARA)

> 작성: qa-engineer · 기준일: 2026-08-05 (3차 검증 — STT/AssemblyAI 완전 폐기, 100% 로컬 문장분리 전환 아키텍처 피벗 대응)
> 검증 대상: `00_input.md`, `01_ux_design.md`(884행), `02_app_architecture.md` + `02_app_code/`(Dart 소스), `03_api_integration.md`(345행), `04_store_listing.md`(395행)
> 검증 방법: **이번 패스에서는 `flutter analyze`/`flutter pub get`을 실제로 실행했다** (`C:\src\flutter`, Flutter 3.44.8 · Dart 3.12.2 — 환경에 SDK가 설치되어 있었음). 결과는 2절 참고. 그 외에는 이전 패스와 동일하게 산출물 전수 정독 + 핵심/위험 코드 파일 직접 리딩 + 문서 간 교차 대조(grep 기반 전역 검색 포함)로 수행했다. **실기기/에뮬레이터 실행, 위젯/골든 테스트, 네트워크 패킷 캡처 검증(음성 미전송 실증)은 수행하지 않았다** — 아래는 정적 분석과 코드 리딩 기준의 판단이다.

---

## 종합 평가

- **배포 준비 상태**: 🟡 **수정 후 진행 (조건부)** — 코드 품질/교차정합성 관점에서는 🔴 없음. 다만 이 상태와 별개로, **CNN/BBC 프리미엄 콘텐츠의 저작권·라이선싱 문제(4-(d)절 미해결 비즈니스/법무 블로커)가 실제 출시를 막는 게이트로 이미 문서에 명시돼 있으며, 이 패스에서도 해결되지 않았고 해결 대상도 아니다.** 이 문서는 그 사실을 재확인만 하고 넘어간다(요청 사항 4).
- **총평**: 2026-08-05 STT(AssemblyAI) 완전 폐기 피벗은 코드/문서 전반에 걸쳐 **매우 깔끔하게 수행되었다** — `flutter analyze`가 실제로 통과했고(경미한 lint 2건+테스트 파일 미사용 import 1건뿐, 에러 0건), 남아있는 STT/AssemblyAI/confidence 언급은 전부 "왜 없앴는지"를 설명하는 주석뿐이며 죽은 코드나 깨진 import는 없다. STT 동의(Consent) 플로우는 코드베이스 전체에서 문자 그대로 흔적이 없다(grep 0건). 다만 (1) 샘플 체험 파일명에 "AI"라는 표현이 남아 있어 이번 피벗이 세운 "AI 암시 표현 금지" 원칙과 정면으로 충돌하는 점, (2) 라이브러리 목업 데이터의 절반(일상회화/비즈니스/여행 카테고리)이 CNN/BBC가 아닌 정체불명의 "ShadowingLab Originals"라는 출처로 채워져 있어 "PRO=CNN/BBC" 라는 확정 사항과 문서상 애매하게 충돌하는 점, (3) 이전 QA 패스에서 지적된 마이크 권한 상시 요청·store-listing 오픈이슈 라벨 뒤처짐 등 **이번 피벗과 무관한 기존 미해결 항목들이 그대로 남아있는 점**을 새로 확인했다.

---

## 1. STT/AssemblyAI 완전 폐기 피벗 — 5개 산출물 교차검증 결과

### ✅ 1-1. 두 갈래 문장분리 경로(무음감지 vs 자막파싱) — 5개 문서 + 코드 전부 일치

- `00_input.md`(35-39행), `01_ux_design.md`(285행 등), `02_app_architecture.md`(7-35행), `03_api_integration.md`(4절 전체) 모두 동일하게 "음성만 업로드→무음/일시정지 구간 감지, 텍스트 없음" / "영상+자막(SRT/VTT)→자막 그대로 파싱, 텍스트 있음" 두 경로만 존재한다고 서술하며 서로 모순이 없다.
- 코드: `upload_controller.dart`(`awaitingSubtitleDecision` 단계, 영상만 자막 여부를 물음), `file_upload_screen.dart`(`_SubtitleDecisionView`), `fake_segmentation_repository.dart`(`subtitleFilePath != null` 분기), `core/utils/subtitle_parser.dart`(실제 SRT/VTT 정규식 파서, AI/네트워크 없음)까지 문서와 1:1 대응. 실제로 동작하는 로직이며(자막 파싱은 진짜 파일 파싱, 무음감지는 타이밍 시뮬레이션이라는 스캐폴드 한계도 문서·코드 주석 양쪽에 동일하게 정직히 명시됨).

### ✅ 1-2. 음성만 업로드 시 텍스트 없음 — 일관됨

- `SentenceSegment.text`는 `String?`(nullable), `hasText` getter로 판별. `sentence_card.dart`가 `segment.hasText`로 분기해 목록형은 `'(자막 없음 · 듣고 따라 말하는 구간)'`(이탤릭 스타일), 학습형은 "자막 없이, 듣고 따라 말해보세요" 전용 플레이스홀더를 각각 노출 — 텍스트를 지어내지 않는다는 `02_app_architecture.md`/`01_ux_design.md` 원칙 그대로 구현됨.
- `mock_sentences.dart`의 `buildMockSilenceSegments`도 텍스트 필드를 아예 채우지 않아(주석에도 "STT 신뢰도 개념이 없으므로 confidence 값은 만들어내지 않는다" 명시) 데모 데이터 레벨에서도 원칙이 지켜짐.

### ✅ 1-3. `confidence` 필드 완전 제거 — 확인됨

- `SentenceSegment` 엔티티(생성자/`copyWith`/`fromJson`/`toJson`/`props` 전부)에 `confidence` 필드 자체가 없음. `lowConfidenceThreshold`/`needsReview` 류의 잔존 참조도 코드 전체에서 0건(grep 확인). `01_ux_design.md` 698행/843행도 "신뢰도(confidence) 배지는 더 이상 존재하지 않는다"로 정확히 반영.

### ✅ 1-4. STT 동의(Consent) 플로우 완전 삭제 — 확인됨(가장 깨끗하게 처리된 항목)

- `stt_consent_sheet.dart` 파일 자체가 없고, 어떤 파일도 이를 import하지 않음(grep 0건). `consent`/`동의` 문자열 전체 코드베이스 검색 결과 **0건** — 설정 화면(`settings_screen.dart`)에도 "AI 처리 동의 상태" 같은 잔존 UI 없음. `LearningSettings` 엔티티에도 `sttConsentAcceptedAt` 필드 없음. 이전 버전(2026-08-04)에 존재했던 이 UI/필드가 이번 피벗에서 **부작용 없이 정확히 삭제**되었음을 확인.

### ✅ 1-5. CNN/BBC 프리미엄 소싱 — 문서 간 일치, 단 코드 목업 데이터는 부분 불일치(아래 🟡 2 참고)

- `00_input.md`/`01_ux_design.md`/`03_api_integration.md`(5절)/`04_store_listing.md` 네 문서 모두 "PRO 콘텐츠 = CNN/BBC 데일리 뉴스, 공식 트랜스크립트 기반, AI 미사용"으로 서로 일치. `LibraryContent.source` 필드(`"CNN"`/`"BBC"`)가 `fromJson`/`toJson`/UI(`content_detail_screen.dart`, 라이브러리 홈)에 정확히 반영되어 출처 배지가 실제로 렌더링됨.
- 단, `mock_library_content.dart`의 목업 데이터 5건 중 2건("오늘의 뉴스" 카테고리)만 `source: 'CNN'`/`'BBC'`이고, 나머지 3건(일상회화/비즈니스/여행 카테고리 — "Ordering coffee like a local" 등)은 `source: 'ShadowingLab Originals'`라는 **어떤 문서에도 등장하지 않는 제3의 출처**로 채워져 있다. 상세는 🟡 2 참고.

### ✅ 1-6. 백엔드 축소(Segmentation=로컬 전용, Library/Subscription만 원격) — 확인됨

- `03_api_integration.md` 0절/4절이 명시적으로 "SegmentationRepository는 이 문서의 API 연동 대상이 아니다"라고 선언하고, `02_app_architecture.md`도 동일하게 "이 계열은 서버로 교체할 대상이 아니다"라고 반복 명시. 코드의 `repository_providers.dart`도 `segmentationRepositoryProvider`에만 "Fake→Real 교체 대상 아님" 주석이 달려 있고, 실제로 `Remote*` 구현체가 존재하는 건(아직 미구현이지만) `Library`/`Subscription` 두 개뿐이라는 설계 의도가 문서·코드 양쪽에서 일관되게 재확인됨.

---

## 2. `flutter analyze` / `flutter pub get` 실행 결과 (이번 패스에서 실제로 수행함)

**중요**: 이전 QA 패스들은 "Flutter SDK 미설치 환경이므로 미실행"이라고 명시했었다. **이번 환경에는 Flutter SDK가 실제로 설치되어 있었다**(`C:\src\flutter`, Flutter 3.44.8 · channel stable · Dart 3.12.2). 아래는 실제 실행 결과이며, 코드 리딩만으로 추정한 것이 아니다.

```
$ flutter pub get
Changed 113 dependencies! (성공, 에러 없음. 21개 패키지에 더 신버전이 있다는 정보성 메시지만 있음)

$ flutter analyze
Analyzing 02_app_code...
   info - '__'는 lowerCamelCase 식별자 규칙 위반 - lib/data/mock/mock_sentences.dart:58:15 (constant_identifier_names)
   info - '__'는 lowerCamelCase 식별자 규칙 위반 - lib/data/mock/mock_sentences.dart:58:15 (non_constant_identifier_names)
warning - 미사용 import 'package:flutter/material.dart' - test/widget_test.dart:1:8 (unused_import)
3 issues found. (20.9s)
```

- **컴파일 에러 0건.** 이번 피벗에서 변경된 모든 파일(엔티티, Repository, 컨트롤러, 화면 다수)이 실제로 컴파일되고 정적 분석을 통과함을 실측으로 확인했다 — 이전 QA 패스들의 "코드 리딩 기준으로는 문제없어 보이나 실기 미검증" 단서를 이번 항목에 한해 해제한다.
- 발견된 3건은 전부 사소함: `mock_sentences.dart:58`의 레코드 패턴 분해(`final (_, __, durMs) = ...`)에서 두 번째 자리표시자 `__`가 lowerCamelCase 린트에 걸린 info 2건(기능에 영향 없음, `_`로 바꾸면 해소), `test/widget_test.dart`의 미사용 import 1건(테스트 보일러플레이트, 기능 코드 아님). 🟢로 분류(아래 참고).
- **수행하지 않은 것**: 실기기/에뮬레이터 실행, 위젯 테스트 실행(`flutter test`), 네트워크 패킷 캡처로 "무음감지 경로에서 정말 네트워크 호출이 0건인지" 실증(01_ux_design.md 872행이 요청한 검증 항목) — 이번 패스는 정적 분석까지만 수행했다.

---

## 3. 코드 grep 결과 — 죽은 참조/잔존 흔적 점검

| 점검 대상 | 결과 |
|---|---|
| `AssemblyAI`, `stt_consent_sheet`, `SttProvider` 등 | 주석(왜 없앴는지 설명) 외 **0건**. 실제 참조/import 없음 |
| `confidence`, `lowConfidenceThreshold`, `needsReview` | 주석 외 **0건**. 엔티티 필드에서 완전 제거 확인 |
| `consent`, `동의` | **전체 0건** (주석 포함해서도 없음 — 가장 깨끗한 제거) |
| `stt_consent_sheet.dart` import | **0건** (파일 자체가 존재하지 않음, 깨진 import 없음) |
| 네트워크/AI 대기 뉘앙스가 남은 UI 카피 | 없음 — `ai_analyzing_screen.dart` "자동으로 문장을 나누고 있어요", `file_upload_screen.dart` "잠시만 기다려 주세요" 등 전부 로컬 처리에 맞게 수정됨. 단, 화면/파일/클래스 이름 자체(`ai_analyzing_screen.dart`, `AiAnalyzingScreen`, `analyzing_controller.dart`)에는 "AI"가 여전히 남아있음(사용자 비노출, 내부 명명 이슈일 뿐 — 🟢 참고) |

---

## 발견 사항

### 🔴 필수 수정
**없음.** 이번 피벗 관련 코드/문서 교차검증에서 배포를 막을 결함은 발견되지 않았다. (단, 종합평가에 명시한 CNN/BBC 저작권 블로커는 QA 코드결함이 아니라 이미 추적 중인 비즈니스/법무 게이트이며, 이 문서는 이를 해결 대상으로 다시 열지 않는다 — 요청 사항 4.)

### 🟡 권장 수정

1. **[코드, 신규 발견] 샘플 체험 파일명에 "AI" 표현이 남아 사용자에게 노출됨 — 피벗의 "AI 암시 금지" 원칙과 충돌**
   - 위치: `lib/presentation/home/home_controller.dart:48` — `fileName: '샘플: AI 인터뷰로 체험하기'`
   - 재현: 홈 화면 → "샘플로 체험하기" 선택 → 홈 파일 목록에 "샘플: AI 인터뷰로 체험하기"라는 파일명 카드가 노출됨.
   - 문제: `01_ux_design.md` 866행이 "스토어 설명/스크린샷 카피에 'AI가 문장을 나눠준다', 'AI 자막', '음성인식' 등 AI·STT를 암시하는 표현을 절대 사용하지 않는다 — 실제로는 기기 내 무음 감지 또는 자막 매칭"이라고 명시했고, `home_controller.dart` 자신의 주석(28-38행)도 "STT 완전 폐기 이후 이 앱 전체에 음성을 어딘가로 전송하는 흐름이 없다"고 강조한다. 그런데 정작 사용자가 보는 파일명 문자열 자체에는 "AI"가 그대로 남아있어, 실제로는 로컬 무음감지일 뿐인 처리를 AI 처리인 것처럼 암시한다.
   - 영향: 기능 결함은 아니지만, 이 피벗 전체가 세운 "허위 AI 암시 금지" 원칙(허위광고/심사 리스크 회피 목적)에 대한 예외가 코드에 남아있는 셈이다. 스토어 스크린샷 촬영 시 이 홈 화면이 노출되면 카피 검수를 통과하기 어렵다.
   - 제안: `'샘플: AI 인터뷰로 체험하기'` → `'샘플: 인터뷰 음성으로 체험하기'` 등으로 수정(app-developer).

2. **[코드↔문서, 신규 발견] 라이브러리 목업 데이터 5건 중 3건이 CNN/BBC가 아닌 미문서화 출처("ShadowingLab Originals")로 채워짐 — "PRO=CNN/BBC" 확정 사항과 애매하게 충돌**
   - 위치: `lib/data/mock/mock_library_content.dart` — `lib-101`~`lib-103`(카테고리: 일상회화/비즈니스/여행, "Ordering coffee like a local" 등)의 `source: 'ShadowingLab Originals'`
   - 근거: `00_input.md`("자체 콘텐츠 라이브러리 — 프리미엄 전용: CNN/BBC 뉴스에서 매일 1개씩")와 `04_store_listing.md`(PRO=CNN/BBC로 전면 브랜딩, 스토어 카피/키워드 전부 CNN/BBC 중심)는 PRO 콘텐츠를 사실상 "CNN/BBC 뉴스"로 좁게 정의한다. 반면 `01_ux_design.md`(83행 "Tab 2. 라이브러리 (PRO · CNN/BBC 공식 자막 기반 큐레이션)", 505행 "[일상회화][비즈니스][여행] 칩")는 같은 PRO 탭 안에 뉴스가 아닌 주제별 카테고리도 함께 두는 와이어프레임을 유지하고 있는데, CNN/BBC가 "커피 주문하기"나 "공항 스몰토크" 같은 회화 콘텐츠를 만들 리는 없으므로 이 카테고리들이 정말 CNN/BBC 소스인지 자체가 논리적으로 애매하다. 코드는 이 모순을 "ShadowingLab Originals"라는 제3의 출처를 만들어 조용히 봉합했지만, 이 출처는 `00_input.md`/`03_api_integration.md`/`04_store_listing.md` 어디에도 등장하지 않아 **저작권 리스크 분석(4-(d)절)에도 반영되지 않은 콘텐츠 소스**가 코드에만 존재하는 상태다.
   - 영향: (1) 실제 라이브러리 화면을 켜면 "PRO=CNN/BBC"라는 스토어 카피와 달리 절반 이상의 카드가 CNN/BBC가 아닌 콘텐츠라 마케팅 카피와 실제 화면이 불일치할 수 있음. (2) 이 미문서화 소스가 자체 제작 콘텐츠라면 그 자체의 저작권/성우 라이선스 문제가 04_store_listing.md 저작권 리스크 분석에서 아예 누락된 채로 있다는 뜻.
   - 제안: 둘 중 하나로 정리 필요(product/ux-designer 의사결정 사항) — (a) PRO 콘텐츠를 `00_input.md` 원문대로 "오늘의 뉴스(CNN/BBC)" 단일 카테고리로 좁히고 일상회화/비즈니스/여행 카테고리 칩과 해당 목업 데이터를 제거, 또는 (b) 이 비-뉴스 카테고리를 의도적으로 유지할 계획이라면 "ShadowingLab Originals"의 실체(자체 성우 녹음? 라이선스 프리 소스?)와 그 자체 저작권 상태를 00_input.md/04_store_listing.md에 명시적으로 추가.

3. **[문서, 기존·미해결] `04_store_listing.md` 오픈이슈 라벨이 실제 코드 상태보다 뒤처짐 — 이전 QA에서 지적된 것과 동일한 패턴이 재발**
   - 위치: `04_store_listing.md` 최하단 "참고 — 팀 간 확인 필요 사항(오픈 이슈)" — `"🔄 (진행 중) app-developer — '샘플 파일로 체험하기' 기능"` 항목
   - 근거: 코드 확인 결과 이 기능은 이미 완전히 구현되어 동작 중이다(`file_upload_screen.dart`의 "샘플로 체험하기" 옵션, `home_controller.dart.getOrCreateSampleMedia()`, `pubspec.yaml`의 `assets/sample/` 선언과 실제 파일 존재까지 확인됨). 그런데도 문서는 여전히 "진행 중/코드 반영 예정"으로 표기되어 있다.
   - 영향: 이전 QA 패스(2026-08-04)에서 정확히 같은 종류의 지적(🟡 4 — 오픈이슈 라벨이 실제보다 한 박자 뒤처짐)을 했었고, 이번 피벗 작업(store-manager가 04번 문서를 대폭 갱신함, 368→395행) 중에도 이 라벨은 갱신되지 않은 채 그대로 남아있다. 배포를 막을 사안은 아니지만, 문서 신뢰도 문제가 반복되고 있다.
   - 제안: store-manager가 이 항목을 "✅ (해결)"로 갱신.

4. **[코드, 기존·미해결] 마이크 권한을 온보딩에서 전체 사용자에게 무조건 요청 — 이번 피벗과 무관, 변경 없음**
   - 위치: `lib/presentation/onboarding/onboarding_screen.dart:66-80`(`_complete()`가 `requestMicrophone()`을 조건 없이 호출)
   - 근거: `permission_service.dart` 클래스 docstring은 "마이크 권한은 선택 기능이다"라고 명시하고, `04_store_listing.md` 3-4/3-5절도 "마이크는 선택 기능 활성화 시에만 사용 시점 요청"을 `[x]` 완료로 체크해 두었다. 그러나 실제 코드는 온보딩 마지막 슬라이드에서 마이크/미디어 권한을 **항상** 함께 요청한다(기능 활성화와 무관).
   - 재검증 결과: 이번 피벗은 이 파일을 건드리지 않았으므로 예상대로 변경 없음 — **여전히 미해결**, 문서(체크 완료)와 코드(상시 요청) 간 불일치도 그대로 남아있음.
   - 제안: (이전 QA와 동일) 온보딩에서 마이크 권한 요청 제거, "내 목소리 녹음/비교" 토글 활성화 시점으로 이동. 또는 문서 체크박스를 실제 상태에 맞게 되돌림.

5. **[코드, 기존·미해결] `Permission.mediaLibrary` API가 Android 세분화 미디어 권한과 실제로 매핑되는지 미확인**
   - 위치: `lib/core/permissions/permission_service.dart:18-22`
   - 재검증 결과: 이번 피벗과 무관한 파일이라 변경 없음 — 여전히 미확인 상태로 이월.

6. **[코드↔문서, 기존·미해결] `02_app_code/README.md`가 이번 피벗 이후에도 "AI가 문장을 잘라주는" 문구를 그대로 유지**
   - 위치: `README.md:3` — "AI가 문장을 잘라주는 영어 쉐도잉 학습 앱."
   - 근거: 이번 피벗에서 변경된 파일 목록(작업 설명에 명시된 목록)에 `README.md`는 포함되지 않았다 — 실제로 열람 결과 STT/AssemblyAI/동의 관련 언급은 없지만(그 부분은 원래도 없었음), 앱 전체를 소개하는 첫 문장이 "AI가 문장을 잘라준다"는 이제는 사실이 아닌 설명을 그대로 달고 있다(무음감지/자막파싱이지 AI 전사가 아님). `02_app_architecture.md`(1-35행)가 이 피벗을 앱 정체성 수준의 변경으로 서술하는 것과 대비된다.
   - 제안: app-developer가 README 첫 문단을 "무음 감지/자막 매칭으로 문장을 나누는" 등으로 수정.

### 🟢 참고 사항

1. **`flutter analyze` 실제 실행 결과 — 에러 0건, 사소한 lint 3건**(2절 참고). `mock_sentences.dart:58`의 `__` 식별자 lint 2건은 `_`로 바꾸면 즉시 해소, `test/widget_test.dart`의 미사용 import는 테스트 보일러플레이트 정리 시 함께 처리 권장.
2. **`segmentation_review_controller.dart:167` 주석이 "AI 결과로 초기화"라는 문구를 쓰지만, 실제 화면(`segmentation_review_screen.dart`)의 버튼 라벨은 "원래대로 초기화"로 이미 AI 암시가 없다** — 내부 주석만 오래된 표현이 남은 것으로 사용자 노출 없음, 사소한 주석 정리 권장.
3. **화면/클래스/파일명에 남은 "AI" 명명**(`ai_analyzing_screen.dart`, `AiAnalyzingScreen`, `analyzing_controller.dart`) — 코드 내부 식별자일 뿐 사용자에게 노출되지 않으므로 기능/카피 문제는 아니나, 향후 리팩터링 시 `SegmentationProgressScreen` 등으로 개명하면 이번 피벗의 취지와 더 일관될 것.
4. **샘플 오디오 asset은 여전히 45초 무음 PCM 플레이스홀더**(`pubspec.yaml` 주석에 명시) — 이전 QA에서 지적된 그대로 이월, 배포 전 실제 라이선스 명확한 영어 발화 샘플로 교체 필요(이번 피벗과 무관, app-developer 기존 액션 아이템 유지).
5. **CNN/BBC 저작권·라이선싱 리스크는 이미 정확히 추적되고 있음** — `04_store_listing.md` 4-(d)절, 최상단 요약, 오픈이슈 섹션 최상단에 반복 고정 게시되어 있고 `00_input.md`/`01_ux_design.md`/`03_api_integration.md`(5-0절)도 모두 "미해결"로 일관되게 표시한다. 이 문서는 요청 사항대로 이를 다시 풀려고 시도하지 않았으며, "추적 중, 여전히 열려 있음"만 확인한다.
6. **학습 화면(#5) 광고/알림 완전 미노출 원칙, 배너 광고 홈 탭 전용 렌더링** — 이번 피벗과 무관한 영역, 변경 없이 유지됨을 재확인(`shadowing_controller.dart` 108-111행 주석, `tab_scaffold.dart`).
7. **`LibraryContent.audioUrl`/`previewAudioUrl` 분기, `SubscriptionRepository.cancel()` 딥링크 동작** — 이전 QA 패스에서 해결 확인된 상태 그대로 유지됨(`shadowing_controller.dart:139`, `subscription_screen.dart` 딥링크 문구).
8. **`pubspec.yaml`에 STT/AssemblyAI 관련 패키지(예: 벤더 SDK, `dio` 등) 잔존 없음** — `flutter pub get` 성공, 오디오/파일/권한 관련 패키지만 존재.

---

## 정합성 매트릭스

| 검증 항목 | 상태 | 비고 |
|----------|------|------|
| 00_input.md ↔ 01_ux_design.md ↔ 02_architecture ↔ 03_api ↔ 04_store (STT 폐기 서술) | ✅ | 두 갈래 로컬 경로, confidence 제거, 동의 삭제 서술이 5개 문서 전부 일치 |
| UX 설계 ↔ 코드(무음감지/자막파싱 두 경로) | ✅ | `upload_controller.dart`/`fake_segmentation_repository.dart`/`subtitle_parser.dart`가 문서와 1:1 대응 |
| 코드 ↔ API 명세(SegmentationRepository 로컬 전용, Library/Subscription만 원격) | ✅ | `repository_providers.dart` 주석과 03번 문서 0/4/12절이 정확히 일치 |
| CNN/BBC 소싱(문서 간) | ✅ | 00/01/03/04 네 문서 서로 일치 |
| CNN/BBC 소싱(문서 ↔ 코드 목업 데이터) | ⚠️ | 목업 5건 중 3건이 미문서화 출처("ShadowingLab Originals")로 채워짐(🟡 2) |
| STT 동의(Consent) 삭제 | ✅ | 코드 전체 grep 0건, 가장 깨끗하게 제거됨 |
| confidence 필드 제거 | ✅ | 엔티티/문서 모두 일치 |
| AI 암시 카피 금지 원칙 ↔ 실제 UI 문자열 | ⚠️ | 화면 카피는 대부분 정리됨, 샘플 파일명 1건 잔존(🟡 1) |
| 02번 문서 트레이서빌리티 | ✅ | 이전 패스에서 지적된 스니펫/표 미반영 문제는 이번 전면 재작성으로 해소(구현현황 표·Repository 스니펫 모두 최신 시그니처) |
| store-listing 오픈이슈 라벨 정확성 | ⚠️ | 샘플 체험 기능 라벨이 여전히 뒤처짐(🟡 3, 이전 패스와 동일 패턴 재발) |
| 성능 | ✅ | 변경 없음(이번 피벗은 네트워크 제거 방향이라 오히려 리스크 감소) |
| 접근성 | ✅ | 변경 없음, `hasText` 분기의 텍스트-없음 플레이스홀더도 스크린리더 대체 텍스트 포함 확인 |
| 보안 | ✅ | 오디오 외부 전송 경로 자체가 코드상 존재하지 않음(HTTP 클라이언트 패키지도 미도입 상태) |
| 정적 분석(`flutter analyze`) | ✅ | 실제 실행 완료, 에러 0건(2절) |
| 마이크 권한 시점(기존 이월) | ❌ | 여전히 온보딩 상시 요청(🟡 4) |

---

## 테스트 커버리지

| 영역 | 점검 시나리오 수 | 통과 | 실패 | 차단/미수행 |
|------|---------|------|------|------|
| STT/AssemblyAI/동의 잔존 참조 grep | 5(AssemblyAI, consent, stt_consent_sheet import, confidence, 네트워크 대기 카피) | 5 | 0 | 0 |
| 두 갈래 문장분리 경로 문서↔코드 대조 | 4(무음감지/자막파싱/텍스트 nullable/실패사유 enum) | 4 | 0 | 0 |
| CNN/BBC 소싱 문서 간 일치 | 4개 문서 쌍 | 4 | 0 | 0 |
| CNN/BBC 소싱 문서↔코드 목업 데이터 일치 | 1 | 0 | 1(🟡 2) | 0 |
| 백엔드 축소(Segmentation 로컬/Library·Subscription만 원격) | 3 | 3 | 0 | 0 |
| 정적 분석(`flutter pub get`/`flutter analyze`) | 2 | 2(경미한 lint 3건 별도 집계) | 0 | 0 |
| AI 암시 카피 잔존 여부(화면 문자열 전수) | 1 | 0 | 1(🟡 1, 샘플 파일명) | 0 |
| 이전 QA 이월 항목(마이크 시점/mediaLibrary API/store 라벨) | 3 | 0 | 3(전부 이월 미해결) | 0 |
| 실기기 네트워크 미전송 실증(패킷 캡처) | 1 | 0 | 0 | 1(미수행 — 정적 분석 범위 밖) |
| 위젯/골든 테스트 실행(`flutter test`) | 1 | 0 | 0 | 1(미수행) |

---

## 최종 산출물 체크리스트

- [x] UX 설계 문서 완성(`01_ux_design.md`) — 이번 피벗 반영 완료(884행), 단 라이브러리 비-뉴스 카테고리 서술이 04번 문서와 애매하게 충돌(🟡 2)
- [x] 앱 코드 생성(`02_app_code/`) — `flutter analyze` 실제 통과(에러 0), STT 피벗 반영 정합성 양호
- [x] API 연동 설계 완성(`03_api_integration.md`) — 백엔드 축소 반영 완료
- [x] 스토어 메타데이터 준비(`04_store_listing.md`) — STT 리스크 해소 반영 완료, 단 오픈이슈 라벨 일부 뒤처짐(🟡 3)
- [ ] 개인정보처리방침 작성 — 여전히 목차 초안 단계, 법무 검토 필요(범위 밖, 배포 차단 아님)
- [x] `flutter analyze`/`flutter pub get` 실기 검증 — **이번 패스에서 실제 실행 완료**(2절), 에러 0건
- [ ] CNN/BBC 콘텐츠 저작권·라이선싱 클리어런스 — **미해결 비즈니스/법무 블로커, 이 문서 범위 밖(추적만 함)**
- [ ] 샘플 오디오 asset을 실제 라이선스 명확한 영어 발화 샘플로 교체(기존 이월)
- [ ] 마이크 권한 온보딩 상시 요청 → 사용 시점 요청으로 변경(기존 이월)

---

## 담당 에이전트별 잔여 요청 요약

- **app-developer**:
  1. 샘플 미디어 `fileName`에서 "AI" 표현 제거(🟡 1).
  2. `mock_library_content.dart`의 비-뉴스 카테고리(일상회화/비즈니스/여행) 처리 방향을 ux-designer/product와 협의 후 결정(🟡 2 — 삭제 또는 출처 명시).
  3. 온보딩 마이크 권한 상시 요청 → 사용 시점 요청 변경(🟡 4, 기존 이월).
  4. `Permission.mediaLibrary`의 Android 매핑 확인(🟡 5, 기존 이월).
  5. `README.md` 첫 문단 "AI가 문장을 잘라주는" 표현 수정(🟡 6).
  6. (선택) `mock_sentences.dart:58`의 `__` 식별자 린트 정리, `test/widget_test.dart` 미사용 import 정리(🟢 1).
  7. (선택, 배포 전 필수) 샘플 오디오를 실제 발화 샘플로 교체(🟢 4).
- **ux-designer**: 라이브러리 홈(#7)의 일상회화/비즈니스/여행 카테고리가 "PRO=CNN/BBC 공식 자막 기반"이라는 전면 브랜딩과 어떻게 공존하는지 명확화 — 유지한다면 해당 콘텐츠의 성격(자체 제작?)을 01_ux_design.md에 명시(🟡 2).
- **store-manager**: 오픈이슈 섹션의 "샘플 파일로 체험하기" 라벨을 "✅ (해결)"로 갱신(🟡 3). 라이브러리 비-뉴스 카테고리 관련 결정이 나면 저작권 리스크 분석(4-(d)절)에도 반영 필요(🟡 2 후속).
- **api-integrator**: 특이 조치 불필요 — 이번 피벗으로 담당 범위가 Library/Subscription 두 API로 명확히 축소되었고, 문서·코드 간 불일치 없음.
