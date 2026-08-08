# QA 검증 보고서 — 쉐도잉랩(ShadowingLab)

> 작성: qa-engineer · 기준일: 2026-08-08 (4차 검증 — 라이브러리/구독 탭 전체 삭제 + 광고 제거 단발성 IAP 신규 도입 + 홈 화면 "고아(orphaned) 분석 작업" 감지 대응)
> 검증 대상: `00_input.md`, `01_ux_design.md`, `02_app_architecture.md` + `02_app_code/`·`ttara_runner/`(Dart 소스, 두 사본), `03_api_integration.md`, `04_store_listing.md`
> 검증 방법: `flutter analyze`/`flutter pub get`을 `ttara_runner`와 `02_app_code` 양쪽에서 실제로 실행(Flutter 3.44.8 · Dart 3.12.2), 두 `lib/` 트리 `diff -rq` 실측, 라이브러리/구독 잔존 참조 전수 grep, 5개 문서의 구체적 주장(가격/상품ID/탭 구조/프로바이더명/삭제 파일 목록)을 실제 코드와 1:1 대조, 구매 흐름·고아 분석 감지 로직 코드 리딩. **실기기/에뮬레이터 실행, `flutter test` 실행, 실제 프로세스 강제종료를 통한 고아 작업 재현은 수행하지 않았다** — 아래는 정적 분석과 코드 리딩 기준의 판단이다.

---

## 종합 평가

- **배포 준비 상태**: 🟢 **준비 완료** (경미한 문서 정합성 이슈만 잔존, 코드 결함 없음)
- **총평**: 라이브러리/구독 삭제 + 광고 제거 IAP 도입 리팩터는 코드 레벨에서 매우 깨끗하다 — `flutter analyze` 에러 0건(두 사본 모두 기존과 동일한 사소한 lint만), 죽은 참조·깨진 import 0건, 두 `lib/` 트리 완전 byte-identical(`l10n/gen/` 포함), 5개 문서의 가격(14,900원)·상품ID(`com.shadowinglab.remove_ads`)·프로바이더명·삭제 파일 목록(13개) 주장이 전부 코드와 정확히 일치한다. 구매 흐름(구매/복원/배너·전면광고 게이팅)과 고아 분석 감지 로직 모두 리뷰 결과 설계 의도대로 정확히 동작한다. 남은 문제는 전부 **문서 쪽**이다: (1) `01_ux_design.md`의 온보딩 슬라이드 3 와이어프레임이 이미 삭제된 CNN/BBC 콘텐츠를 여전히 홍보 문구로 남겨둔 신규 발견, (2) `04_store_listing.md` 오픈이슈가 `03_api_integration.md`에 이미 완료된 영수증 검증 엔드포인트 설계를 "미착수"로 잘못 표기(이전 QA에서 지적한 것과 동일한 "라벨 뒤처짐" 패턴 재발), (3) 마이크 권한 온보딩 상시 요청은 이번 작업과 무관하게 그대로 이월.

---

## 1. 라이브러리/구독 삭제 — 죽은 참조 grep 결과

`ttara_runner/lib`와 `02_app_code/lib` 양쪽 전수 검색(대소문자 무시).

| 검색어 | 결과 | 판정 |
|---|---|---|
| `library`/`Library` | `permission_service.dart`의 `requestMediaLibrary()`/`Permission.mediaLibrary` 3건(양쪽 동일) | ✅ 전부 오검출(미디어 라이브러리 **권한** API, 콘텐츠 라이브러리와 무관) |
| `subscription`/`Subscription` | `StreamSubscription` 3건(오디오/타이머 구독) + `fake_purchase_repository.dart`·`purchase_repository.dart`의 "구 `FakeSubscriptionRepository`/`SubscriptionRepository`(2026-08-08 제거)" 설명 주석 2건 | ✅ 전부 오검출 또는 삭제 설명 주석. 살아있는 참조·import 없음 |
| `PaywallSheet`/`ProBadge`/`proGold` | **0건** | ✅ 완전 제거 |
| 라우터(`app_router.dart`) | `/library` 브랜치, `/my/subscription` 라우트 없음. `StatefulShellRoute`가 홈/마이 2개 브랜치만 가짐 | ✅ |
| `pubspec.yaml`/에셋 | library/subscription/cnn/bbc 문자열 0건 | ✅ |

**삭제 파일 목록 실측(02_app_architecture.md가 명시한 13개)**: `library_home_screen.dart`, `library_controller.dart`, `content_detail_screen.dart`, `subscription_screen.dart`, `paywall_sheet.dart`, `pro_badge.dart`, `library_content.dart`, `subscription.dart`, `library_repository.dart`, `subscription_repository.dart`, `fake_library_repository.dart`, `fake_subscription_repository.dart`, `mock_library_content.dart` — **13개 전부 실제로 존재하지 않음을 확인**. 이전 QA(2026-08-05)가 지적했던 "`mock_library_content.dart`의 비-CNN/BBC 목업 데이터(ShadowingLab Originals)" 이슈는 파일 자체가 삭제되며 **자동으로 해소됨**.

---

## 2. `flutter analyze` / `flutter pub get` 실행 결과 (양쪽 모두 실제 실행)

```
$ (ttara_runner) flutter pub get   → Got dependencies! (에러 없음, 21개 패키지 구버전 정보성 메시지만)
$ (ttara_runner) flutter analyze
   info - '__'는 lowerCamelCase 위반 - lib\data\mock\mock_sentences.dart:58:15 (constant_identifier_names)
   info - '__'는 lowerCamelCase 위반 - lib\data\mock\mock_sentences.dart:58:15 (non_constant_identifier_names)
2 issues found. (4.8s)

$ (02_app_code) flutter pub get    → Got dependencies! (동일)
$ (02_app_code) flutter analyze
   info - '__'는 lowerCamelCase 위반 - lib\data\mock\mock_sentences.dart:58:15 (constant_identifier_names)
   info - '__'는 lowerCamelCase 위반 - lib\data\mock\mock_sentences.dart:58:15 (non_constant_identifier_names)
warning - 미사용 import 'package:flutter/material.dart' - test\widget_test.dart:1:8 (unused_import)
3 issues found. (2.7s)
```

- **컴파일 에러 0건, 요청된 기대 베이스라인과 정확히 일치**(`mock_sentences.dart:58` info 2건 + `02_app_code`에만 있는 `test/widget_test.dart` warning 1건).
- `02_app_code`와 `ttara_runner`의 `test/widget_test.dart`가 서로 다른 파일이라는 점을 실측 확인(3절 참고) — `unused_import` 차이는 이 때문이며, `lib/`의 정합성과는 무관.
- **수행하지 않은 것**: `flutter test` 실행, 실기기/에뮬레이터 실행, 실제 프로세스 강제종료를 통한 고아 분석 작업 재현.

---

## 3. `02_app_code/lib` ↔ `ttara_runner/lib` byte-identical 검증

```
$ diff -rq ttara_runner/lib/ 02_app_code/lib/
(출력 없음 — 완전 동일)
```

`l10n/gen/`을 포함해 **전체 68개 파일이 완전히 동일**함을 실측 확인(제외 옵션 없이 전체 diff에서도 차이 없음 — 두 프로젝트의 `l10n/gen/`도 우연히 동일 상태로 유지되고 있음). `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, `assets/`도 모두 동일.

유일한 차이는 `lib/` 바깥의 `test/widget_test.dart` 1개 파일(2절 참고) — `ttara_runner`는 구버전 스모크 테스트(`TtaraApp` 위젯 존재만 확인), `02_app_code`는 온보딩 화면 텍스트("건너뛰기")까지 확인하는 더 상세한 버전이며 `shared_preferences` import는 쓰지만 `flutter/material.dart` import는 쓰지 않아 `unused_import`가 발생한다. `lib/`가 소스오브트루스 동기화 대상이므로 이 차이는 요청 범위 밖이며 문제가 아니다.

---

## 4. 5개 문서 ↔ 코드 교차검증 — 구체적 주장 표본 대조

| 문서 주장 | 검증 방법 | 결과 |
|---|---|---|
| 광고 제거 IAP 가격 "14,900원" (5개 문서 전체) | `app_ko.arb`의 `adRemovalPrice` 실측 | ✅ `"14,900원"` 일치 |
| 상품 ID `com.shadowinglab.remove_ads` (00/02/03/04번 문서) | `PurchaseRepository.adRemovalProductId` 실측 | ✅ 정확히 일치 |
| "3탭→2탭(홈/마이), `/library`·`/my/subscription` 라우트 제거" (02_app_architecture.md) | `app_router.dart` 실측 | ✅ `StatefulShellRoute.indexedStack`이 `/home`, `/my` 브랜치 2개만 가짐 |
| 삭제 파일 13개 목록 (02_app_architecture.md) | 파일 존재 여부 실측 | ✅ 13개 전부 미존재 확인(1절) |
| `core/theme/` 5개 파일 1:1 매핑 (02_app_architecture.md) | `ls core/theme/` | ✅ 정확히 5개(`app_colors/motion/spacing/theme/typography.dart`) |
| 프로바이더명(`adsRemovedProvider`, `analyzingControllerProvider` 등, 02_app_architecture.md) | 코드 내 `final XProvider` 선언 전수 대조 | ✅ 문서가 언급한 프로바이더 전부 코드에 존재, 이름 불일치 없음 |
| `PurchaseRepository` 인터페이스 시그니처(03_api_integration.md 5-1절 코드 스니펫) | `purchase_repository.dart` 실측 | ✅ `watchAdsRemoved()`/`purchaseRemoveAds()`/`restorePurchases()` 시그니처까지 정확히 일치 |
| "AdService는 NoOpAdService 플레이스홀더"(04_store_listing.md 오픈이슈) | `ad_service.dart` 실측 | ✅ 정확 |
| "샘플 파일로 체험하기 기능 ✅ 해결"(04_store_listing.md) | `home_controller.dart`의 `getOrCreateSampleAudioMedia`/`getOrCreateSampleVideoMedia` 실측 | ✅ 실제로 구현되어 있고 라벨도 이미 해결로 갱신됨(이전 QA 지적사항 반영 확인) |
| README "AI가 문장을 잘라주는" 표현(이전 QA 🟡6) | `02_app_code/README.md` 실측 | ✅ **"자동으로 문장을 나눠주는"으로 수정 완료** — 이전 QA 지적사항 해소 확인 |
| 샘플 파일명의 "AI" 노출(이전 QA 🟡1) | `home_controller.dart`의 `fileName` 값 실측 | ✅ **"샘플 오디오 파일 (MP3)"/"샘플 영상 파일"로 수정 완료** — "AI" 표현 제거 확인 |
| 광고 제거 영수증 검증 엔드포인트 "미설계"(04_store_listing.md 오픈이슈, 381행) | `03_api_integration.md` 5-2절 실측 | ❌ **불일치 — 아래 🟡 1 참고** |
| 온보딩 슬라이드 3 "CNN·BBC 공식 자막" 홍보 문구(01_ux_design.md 158행) | 코드(`onboarding_screen.dart`, 전체 arb 파일)에 CNN/BBC 문자열 존재 여부 | ❌ **코드에는 없음(정상), 그러나 문서 와이어프레임 자체가 삭제된 기능을 여전히 홍보 — 아래 🟡 2 참고** |

---

## 5. 광고 제거 구매 흐름 코드 리뷰

대상: `purchase_repository.dart`, `fake_purchase_repository.dart`, `ad_removal_sheet.dart`, `my_home_screen.dart`, `tab_scaffold.dart`, `session_summary_screen.dart`, `purchase_providers.dart`, `local_kv_store.dart`.

- **영속성**: `FakePurchaseRepository`가 `LocalKvStore`(`shared_preferences` 래퍼, 실제로 기기 디스크에 영속)에 `ttara.ads_removed.v1` 키로 `bool`을 저장 → 앱 재시작 후에도 유지됨(인메모리가 아님, 실측 확인).
- **게이팅**: `adsRemovedProvider`(`StreamProvider.autoDispose`)가 단일 진실 소스. `tab_scaffold.dart`가 `navigationShell.currentIndex == 0 && !adsRemoved`로 배너를 **홈 탭 전용**으로 정확히 제한(마이 탭엔 애초에 렌더링 코드 자체가 없음). `session_summary_screen.dart`는 `initState`의 `addPostFrameCallback`에서 `watchAdsRemoved().first`를 1회 읽어 전면광고 트리거 여부를 결정 — 화면 진입 시점 스냅샷이면 충분한 일회성 게이트라 반응형일 필요가 없는 합리적 설계.
- **더블탭 방지**: `AdRemovalSheet`의 `_isPurchasing`/`_isRestoring` + `busy` 플래그로 구매/복원 버튼이 처리 중엔 `onPressed: null`로 비활성화됨 — 재빠른 연속 탭 시 두 번째 탭은 무시됨. ✅ 정상.
- **백그라운드 진입**: 900ms(구매)/500ms(복원)의 단순 `Future.delayed` 기반이라 앱이 일시정지(suspend)되어도 프로세스가 살아있는 한 Dart Future는 그대로 이어져 완료된다. 프로세스가 완전히 종료(kill)되면 미완료 구매는 유실되지만, 이는 Fake 스캐폴드의 한계이며 실제 StoreKit/Play Billing 전환 시 트랜잭션 큐 복구(`SKPaymentQueue` 등)로 대체되어야 할 지점 — `03_api_integration.md` 5-2절이 이미 이 필요성을 인지하고 웹훅/서버검증 설계를 남겨둠.
- **`restorePurchases()` 동작**: 실제로는 `_load()`를 호출해 **이미 메모리에 캐시된 값을 그대로 반환**할 뿐 — `watchAdsRemoved()`가 시트를 열기 전에 이미 최소 1회 로드해 `_cache`를 채워두므로, "복원" 버튼을 눌러도 로컬 상태가 바뀔 일이 사실상 없다(진짜 스토어 재조회가 없는 Fake 특성상 당연함). "재설치 후 복원" 시나리오는 이 Fake 구현으로는 재현 불가능(로컬 저장소 자체가 재설치 시 초기화되므로) — 실 StoreKit/Play Billing 연동 전까지는 QA가 이 경로를 의미 있게 테스트할 수 없다는 점을 인지할 필요. 🟢 참고 사항으로 기록(아래).
- **`PurchaseFailure` 예외 경로**: `core/error/failure.dart`에 클래스는 정의돼 있고 `ad_removal_sheet.dart`도 `on PurchaseFailure catch` 처리를 갖추고 있으나, `FakePurchaseRepository`는 어떤 조건에서도 실패를 던지지 않음 — 실패 UI(인라인 에러 토스트) 자체가 현재 코드베이스로는 트리거 불가능(테스트 커버리지 공백, 🟢 참고).

**결론**: 구매 상태 영속화·배너/전면광고 게이팅 모두 설계 의도대로 정확히 동작. 🔴/🟡 결함 없음, 위 세부사항은 전부 Fake 스캐폴드의 알려진 한계로 참고 수준.

---

## 6. 고아(orphaned) 분석 작업 감지 로직(`home_screen.dart` `_MediaCard`) 리뷰

```dart
final isOrphanedAnalyzing =
    item.status == MediaStatus.analyzing && !ref.exists(analyzingControllerProvider(item.id));
```

- **`analyzingControllerProvider`가 실제로 non-autoDispose임을 확인**(`StateNotifierProvider.family` 선언에 `.autoDispose`가 없음, 클래스 주석도 "의도적으로 autoDispose를 쓰지 않는다"로 명시) — 한 번 생성되면 프로세스가 살아있는 한 `ref.invalidate` 호출 없이는 계속 존재한다(코드 전체에서 해당 invalidate 호출 0건 확인).
- **정상 시나리오(오탐 없음)**: `AiAnalyzingScreen`이 `ref.watch(analyzingControllerProvider(mediaId))`로 컨트롤러를 최초 생성한 이후, 사용자가 뒤로 가서 홈 탭으로 돌아와도(비차단형 대기 설계) 같은 프로세스 내에서는 컨트롤러가 계속 살아있으므로 `ref.exists`가 `true`를 반환 — "멈춤"으로 오표시되지 않는다.
- **고아 시나리오(정탐)**: OS가 프로세스를 통째로 죽이면 컨트롤러를 포함한 전체 Riverpod 컨테이너가 함께 사라진다. 앱 재시작 시 홈 화면이 로컬 저장소에서 `MediaItem.status == analyzing`인 항목을 스트림으로 읽지만, 새 프로세스에는 아직 아무 `analyzingControllerProvider` 인스턴스도 생성되지 않았으므로 `ref.exists`가 `false` → 정확히 의도한 "멈춤" 표시로 이어짐.
- **잠재 경합 창(미세)**: `upload_controller.dart`(`_registerAndSave`)와 `home_controller.dart`(샘플 체험)는 `MediaItem`을 `status: analyzing`으로 저장하는 시점이 `AiAnalyzingScreen`이 실제로 빌드되어 컨트롤러를 생성하는 시점보다 앞선다. 이 저장은 파일 업로드 화면(홈 위에 push된 화면)에서 발생하며, 저장 직후 곧바로 `navigateForMediaStatus`로 분석 화면 이동이 이어지므로 홈 화면이 화면에 보이는 상태로 이 경합 창을 사용자가 목격할 가능성은 사실상 없다(수 프레임 내 이동, 홈 탭이 가려진 상태) — 코드 리딩상 이론적 false-positive 창이 존재하나 실사용 영향은 무시 가능한 수준으로 판단(🟢 참고로 기록).
- **"이어하기"(resume) 실제 동작 — 재시작이지 진짜 이어하기가 아님**: 고아 카드를 탭하면 `navigateForMediaStatus`가 `/home/analyzing/:mediaId`로 이동해 **새 `AnalyzingController` 인스턴스**를 생성하고, 그 생성자는 무조건 `_start()`를 호출한다. `_start()`는 `requestSegmentation(mediaId)`로 **완전히 새로운 jobId를 발급**하고 진행률을 처음부터(0%) 다시 관찰한다 — 즉 UI 문구("이어서 분석"/"탭해서 이어하기")와 달리 실제로는 **분석을 처음부터 재시작**한다. 로컬 처리(자막 파싱은 거의 즉시, 무음 감지도 상대적으로 빠름)라 재시작 비용 자체는 낮지만, 60분 분량 실제 파일의 무음 감지처럼 오래 걸릴 수 있는 케이스에서 "거의 다 됐던 걸 이어간다"는 기대와 "처음부터 다시 돈다"는 실제 동작이 어긋날 수 있다. 코드 주석 자체도 "자동으로 재시작된다(직접 확인됨)"라고 정확히 명시하고 있어 **구현자는 이 사실을 인지하고 있음** — 다만 사용자 노출 카피(`analyzingOrphanedStatus`="분석이 멈췄어요 · 탭해서 이어하기", `resumeAnalysisNeeded`="이어서 분석")는 "이어하기"라는 표현으로 마치 중단 지점부터 재개되는 것처럼 오인시킬 소지가 있다.

**결론**: `ref.exists()` 체크 자체는 non-autoDispose 프로바이더 시맨틱에 정확히 부합하며 설계 의도대로 동작한다. 로직 결함은 발견되지 않았으나, **실기기에서 프로세스를 강제 종료한 뒤 재실행해 진짜 고아 작업이 의도대로 표시되는지는 코드 리딩만으로는 확증 불가 — 수동 실기기 검증이 필요한 잔여 항목으로 남긴다.**

---

## 7. 이전 QA(2026-08-05) 지적사항 재검증

| 항목 | 이전 상태 | 이번 재검증 결과 |
|---|---|---|
| 🟡1 샘플 파일명 "AI" 노출 | 미해결 | ✅ **해결됨** — `home_controller.dart`의 `fileName`이 "샘플 오디오 파일 (MP3)"/"샘플 영상 파일"로 수정됨 |
| 🟡2 `mock_library_content.dart` 비-CNN/BBC 목업("ShadowingLab Originals") | 미해결 | ✅ **해소됨(구조적)** — 라이브러리 기능 전체가 삭제되며 파일 자체가 사라짐 |
| 🟡3 store-listing 오픈이슈 라벨 뒤처짐("샘플 체험" 기능) | 미해결 | ✅ **해결됨** — 04_store_listing.md가 이미 "✅ (해결)"로 갱신. 단, **같은 패턴의 새 사례가 발견됨**(아래 🟡1) |
| 🟡4 마이크 권한 온보딩 상시 요청 | 미해결 | ❌ **여전히 미해결, 변경 없음** — `onboarding_screen.dart:70-84`의 `_complete()`가 조건 없이 `requestMicrophone()`+`requestMediaLibrary()` 호출. `04_store_listing.md` 382행이 이 항목을 여전히 qa-engineer 우선 검증 요청 목록에 올려두고 있어 문서·현실 인식이 일치함(문서가 "해결됨"으로 잘못 표기하던 이전 문제는 사라짐) |
| 🟡5 `Permission.mediaLibrary` Android 세분화 매핑 미확인 | 미해결 | ➡️ **변경 없음, 이월** — 이번 작업 범위 밖 |
| 🟡6 README "AI가 문장을 잘라주는" 표현 | 미해결 | ✅ **해결됨** — "자동으로 문장을 나눠주는"으로 수정 |

---

## 발견 사항

### 🔴 필수 수정

**없음.** 코드 컴파일/정적분석/구매 흐름/고아 감지 로직/문서-코드 핵심 사실관계(가격, 상품ID, 탭 구조, 삭제 파일 목록) 전부 정합성 확인됨.

### 🟡 권장 수정

1. **[문서, 신규 발견] `04_store_listing.md` 오픈이슈가 이미 완료된 API 설계를 "미착수"로 잘못 표기 — 이전 QA에서 지적된 것과 동일한 "라벨 뒤처짐" 패턴 재발**
   - 위치: `04_store_listing.md:381` — `"🆕 (오픈) api-integrator — 광고 제거 단발성 구매 영수증 검증 엔드포인트 신규 설계 필요"`
   - 근거: `03_api_integration.md` 5-2절이 이미 `POST /v1/purchase/verify`, `GET /v1/purchase/status`, `POST /v1/purchase/webhooks/apple`·`/google`을 요청/응답 바디까지 구체적으로 설계 완료한 상태다(196-199행). 04번 문서는 이 사실을 반영하지 못하고 여전히 "03_api_integration.md의 `POST /subscription/verify`는 구독 검증용 구 문서"라고 서술하는데, 이는 03번 문서의 **현재 내용과도 맞지 않는다**(그 구독 엔드포인트는 03번 문서에서 이미 삭제되고 `/purchase/verify`로 완전히 대체됨, 03_api_integration.md:9행 참고).
   - 영향: 배포를 막지는 않지만, store-manager가 이 오픈이슈를 근거로 api-integrator에게 이미 끝난 작업을 다시 요청할 위험, 또는 반대로 실제로 남은 작업(실제 서버 구현·배포, 설계가 아니라 구현)이 무엇인지 헷갈리게 만듦.
   - 제안: store-manager가 이 항목을 "✅ (해결 — 설계 완료, 03_api_integration.md 5-2절 참고) / 🔄 (오픈 — 실 서버 구현·배포는 별도)"로 정정.

2. **[문서, 신규 발견] `01_ux_design.md` 온보딩(#0) 와이어프레임이 이미 삭제된 CNN/BBC 콘텐츠를 여전히 마케팅 문구로 노출**
   - 위치: `01_ux_design.md:158` — `슬라이드 3: "CNN·BBC 공식 자막으로, 오늘의 뉴스도 매일 새롭게" + 파일/마이크 권한 요청 → [시작하기]`
   - 근거: 같은 문서 5행이 "라이브러리(CNN/BBC 뉴스·대화 콘텐츠) 탭과 PRO 구독/Paywall 관련 기능이 코드에서 전부 삭제"됐다고 명시하고, 488행 이하 라이브러리 화면(#7/#8) 관련 서술은 전부 "**삭제됨(2026-08-08)**" 표기와 함께 참고용 이력으로만 남겨뒀다. 그런데 정작 **활성 화면(#0 온보딩, 삭제 표시 없음)**의 슬라이드 3 카피는 여전히 삭제된 라이브러리 기능을 홍보하고 있다 — 문서 내에서 자기모순.
   - 실제 코드는 정상: `onboarding_screen.dart`와 전체 l10n arb 파일(en/ja/ko) grep 결과 CNN/BBC 문자열 0건 — **코드는 이미 이 문구 없이 정확히 구현되어 있고, 문서만 뒤처져 있다.**
   - 영향: 배포를 막을 사안은 아니나(코드가 이미 맞게 구현됨), 이 문서를 기준으로 스토어 스크린샷·온보딩 카피 QA를 하는 경우 잘못된 기준선을 갖게 됨.
   - 제안: ux-designer가 158행을 삭제하거나 실제 온보딩 슬라이드 3 카피(코드 기준: 무음감지/자막파싱 두 갈래 소개 등)로 교체.

3. **[코드, 기존·미해결·변경 없음] 마이크 권한을 온보딩에서 전체 사용자에게 무조건 요청**
   - 위치: `lib/presentation/onboarding/onboarding_screen.dart:70-84`
   - 근거: `permission_service.dart` 클래스 docstring은 "마이크 권한은 선택 기능"이라고 명시하지만, `_complete()`는 조건 없이 `requestMicrophone()`을 호출한다.
   - 재검증 결과: 이번 라이브러리/구매 리팩터는 이 파일을 건드리지 않았으므로 예상대로 변경 없음. `04_store_listing.md:382`도 이 항목을 여전히 열린 검증 요청으로 정확히 인지하고 있어 문서·코드 인식은 일치(이전 QA에서 지적했던 "문서가 이미 해결로 잘못 표기" 문제는 이제 없음).
   - 제안: (이전 QA와 동일) 온보딩에서 마이크 권한 요청 제거, "내 목소리 녹음/비교" 토글 활성화 시점으로 이동.

4. **[코드↔카피, 신규 발견] "고아 분석 재개" UI 문구가 실제 동작(전체 재시작)과 어긋남**
   - 위치: `app_ko.arb`의 `analyzingOrphanedStatus`("분석이 멈췄어요 · 탭해서 이어하기") / `resumeAnalysisNeeded`("이어서 분석") ↔ `analyzing_controller.dart`의 `_start()`(매번 신규 jobId로 진행률 0%부터 재시작)
   - 근거: 6절 참고. 탭하면 실제로는 마지막 진행률에서 이어지는 게 아니라 세그멘테이션 작업 전체가 처음부터 다시 돈다 — 코드 주석은 이를 정확히 인지하고 있으나("자동으로 재시작된다"), 사용자 노출 카피는 "이어하기"라는 표현을 쓴다.
   - 영향: 로컬 처리 특성상 대부분 빠르게 끝나 실사용 체감은 크지 않을 가능성이 높지만, 60분 분량의 실제 무음감지처럼 오래 걸리는 케이스에서는 "거의 다 왔었는데 왜 처음부터?"라는 혼란을 줄 수 있음.
   - 제안: (a) 카피를 "다시 분석" 등 재시작임을 정확히 반영하도록 수정하거나, (b) 문구를 유지하고 싶다면 최소한 스토어 심사/사용자 기대관리 관점에서 이 트레이드오프를 UX 설계 문서에 명시.

### 🟢 참고 사항

1. **`flutter analyze` 실측 결과 — 두 사본 모두 요청된 기대 베이스라인과 정확히 일치**(2절). `ttara_runner` 2 info, `02_app_code` 2 info + 1 warning(테스트 파일 전용, `lib/`와 무관).
2. **`ttara_runner/lib`와 `02_app_code/lib`가 `l10n/gen/`까지 포함해 완전 byte-identical**(3절). 유일한 차이는 `lib/` 바깥의 `test/widget_test.dart` 1개 파일이며, 이는 요청 범위 밖이자 위 1번 lint 차이의 원인으로 이미 설명됨.
3. **`FakePurchaseRepository.restorePurchases()`는 사실상 로컬 캐시를 그대로 반환할 뿐** — "재설치 후 복원" 같은 진짜 복원 시나리오는 이 Fake 구현으로는 재현 불가능(5절). 실 StoreKit/Play Billing 연동 전까지 QA가 의미 있게 테스트할 수 있는 유일한 경로가 아니라는 점을 테스트 플랜에 명시 권장.
4. **`PurchaseFailure` 예외 경로가 현재 코드베이스로는 트리거 불가능** — `FakePurchaseRepository`가 실패를 시뮬레이션하지 않아 인라인 에러 토스트 UI가 실행 경로상 도달 불가(5절). 실 SDK 연동 전 수동 QA로는 검증 불가, 참고만.
5. **고아 분석 감지 로직에 이론적 false-positive 경합 창이 존재하나 실사용 영향은 무시 가능**(6절) — `MediaItem.status=analyzing` 저장이 `AiAnalyzingScreen` 마운트(컨트롤러 생성)보다 수 프레임 앞서지만, 이 구간 동안 홈 화면이 사용자에게 보이지 않는 상태로 즉시 화면 전환이 이어지므로 실질적 영향 없음.
6. **실기기 강제종료 재현 테스트는 이번 패스에서 미수행** — 코드 리딩상 `ref.exists()` 로직은 non-autoDispose 프로바이더 시맨틱에 정확히 부합하는 것으로 판단되나(6절), 실제 OS 프로세스 킬(특히 삼성 기기의 공격적 백그라운드 정책) 후 재실행 시 의도대로 "멈춤" 배지가 뜨는지는 실기기에서 직접 검증 필요.
7. **`MediaStatus.uploading` enum 값이 현재 코드 흐름상 도달 불가능**(dead state) — `_registerAndSave`는 등록 완료 후에야 `MediaItem`을 `status: analyzing`으로 저장하므로 `uploading` 상태의 `MediaItem`이 저장소에 남는 경로가 없다. `navigateForMediaStatus`/홈 화면 switch문에는 케이스가 남아있어 컴파일에는 문제없음(exhaustive switch 요구사항 충족용으로 유지되는 것으로 추정) — 기능 결함 아님, 참고만.
8. **광고 SDK 미연동 상태(`NoOpAdService`) 실측 확인** — `04_store_listing.md`의 "AdMob 등 실 SDK 확정 시..." 오픈이슈 서술과 정확히 일치. 배너는 플레이스홀더 박스("광고 영역 (SDK 미연동)"), 전면광고는 즉시 no-op 완료.
9. **샘플 오디오 asset은 여전히 45초 무음 PCM 플레이스홀더** — 이전 QA에서 지적된 그대로 이월(배포 전 실제 라이선스 명확한 영어 발화 샘플로 교체 필요, 이번 리팩터와 무관).
10. **CNN/BBC 저작권 블로커는 앱 분리로 완전히 이 앱 범위 밖으로 이관됨** — `04_store_listing.md` 8행이 "N/A로 통째 제거"를 명시하고, 실제로 이 앱 코드베이스에는 CNN/BBC 콘텐츠 취급 코드 자체가 없음(1절). 별도 앱("English News Shadowing Lab") 프로젝트 문서에서 계속 추적되어야 할 사항이며 이 문서 범위가 아님.

---

## 정합성 매트릭스

| 검증 항목 | 상태 | 비고 |
|----------|------|------|
| 라이브러리/구독 삭제 완전성(코드 grep) | ✅ | 죽은 참조 0건, 삭제 파일 13개 전부 미존재 확인(1절) |
| `ttara_runner/lib` ↔ `02_app_code/lib` 동기화 | ✅ | 완전 byte-identical, `l10n/gen/` 포함(3절) |
| `flutter analyze`(양쪽) | ✅ | 두 사본 모두 요청된 기대 베이스라인과 정확히 일치, 에러 0건(2절) |
| 문서 ↔ 코드(가격/상품ID/탭구조/프로바이더명/삭제파일목록) | ✅ | 표본 검증 전부 일치(4절) |
| 문서 ↔ 코드(온보딩 슬라이드 3 카피) | ⚠️ | 코드는 정상, `01_ux_design.md` 158행만 삭제된 기능 홍보 문구 잔존(🟡 2) |
| store-listing 오픈이슈 라벨 정확성 | ⚠️ | 영수증 검증 엔드포인트 설계 완료를 미착수로 잘못 표기(🟡 1, 이전 패턴 재발) |
| 광고 제거 구매 흐름(영속성/게이팅/더블탭) | ✅ | 배너(홈 전용)·전면광고(세션종료) 게이팅 정확, 더블탭 방지 확인(5절) |
| 고아 분석 감지 로직(`ref.exists()`) | ✅ | non-autoDispose 시맨틱과 정확히 부합, 코드 리딩상 결함 없음(6절) — 단 실기기 검증 잔여(🟢 6) |
| "이어하기" 카피 ↔ 실제 재시작 동작 | ⚠️ | 기능은 정상 작동하나 사용자 기대와 문구가 어긋날 수 있음(🟡 4) |
| 이전 QA 이월 항목 재검증 | ⚠️ | 6개 중 4개 해결, 1개 여전히 미해결(마이크 권한), 1개 무관(mediaLibrary API)로 이월(7절) |
| 성능 | ✅ | 변경 없음, 리팩터가 오히려 코드/화면 수 감소 방향 |
| 접근성 | ✅ | 변경 없음, 고아 배지도 색상+텍스트("멈췄어요") 병기 확인 |
| 보안 | ✅ | 오디오 외부 전송 경로 없음, 구매 상태는 로컬 저장(실 연동 전 서버 검증 필요성은 03번 문서가 이미 인지) |

---

## 테스트 커버리지

| 영역 | 점검 시나리오 수 | 통과 | 실패 | 차단/미수행 |
|------|---------|------|------|------|
| 라이브러리/구독 잔존 참조 grep(library/Library/subscription/Subscription/PaywallSheet/ProBadge/proGold) | 5 | 5 | 0 | 0 |
| 삭제 파일 13개 실존 여부 확인 | 13 | 13 | 0 | 0 |
| `flutter analyze`(ttara_runner/02_app_code) | 2 | 2(기대 베이스라인과 정확히 일치) | 0 | 0 |
| `lib/` 트리 byte-identical(diff -rq) | 1 | 1 | 0 | 0 |
| 문서↔코드 구체적 주장 대조(가격/상품ID/탭구조/프로바이더명/삭제파일목록/README/샘플파일명) | 10 | 8 | 2(🟡1, 🟡2) | 0 |
| 구매 흐름 코드 리뷰(영속성/게이팅/더블탭/백그라운드/복원) | 5 | 5 | 0 | 0 |
| 고아 분석 감지 로직 리뷰(`ref.exists` 정합성/경합창/재시작 여부) | 4 | 3 | 1(🟡4, 카피 불일치) | 0 |
| 이전 QA 이월 항목 재검증 | 6 | 5 | 1(마이크 권한, 기존 미해결) | 0 |
| 실기기 고아 작업 강제종료 재현 | 1 | 0 | 0 | 1(미수행 — 코드 리딩 범위 밖) |
| 위젯/골든 테스트 실행(`flutter test`) | 1 | 0 | 0 | 1(미수행) |

---

## 최종 산출물 체크리스트

- [x] UX 설계 문서 완성(`01_ux_design.md`) — 2탭 구조/IAP 반영 완료, 단 온보딩 슬라이드 3 카피 잔존(🟡 2)
- [x] 앱 코드 생성(`02_app_code/`, `ttara_runner/`) — `flutter analyze` 양쪽 실제 통과(에러 0), 두 사본 완전 동기화
- [x] API 연동 설계 완성(`03_api_integration.md`) — 광고 제거 IAP 검증 엔드포인트 설계 완료(5-2절)
- [x] 스토어 메타데이터 준비(`04_store_listing.md`) — 가격/카피 전면 정리 완료, 단 오픈이슈 라벨 일부 뒤처짐(🟡 1)
- [ ] 개인정보처리방침 작성 — 여전히 목차 초안 단계, 법무 검토 필요(범위 밖, 배포 차단 아님)
- [x] `flutter analyze`/`flutter pub get` 실기 검증(양쪽 사본) — 이번 패스에서 실제 실행 완료(2절), 에러 0건
- [x] `02_app_code`↔`ttara_runner` 동기화 검증 — 이번 패스에서 실제 diff 실행 완료(3절), 완전 동일
- [ ] 실기기 강제종료 → 고아 분석 작업 재현 테스트(🟢 6, 잔여 수동 검증 항목)
- [ ] 마이크 권한 온보딩 상시 요청 → 사용 시점 요청으로 변경(기존 이월, 🟡 3)
- [ ] 샘플 오디오 asset을 실제 라이선스 명확한 영어 발화 샘플로 교체(기존 이월)

---

## 담당 에이전트별 잔여 요청 요약

- **ux-designer**: `01_ux_design.md:158` 온보딩 슬라이드 3 카피에서 CNN/BBC 홍보 문구 제거·교체(🟡 2).
- **store-manager**: `04_store_listing.md:381` 오픈이슈를 "영수증 검증 엔드포인트 설계 완료(03_api_integration.md 5-2절), 실 서버 구현만 잔여"로 정정(🟡 1).
- **app-developer**:
  1. 온보딩 마이크 권한 상시 요청 → 사용 시점 요청 변경(🟡 3, 기존 이월).
  2. 고아 분석 "이어하기" 카피를 실제 재시작 동작에 맞게 조정하거나, UX 설계 문서에 재시작 트레이드오프 명시(🟡 4).
  3. `Permission.mediaLibrary`의 Android 세분화 매핑 확인(기존 이월).
  4. (선택, 배포 전 필수) 샘플 오디오를 실제 발화 샘플로 교체(기존 이월).
  5. (선택) `mock_sentences.dart:58`의 `__` 식별자 린트 정리.
- **qa-engineer(잔여, 실기기 필요)**: 프로세스 강제종료 후 재실행으로 고아 분석 감지 배지 실제 동작 검증(🟢 6) — 코드 리딩만으로는 확증 불가능한 유일한 잔여 항목.
- **api-integrator**: 특이 조치 불필요 — 이번 리팩터로 담당 범위가 광고 제거 IAP 영수증 검증(설계 완료, 구현 대기) 하나로 축소되었고 문서·코드 간 불일치 없음.
