# API 연동 명세 — 쉐도잉랩(ShadowingLab, 구 따라/TTARA) 쉐도잉 학습 앱

> 작성: api-integrator · 기준일: 2026-08-08(앱 분리 반영, 최초 작성 2026-08-05)
> 참고 문서: `00_input.md`(2026-08-05 STT 완전 폐기 결정, 2026-08-08 앱 분리·수익모델 개정), `01_ux_design.md`(UX 설계·API 연동 전달 사항), `02_app_architecture.md`(Repository 인터페이스, 로컬 문장분리 구현), `04_store_listing.md`(개인정보/심사 리스크)
> 대상 Repository: `purchase_repository.dart`(광고 제거 인앱 구매 — 유일한 서버 연동 후보, `_workspace/ttara_runner/lib/domain/repositories/`) / `segmentation_repository.dart` (2026-08-05부터 **로컬 전용, 이 문서의 API 연동 대상 아님** — 4절 참고)
>
> **2026-08-05 결정 반영**: 유료 STT 벤더(AssemblyAI 등)를 앱 전체에서 완전히 제거한다. 사용자가 개발자의 유료 API를 소비시키는 흐름을 하나도 남기지 않는 것이 확정 요구사항이며, 이는 무료 티어에 국한된 정책이 아니라 앱 전체 원칙이다.
>
> **2026-08-08 앱 분리 반영**: 이 앱(쉐도잉랩)은 **CNN/BBC 뉴스·자체 제작 다이얼로그 콘텐츠 라이브러리 및 구독 기능 전체를 별도 앱 "English News Shadowing Lab"으로 이전**했다(`00_input.md` 참고). 콘텐츠 수집 파이프라인(오늘의 뉴스 + 자체 제작 다이얼로그 2트랙), `GET /v1/library/*` 엔드포인트 일체, `POST /v1/subscription/verify`, `LibraryContent`/`SubscriptionStatus` 데이터 모델은 **그대로 새 앱으로 이전**되었으며 그 문서는 별도 프로젝트에 있다 — 이 문서에서는 완전히 삭제한다(이전 버전의 5절 "콘텐츠 라이브러리 API", 6절 "구독/결제 연동"이 이에 해당했다). 대신 수익모델이 **일회성 "광고 제거" 인앱 구매(14,900원)** 하나로 단순화되어, 이를 반영한 새 5절로 대체했다.

---

## 0. 문서 범위와 전제

- 실제 백엔드는 아직 존재하지 않는다. 앱 분리(2026-08-08) 이후 이 백엔드가 담당할 일은 **광고 제거 인앱 구매 영수증 검증** 단 하나로 줄었다 — 그마저도 **아직 구현되지 않았다**. 현재 `PurchaseRepository`는 `FakePurchaseRepository`(로컬 KV 저장소 기반 mock)로만 구현되어 있고, 실제 StoreKit/Play Billing 연동이나 서버 검증 호출은 없다(5절).
- 핵심 플로우(로컬 파일 업로드 → 기기 내 무음감지/자막파싱 → 쉐도잉)는 애초부터 서버 API가 필요 없었고, 이 사실은 앱 분리와 무관하게 그대로 유지된다(`00_input.md`, 4절).
- `SegmentationRepository`(문장 자동분리)는 **이 문서의 API 연동 대상이 아니다.** 무음 감지(음성만 업로드)와 자막 파일 파싱(영상+자막 업로드) 모두 클라이언트 로컬 처리이며 어떤 네트워크 호출도 발생시키지 않는다. `MediaRepository`/`StatsRepository`/`SettingsRepository`와 마찬가지로 **로컬 전용 Repository**다 — 실제 구현 로직은 app-developer가 담당하는 `02_app_architecture.md`를 참고하고, 이 문서에서는 4절에서 그 이유와 경계만 짧게 명시한다.
- 결과적으로 이 문서가 실제로 설계할 대상은 **미래에 필요해질 구매 영수증 검증 엔드포인트 하나**뿐이며(5절), 나머지 절(1~3, 6~11)은 그 하나의 엔드포인트를 둘러싼 공통 네트워크 계층/에러 처리/캐싱/오프라인 원칙을 다룬다. 콘텐츠 라이브러리처럼 상세도를 배분할 대상 자체가 더 이상 없다.

---

## 1. 전체 아키텍처

```
Flutter App (dio, 실제 서버 호출은 아직 0건 — 전부 준비 단계)
   │  (미구현) Bearer accessToken(JWT)?  ── 2절 참고, 현재는 불필요할 수도 있음
   ▼
자체 백엔드 API  api.ttara.app/v1   ← 아직 존재하지 않음, 이 문서가 설계만 해둔 상태
   │
   │ (미구현) 영수증 검증
   ▼
App Store Server API / Google Play Developer API

※ 사용자 업로드 음성/영상 파일은 이 다이어그램에 등장하지 않는다 — 문장 분리는
  전적으로 기기 내(로컬)에서 처리되고, 원본 파일도 서버로 전송되지 않는다(4절).
※ 콘텐츠 라이브러리(CNN/BBC, 자체 제작 다이얼로그)와 구독 서빙은 2026-08-08부로
  별도 앱(English News Shadowing Lab)의 책임이며 이 다이어그램·문서에 없다.
```

- **백엔드가 (미래에) 하게 될 일은 하나뿐이다**: 광고 제거 인앱 구매 영수증/구매 토큰을 서버에서 재검증하는 것(5절). 그 외 어떤 서버 API도 이 앱에는 필요하지 않다.
- **인증 필요 여부는 아직 확정이 아니다**: 콘텐츠 라이브러리가 없어지면서 "구독 엔타이틀먼트 조회"라는, 기존에 기기 기반 익명 인증(JWT)을 요구했던 핵심 근거가 사라졌다. `PurchaseRepository` 인터페이스(`watchAdsRemoved()`/`purchaseRemoveAds()`/`restorePurchases()`) 자체는 `userId`나 토큰을 전혀 요구하지 않는다 — 스토어 SDK의 "구매 내역 복원"이 사용자의 App Store/Google 계정을 기준으로 동작하기 때문이다. 2절은 이 앱에 남아있는 유일한 서버 연동(영수증 검증)에 자체 계정 시스템이 실제로 필요한지 재검토가 필요하다는 전제로 다시 정리했다.

---

## 2. 인증 흐름 — 기기 기반 익명 인증 (필요성 재검토 대상, + 선택적 이메일 연결)

> ⚠️ **2026-08-08 갱신**: 이 절이 원래 전제하던 근거(콘텐츠 라이브러리 접근권/구독 엔타이틀먼트를 서버가 판별해야 함)는 라이브러리 기능 자체가 별도 앱으로 이전되며 사라졌다. `PurchaseRepository`의 실제 인터페이스(`purchase_repository.dart`)는 `userId`/토큰 파라미터를 전혀 사용하지 않으며, `restorePurchases()`는 스토어 SDK가 사용자의 App Store/Google 계정을 통해 처리한다 — 자체 백엔드 인증 없이도 기기/재설치 복원이 이미 가능하다. 아래 설계는 "서버가 구매 엔타이틀먼트를 자체 `userId`에 귀속시켜 관리하고 싶을 경우"에 대비한 **선택적** 설계로 남겨두며, 5절의 `POST /v1/purchase/verify`를 실제로 구현할 때 정말 필요한지 app-developer와 재확인해야 한다.

### 2-1. 방식 결정 및 근거 (선택적 설계로 격하)

| 검토 옵션 | 채택 여부 | 근거 |
|---|---|---|
| 이메일/비밀번호 회원가입 필수 | ❌ | 무료 핵심 기능(내 파일 쉐도잉)은 로그인 없이도 100% 동작해야 한다는 원칙과 충돌 |
| 완전 무인증(서버에 사용자 개념 없음) | ✅ 유력 후보 | 광고 제거는 스토어 계정에 귀속되는 구매이므로, 서버가 영수증만 검증하고 별도 `userId`로 관리하지 않아도 `restorePurchases()`가 정상 동작한다. 서버 쪽에서 굳이 자체 계정 시스템을 유지할 이유가 약해졌다 — **아래 기기 기반 익명 인증은 "그래도 서버측에 구매 상태를 귀속·감사하고 싶다"는 요구가 생길 때만 채택**한다 |
| 기기 기반 익명 인증(JWT) + 선택적 이메일 연결 | 🔶 조건부(구현 시점에 재판단) | 서버가 영수증 검증 이력을 `userId` 단위로 감사/조회하고 싶거나, 향후 다른 서버 기능이 추가될 것을 대비한다면 유지할 가치가 있다. 순수 광고 제거 단일 기능만 놓고 보면 과설계일 수 있음 |

### 2-2. (조건부 채택 시) 토큰 저장

| 플랫폼 | 저장소 |
|---|---|
| iOS | Keychain (`flutter_secure_storage`, `first_unlock_this_device` 접근성) |
| Android | EncryptedSharedPreferences (`flutter_secure_storage` 동일 패키지가 자동 위임) |

저장 키: `accessToken`, `refreshToken`, `userId`, `deviceId`(최초 1회 생성 후 고정, `uuid` v4).

### 2-3. (조건부 채택 시) 엔드포인트

| 메서드 | 엔드포인트 | 설명 |
|---|---|---|
| POST | `/v1/auth/anonymous` | 최초 실행 시 1회 호출. Body: `{ "deviceId": "uuid", "platform": "ios\|android", "appVersion": "1.0.0" }` → `{ "userId", "accessToken", "refreshToken", "expiresIn": 3600 }` |
| POST | `/v1/auth/refresh` | Body: `{ "refreshToken" }` → 새 토큰 쌍. Refresh Token도 만료/폐기 시 401 → 재로그인(=`/v1/auth/anonymous` 재호출, 단 기존 `deviceId` 유지 시 서버가 동일 `userId`로 매핑 시도) |
| POST | `/v1/auth/link-email` | 선택 기능. Body: `{ "email" }` → 매직링크 이메일 발송(비밀번호 없음) |
| GET | `/v1/auth/link-email/verify?token=...` | 딥링크로 앱 복귀 시 호출 → 기존 익명 `userId`에 이메일 연결, 응답으로 갱신된 토큰 쌍 |
| POST | `/v1/auth/logout` | 이메일 연결된 계정만 유효(로컬 토큰 폐기 + 서버 refreshToken revoke) |

### 2-4. (조건부 채택 시) 플로우

```
1. 앱 최초 실행 → deviceId 로컬 생성(1회) → POST /v1/auth/anonymous
2. accessToken(1시간)/refreshToken(90일) 수신 → Secure Storage 저장
3. 모든 API 요청에 Authorization: Bearer {accessToken} 첨부
4. 401 수신 → AuthInterceptor가 refreshToken으로 갱신 시도(동시 요청은 단일 refresh로 합류, 3-2 참조)
5. refresh도 401/실패 → accessToken/refreshToken 삭제 후 /v1/auth/anonymous 재발급(사용자는 인지 못함)
6. (선택) 설정 화면에서 이메일 연결 시 이후 재설치해도 이메일 인증으로 동일 userId 복구 가능
```

- 무료 핵심 기능(파일 업로드/쉐도잉 학습)은 인증과 완전히 무관하게 동작한다. 광고 제거 구매/복원도 스토어 SDK만으로 이미 동작하므로, 이 절 전체를 구현할지 여부는 **5절의 서버 영수증 검증을 실제로 붙이는 시점에 app-developer와 함께 결정**한다.

---

## 3. 네트워크 계층 공통 설계

### 3-1. HTTP 클라이언트

- **패키지**: `dio` (+ 커스텀 RetryInterceptor), `connectivity_plus`(네트워크 상태 감지), `flutter_secure_storage`(토큰, 2절 채택 시), `pretty_dio_logger`(디버그 빌드 전용).
- **BaseOptions**: `baseUrl: https://api.ttara.app/v1`, `connectTimeout: 10s`, `receiveTimeout: 20s` — 유일한 API 호출 후보가 구매 영수증 검증(5절) 하나뿐인 가벼운 REST 호출이라 도메인별 특수 타임아웃 오버라이드가 불필요하다.
- **인터셉터 체인 순서** (`InterceptorsWrapper` 여러 개를 순서대로 등록):
  1. `AuthInterceptor` — (2절 채택 시) 모든 요청에 `Authorization: Bearer {accessToken}` 첨부. 응답 401 감지 시 갱신 로직 수행(3-2).
  2. `RetryInterceptor` — 멱등 요청(GET, PUT, 그리고 명시적으로 멱등 설계된 POST — 예: `POST /v1/purchase/verify`는 동일 영수증 재전송해도 안전, 5-2절)에 한해 5xx/timeout/connection error를 지수 백오프(0.5s→1s→2s, ±20% jitter)로 최대 3회 재시도. 4xx는 재시도하지 않음.
  3. `ErrorMappingInterceptor` — `DioException` → 앱 도메인 `Failure` 타입(`core/error/failure.dart`)으로 변환 후 rethrow. 구매 실패는 `PurchaseFailure`로 매핑(9절 에러 매트릭스 참고).
  4. `LoggingInterceptor` — `kDebugMode`에서만 활성화, 토큰/영수증 등 민감 필드는 마스킹 후 로그.

### 3-2. 401 처리 / 토큰 갱신 동시성 제어 (2절 채택 시)

호출 대상이 하나뿐이라 실제로 401이 "동시다발"할 시나리오는 거의 없지만, 설계는 남겨둔다:

```
if (refreshInFlight != null) {
  await refreshInFlight;               // 이미 진행 중인 refresh에 합류
} else {
  refreshInFlight = _doRefresh();
  await refreshInFlight;
  refreshInFlight = null;
}
// 갱신된 accessToken으로 원 요청 1회 재시도 (RequestOptions 재사용)
```

### 3-3. 네트워크 상태 3단계 인식

| 상태 | 판정 기준 | 앱 동작 |
|---|---|---|
| **정상** | `connectivity_plus`가 wifi/mobile 보고 + 최근 5회 요청 평균 RTT < 1.5s | 평소대로 동작 |
| **느린 네트워크** | 연결은 있으나 최근 요청 평균 RTT ≥ 1.5s | 구매 시트에 "네트워크가 느려요, 시간이 더 걸릴 수 있어요" 인라인 안내만 추가(차단하지 않음). 내 파일 업로드/문장분리는 로컬 처리이므로 네트워크 상태와 무관 |
| **오프라인** | `connectivity_plus`가 `none` 보고 | 구매/복원(5절)은 온라인 필요 액션이므로 오프라인 시 버튼 비활성화 + "오프라인" 안내. 내 파일 쉐도잉(#1/#5)은 완전 오프라인 정상 동작(무음 감지/자막 파싱이 모두 로컬 처리이므로 서버 호출 자체가 없음) |

### 3-4. 보안 원칙

- 구매 검증 API가 내부적으로 사용하는 키(App Store/Google Play 서버 API 키 등)는 전부 **백엔드에만 보관**, 클라이언트 코드/빌드 산출물에는 어떤 API 키도 하드코딩하지 않는다. 클라이언트가 아는 것은 `baseUrl`과 (2절 채택 시) 발급받은 사용자 JWT뿐이다. (참고: STT 벤더 키, CNN/BBC 피드 자격증명은 애초에 이 앱에 존재하지 않는다 — 전자는 2026-08-05 결정, 후자는 2026-08-08 앱 분리로 각각 제거/이관.)
- `baseUrl`, 환경별(dev/staging/prod) 엔드포인트는 `--dart-define` 빌드 변수 또는 `flutter_dotenv`(단, `.env`는 `.gitignore` 처리)로 주입.
- 전 구간 TLS 1.2+ 강제, 인증서 피닝은 MVP 범위 밖(v2 검토).

---

## 4. 문장분리 — `SegmentationRepository` (API 연동 없음, 로컬 전용)

**이 절의 결론은 한 문장으로 요약된다: `SegmentationRepository`는 백엔드/외부 API를 전혀 호출하지 않는다.** 아래는 이전 버전(2026-08-04, STT 벤더 채택안)이 왜 폐기되었는지와, 그 결과 이 문서의 책임 범위가 어떻게 줄어드는지를 짧게 기록한다. 실제 로컬 처리 구현(무음 감지 알고리즘, SRT/VTT 파서 등)은 `02_app_architecture.md`가 소유하며, 이 문서는 "여기엔 API가 없다"는 경계만 명시한다.

### 4-1. 왜 API가 없는가 — 2026-08-05 결정 배경

- **이전 설계(폐기됨)**: 클라우드 STT 벤더(AssemblyAI 등)에 오디오를 업로드해 문장 경계+신뢰도를 받아오는 비동기 Job 파이프라인(Presigned 분할 업로드 → Job 제출/폴링/SSE → 결과 저장 → 벤더 삭제 정책)을 설계했었다. 이 구조는 사용자 1인의 파일 업로드마다 벤더에 종량 과금이 발생하는 구조였다.
- **폐기 사유**: 개발자가 "사용자가 어떤 경로로든 개발자의 유료 API 호출을 트리거하는 일이 없어야 한다"를 하드 요구사항으로 확정(`00_input.md` 2026-08-05). 이는 무료 티어에만 적용되는 제약이 아니라 앱 전체 원칙이며, 유료 사용자에게도 사용자 업로드 파일에 대한 STT 호출은 발생하지 않는다.
- **대체 방식**: 두 가지 로컬 경로만 존재한다.
  1. **음성만 업로드**: 클라이언트가 무음/휴지(pause) 구간을 신호 처리로 감지해 문장 경계만 나눈다. 텍스트는 없음 — 문장 번호만 표시하고 사용자는 듣고 따라 말한다.
  2. **영상+자막(SRT/VTT) 업로드**: 자막 파일 자체의 큐 타임스탬프/텍스트를 그대로 문장 경계·텍스트로 사용한다(파싱만 필요, AI 인식 없음).
- 두 경로 모두 **네트워크 호출이 0건**이다. 오디오/영상 원본은 기기 밖으로 전송되지 않는다.

### 4-2. Repository 분류 변경

- `SegmentationRepository`는 `MediaRepository`/`StatsRepository`/`SettingsRepository`와 동일하게 **로컬 전용 Repository**로 취급한다(0절 참고). `repository_providers.dart`에서 이 Repository는 애초에 "Fake → Real(원격)" 교체 대상이 아니다 — 로컬 구현체가 곧 최종 구현체다.
- 이전 버전 4-7절의 `SentenceSegment` 스키마(`id/mediaId/index/text/translation/startMs/endMs/confidence/edited/repeatCountOverride`)는 필드 구조 자체는 유지 가능하지만, `confidence`(벤더 신뢰도)·`translation`(번역 API 결과)처럼 서버/벤더 응답에서 채우던 필드는 채울 소스가 없다 — 로컬 처리 방식에 맞는 필드 축소/의미 재정의는 app-developer의 `02_app_architecture.md` 소관이며, 이 문서는 "서버가 이 필드들을 채워주지 않는다"는 점만 알린다.
- 이전 버전의 Presigned 분할 업로드, Job 폴링/SSE, `SttProvider` 어댑터, 벤더 삭제 API 연동, Mock STT 서버는 전부 **삭제 대상**이며 어떤 형태로도 재사용하지 않는다.

### 4-3. app-developer/QA 확인 필요 사항

- 로컬 무음 감지·자막 파싱 로직의 성능(대용량 파일 처리 시간, 배터리 소모)과 정확도는 API 연동 이슈가 아니므로 이 문서 범위 밖이다 — `02_app_architecture.md`/QA(`05_qa_report.md`)에서 다룬다.
- 오프라인 지원(8절)에서 "내 파일 쉐도잉"은 애초에 서버 호출이 없으므로 네트워크 상태와 완전히 무관하게 동작한다는 점만 이 문서에서 재확인한다.

---

## 5. 인앱 구매 연동(광고 제거) — `PurchaseRepository`

**2026-08-08 수익모델 개정**(`00_input.md`)으로 기존 정기 구독(월/연) 모델은 완전히 폐기되고, **광고 제거 일회성 인앱 구매(14,900원)** 하나로 단순화되었다. 이 구매는 배너/전면 광고를 영구히 제거하는 단발성 결제이며, "구독"이 아니므로 `plan`/`nextBillingDate` 같은 정기 결제 개념이 아예 적용되지 않는다.

> 아래 인터페이스는 실제 코드(`_workspace/ttara_runner/lib/domain/repositories/purchase_repository.dart`)를 그대로 확인하고 옮긴 것이다 — 메서드 시그니처를 임의로 추정하지 않았다.

### 5-0. 현재 구현 상태 — 전부 로컬 Fake

- `PurchaseRepository`는 현재 `FakePurchaseRepository`(`data/repositories/fake_purchase_repository.dart`)로만 구현되어 있다. 실제 스토어 SDK(StoreKit2/Play Billing) 연동도, 서버 통신도 **전혀 없다** — `LocalKvStore`에 `bool`(광고 제거 여부) 하나를 저장할 뿐이다.
- `purchaseRemoveAds()`는 900ms 지연 후 로컬 상태를 `true`로 저장(스토어 결제 시트 시뮬레이션), `restorePurchases()`는 500ms 지연 후 저장된 로컬 값을 다시 읽어올 뿐(스토어 복원 흐름 시뮬레이션) — 실제 영수증 검증도, 실제 스토어 API 호출도 발생하지 않는다.
- 즉 이 절의 5-1~5-3은 **api-integrator가 실제 StoreKit/Play Billing + 서버 검증으로 교체할 때를 위한 설계**이며, 현재 시점에는 어떤 네트워크 호출도 만들지 않는다(0절 참고).

### 5-1. 실제 `PurchaseRepository` 인터페이스 (코드 확인 완료)

```dart
abstract class PurchaseRepository {
  static const adRemovalProductId = 'com.shadowinglab.remove_ads';

  Stream<bool> watchAdsRemoved();
  Future<void> purchaseRemoveAds();   // 실패 시 PurchaseFailure
  Future<void> restorePurchases();
}
```

- `watchAdsRemoved()`: 광고 제거 상태를 구독하는 스트림. 배너 광고 노출 여부(#홈), 전면 광고 트리거 여부, 설정 화면 "광고 제거됨 ✓" 표시가 전부 이 스트림 하나로 게이팅된다.
- `purchaseRemoveAds()`: 구매 흐름 시작부터 완료(및 실 구현 시 서버 영수증 검증)까지 하나로 감싼 메서드 — UI는 구현 세부사항(스토어 SDK 호출, 서버 검증 왕복)을 모른다. 실패 시 `PurchaseFailure`(`core/error/failure.dart`)를 던진다(구매 시트 인라인 에러 + 재시도).
- `restorePurchases()`: `purchaseRemoveAds()`와 **의도적으로 분리된 별개 메서드**다 — 실제 StoreKit/Play Billing에서도 "새로 구매"와 "이미 구매한 내역 복원"은 서로 다른 API 호출이기 때문에 이 구분을 유지한다(기기 변경/재설치 시나리오).
- `cancel()`류의 메서드는 **인터페이스에 없다** — 일회성 구매는애초에 "해지"라는 개념이 없다(정기 구독이 아니므로 자동 갱신 자체가 없음). 이전 버전(폐기된 `SubscriptionRepository`)에 있던 "구독 해지 버튼 → 스토어 구독 관리 화면 딥링크" 관련 설계는 **이 앱에는 해당 사항 없음**.
- 상품 ID `com.shadowinglab.remove_ads`는 실제 App Store Connect/Play Console 등록 시 그대로 사용할 상수로 이미 코드에 정의돼 있다. 가격 문자열(`14,900원`)은 현재 `l10n` ARB 파일에 하드코딩돼 있다(`adRemovalBannerTitle`, `adRemovalPrice` 등) — 실제 스토어 연동 시에는 기존 구독 설계와 동일한 원칙으로, `in_app_purchase` 패키지의 `queryProductDetails()`가 반환하는 실제 등록 가격으로 교체해 국가별 가격 자동 대응하도록 app-developer에게 전달 필요(12절).

### 5-2. (미구현, 설계만) 서버 영수증 검증 엔드포인트

일회성 구매도 클라이언트 로컬 상태만으로는 위변조에 취약하므로(예: 기기 저장소 직접 조작으로 `adsRemoved=true` 위조), 실제 스토어 연동 시에는 서버 검증이 필요하다. 이전 버전의 `POST /v1/subscription/verify`와 동일한 목적이지만, **정기 결제가 아니므로 구조를 단순화**한다:

| 메서드 | 엔드포인트 | 설명 |
|---|---|---|
| POST | `/v1/purchase/verify` | `purchaseRemoveAds()`/`restorePurchases()` 공용. Body: `{ platform: "ios"\|"android", productId: "com.shadowinglab.remove_ads", receiptData (iOS) \| purchaseToken (Android) }` → 서버가 App Store Server API(JWS 검증) 또는 Google Play Developer API(`purchases.products.get` — 정기결제용 `purchases.subscriptions.get`이 아님)로 유효성 재검증 → `{ isAdRemoved: true, purchasedAt }`. 멱등 — 동일 영수증 재전송해도 안전 |
| GET | `/v1/purchase/status` | (선택) 현재 엔타이틀먼트 조회 — 2절에서 자체 계정 시스템을 채택하지 않는다면, 클라이언트가 로컬 캐시(`watchAdsRemoved()`)만으로 충분할 수 있어 이 엔드포인트 자체가 불필요할 수 있음. 2절 결정에 종속 |
| POST | `/v1/purchase/webhooks/apple` | (선택) Apple **App Store Server Notifications V2** 수신(서버-서버). 환불(`REFUND`) 발생 시 서버가 엔타이틀먼트를 즉시 회수 — 일회성 구매도 환불은 가능하므로 이 웹훅만은 정기구독 설계와 동일하게 유효 |
| POST | `/v1/purchase/webhooks/google` | (선택) Google **RTDN** 수신, 환불 등 동일 목적(`ONE_TIME_PRODUCT_NOTIFICATION` 타입) |

- **이전 버전과의 핵심 차이**: 응답에 `plan`/`nextBillingDate`/`isTrialEligible` 같은 정기 결제 필드가 없다. 일회성 구매는 "샀다/안 샀다"(`isAdRemoved: bool`)와 "언제 샀는지"(`purchasedAt`, 환불 문의 대응용)만 있으면 충분하다.
- **환불 대응**: 정기 구독처럼 "해지"는 없지만 "환불"은 여전히 가능하다 — 웹훅으로 서버가 인지하면 `watchAdsRemoved()`가 다음 조회 시 `false`로 돌아가도록 반영해야 한다(광고가 다시 노출됨). 이 사용자 경험(환불 후 광고 재노출 안내)은 app-developer/UX 쪽에 확인 필요.

### 5-3. `watchAdsRemoved()` 갱신 방식 (실 구현 시)

- 서버 웹훅(환불 등)이 클라이언트로 즉시 전달되지 않으므로, `StreamProvider`는 **앱 포그라운드 전환 시 1회 + 구매/복원 직후 1회** `GET /v1/purchase/status`(구현한다면) 또는 로컬 캐시 재확인으로 스트림에 방출하는 폴링 기반으로 구현한다. 현재 Fake 구현은 `LocalKvStore` 변경을 `StreamController.broadcast()`로 즉시 방출하므로 이 지연이 없다 — 실 구현 전환 시 이 차이를 QA에 공유 필요.

---

## 6. 데이터 모델 매핑

| 모델명 | 필드 | 타입 | API 매핑 | 비고 |
|---|---|---|---|---|
| `SentenceSegment` | id, mediaId, index, text, translation, startMs, endMs, confidence, edited, repeatCountOverride | String, String, int, String, String?, int, int, double, bool, int? | API 매핑 없음 — 로컬 무음감지/자막파싱으로 클라이언트가 직접 생성(4절) | `confidence`/`translation`은 서버에서 채워줄 소스가 없다(라이브러리 기능이 별도 앱으로 이전됨) — 로컬 처리 방식에 맞는 필드 축소/의미 재정의는 app-developer가 재검토(02_app_architecture.md) |
| `PurchaseStatus`(신규, 미구현) | isAdRemoved, purchasedAt | bool, DateTime? | (미구현) `GET /v1/purchase/status`, `POST /v1/purchase/verify` 응답 | 5-2절 참고. 기존 `SubscriptionStatus`(plan/nextBillingDate/isTrialEligible)와 달리 정기 결제 필드가 없다 — 실제 엔티티 클래스는 아직 코드에 없으므로 app-developer와 필드명 확정 필요 |

이전 버전에 있던 `LibraryContent`, `LibraryCategory`, `Paginated<T>`(라이브러리 목록 응답 공용 래퍼)는 **삭제한다** — 해당 기능이 별도 앱(English News Shadowing Lab)으로 이전되며 이 앱 코드에서 완전히 제거되었고(`purchase_repository.dart`/`fake_purchase_repository.dart` 확인 결과 관련 타입 없음), `Paginated<T>`를 사용할 목록형 API도 이 앱에는 더 이상 없다.

---

## 7. 캐싱 전략

| 데이터 유형 | 캐시 방식 | TTL | 무효화 조건 |
|---|---|---|---|
| 사용자 세션(accessToken) | 메모리 + Secure Storage (2절 채택 시에만 해당) | 1시간(만료 시 자동 refresh) | 로그아웃, refresh 실패 |
| 내 파일 문장 세그먼트(로컬 무음감지/자막파싱 결과, API 아님) | 로컬 DB(Drift/Isar, 무제한) | 없음(사용자 삭제 전까지 영구) | 사용자 삭제, 재분석 요청 |
| 광고 제거 구매 상태 | 현재: 로컬 KV(`LocalKvStore`, 무제한) / 실 구현 시: 메모리 + 디스크(마지막 조회값) | 현재: 없음(영구) / 실 구현 시: 포그라운드 전환마다 재확인 | 구매/복원 직후 즉시 갱신(현재 Fake 구현도 이미 이렇게 동작), 실 구현 시 환불 웹훅 반영 |

이전 버전에 있던 라이브러리 오늘의 뉴스/카테고리/콘텐츠 상세/오프라인 오디오 캐시 행은 **삭제한다** — 해당 데이터와 캐시 정책 자체가 별도 앱으로 이전되었다.

---

## 8. 오프라인 지원

- **읽기**: 내 파일(Tab1)은 로컬 저장이 원본이고 문장분리도 로컬 처리이므로 오프라인에서도 완전 정상 동작(서버 호출 자체가 없음, `MediaRepository`/`StatsRepository`/`SettingsRepository`/`SegmentationRepository`는 전부 로컬 전용이므로 이 문서 범위 밖). 광고 제거 구매 상태(`watchAdsRemoved()`)는 로컬 캐시 값을 그대로 사용하므로 오프라인에서도 마지막으로 알려진 상태를 정상 표시한다.
- **쓰기**: 이 앱에서 서버로 향하는 "쓰기"는 (미구현) 구매 영수증 검증(`POST /v1/purchase/verify`, 5절) 하나뿐이며, 이는 온라인 상태에서만 시도하는 명시적 사용자 액션(결제/복원)이라 오프라인 큐잉 대상이 아니다 — 오프라인 시에는 구매/복원 버튼을 비활성화하고 안내만 표시한다(3-3절).
- **충돌 해결**: 적용될 데이터가 사실상 없다(세그먼트는 로컬에만 존재, 구매 상태는 스토어가 유일한 진실 소스). 이 항목은 참고용으로만 남겨두고 v2에서 서버 동기화가 필요한 기능이 새로 생기면 그때 재설계한다.

---

## 9. 에러 처리 매트릭스

백엔드 호출 후보가 (미구현) 구매 영수증 검증(5절) 하나뿐이므로, 업로드/STT 파이프라인·콘텐츠 라이브러리에서만 발생하던 코드(409 파트 충돌, 413 파일 용량 초과, 415 지원하지 않는 형식, 422 STT 동의 누락, 라이브러리 잠금 콘텐츠 접근 관련 403 시나리오)는 트리거할 엔드포인트 자체가 없어 **매트릭스에서 삭제**한다.

| HTTP 코드 | 의미 | 앱 처리 | 사용자 메시지 |
|---|---|---|---|
| 400 | 요청 형식 오류(예: 잘못된 영수증 포맷) | `ValidationFailure` | "입력을 확인해주세요" |
| 401 | 토큰 만료/무효 (2절 채택 시에만 발생 가능) | `AuthInterceptor`가 자동 refresh 후 재시도(3-2), 재실패 시 익명 재발급 | 사용자에게는 대부분 비노출(자동 처리) |
| 403 | 권한 없음(예: 이미 처리된 영수증으로 다른 계정 귀속 시도 등) | `PurchaseFailure` | "구매 정보를 확인할 수 없어요" |
| 404 | 리소스 없음(존재하지 않는 상품 ID 등) | `PurchaseFailure` | "상품 정보를 찾을 수 없습니다" |
| 429 | 레이트리밋 | `RetryInterceptor` 지수 백오프 | "잠시 후 다시 시도" |
| 500/502/503 | 서버 오류 | `RetryInterceptor` 재시도(멱등 요청만), 최종 실패 시 `ServerFailure`/`PurchaseFailure` | "서버 오류, 재시도 중" → 재시도 소진 시 "다시 시도" 버튼 |
| 타임아웃/연결 끊김 | 네트워크 불안정 | `NetworkFailure`, 3단계 네트워크 상태 배너(3-3) | "네트워크 연결을 확인해주세요" |

---

## 10. 음성 데이터 외부 전송 관련 개인정보 기술 대응 — 대부분 해소됨

**2026-08-05 결정으로 이 절이 다루던 문제 대부분이 사라졌다.** 이전 버전은 사용자가 업로드한 음성이 STT 벤더(AssemblyAI 등)로 전송되는 것을 전제로 사전 동의 Bottom Sheet, 서버측 동의 감사 로그, 벤더/원본 오디오 삭제 정책, Apple/Google 심사 답변 정합성 확보 방안을 상세히 설계했었다. **사용자 업로드 음성/영상이 문장분리를 위해 기기 밖으로 나가는 경로 자체가 완전히 제거되었으므로, 이 모든 절차가 통째로 불필요해졌다.**

### 10-1. 더 이상 필요 없는 것 (참고용 기록)

- STT 전송 동의 Bottom Sheet(업로드 전 1회 노출) — **불필요**. 어떤 사용자 오디오도 제3자/자사 서버로 전송되지 않으므로 동의를 받을 대상 행위 자체가 없다.
- 서버측 동의 감사 로그, 동의 거부 시 업로드 차단(구 422 케이스) — **불필요**.
- 원본 오디오/STT 벤더 사본 삭제 정책(스토리지 라이프사이클 TTL, 벤더 삭제 API 연동) — **불필요**. 오디오가 애초에 서버에 도달하지 않으므로 삭제할 서버측 사본이 없다.
- 국외 이전 고지("음성 데이터가 미국 소재 벤더로 전송") — **불필요**. 사용자 업로드 음성에 대해서는 국외 이전 항목 자체가 없다(store-manager에게 `04_store_listing.md` 개인정보처리방침에서 이 조항을 삭제/수정하도록 전달 필요 — 11절 전달 사항 참고).

### 10-2. 실제로 남아있는(또는 남게 될) 데이터 흐름

이제 앱이 외부로 전송할 가능성이 있는 사용자 관련 데이터는 사실상 다음 하나뿐이며, 그마저도 아직 구현 전이다.

| 데이터 | 전송 대상 | 목적 | 보존 기간 |
|---|---|---|---|
| (미구현) 스토어 영수증(iOS JWS)/구매 토큰(Android purchaseToken) | 자체 백엔드 → App Store Server API / Google Play Developer API | 광고 제거 구매 유효성 검증(5절) | 백엔드가 엔타이틀먼트 상태만 보관, 원본 영수증 원문은 검증 즉시 폐기 권장(장기 보관 불필요) |

- store-manager에게 전달: App Privacy Nutrition Label / Google Data Safety Form에서 "오디오 데이터 → 제3자 공유" 항목은 **삭제(해당 없음)로 변경**하고, 콘텐츠 라이브러리 관련 데이터 공유 항목(있었다면)도 함께 삭제 — 남는 데이터 공유 항목은 (구매 영수증 검증을 실제로 붙이는 시점부터) "구매/거래 정보 → 스토어 사업자와 공유(영수증 검증 목적)" 정도로 매우 단순하다.

---

## 11. Fake → Real 구현체 교체 가이드

app-developer의 산출물은 `presentation/providers/repository_providers.dart` **한 곳**에서 구현체를 주입하므로, 교체는 이 파일 몇 줄 + 새 구현체 클래스 추가로 끝난다(presentation 레이어 수정 불필요). **`SegmentationRepository`는 이 교체 대상에서 제외된다** — 로컬 구현체가 곧 최종 구현체이므로 Fake→Real 전환 자체가 없다(4절).

1. `core/network/` 신설: `dio_client.dart`(3절 BaseOptions+인터셉터 조립), (2절 채택 시) `auth_interceptor.dart`, `retry_interceptor.dart`, `error_mapping_interceptor.dart`, (2절 채택 시) `token_storage.dart`(flutter_secure_storage 래퍼).
2. `data/repositories/`에 `RemotePurchaseRepository` 추가 — `PurchaseRepository`를 `implements`하고, `purchaseRemoveAds()`/`restorePurchases()` 내부에서 (a) `in_app_purchase` 패키지로 StoreKit2/Play Billing 구매·복원 UI를 호출하고, (b) 획득한 영수증/구매 토큰을 5-2절 `POST /v1/purchase/verify`로 전송해 서버 검증까지 마친 뒤 완료 처리한다. `watchAdsRemoved()`는 로컬 캐시 + (구현한다면) `GET /v1/purchase/status` 폴링을 조합해 구현(5-3절).
3. `repository_providers.dart`에서 `FakePurchaseRepository()` → `RemotePurchaseRepository(dioClient, inAppPurchase)`로 교체. 환경별(dev/staging/prod) 분기는 `--dart-define=API_BASE_URL=...`로 처리. `FakeSegmentationRepository`는 애초에 로컬 최종 구현체(무음감지/자막파싱)로 대체되므로 이 흐름과 무관.
4. 마이그레이션 순서 권장: (1) 2절의 자체 인증이 실제로 필요한지 app-developer와 재확인 → (필요하다면) 인증 배선 → (2) `RemotePurchaseRepository`(스토어 심사 전 필수, 실 결제 없이는 심사 제출 불가) → (3) 5-2절 웹훅(환불 반영, 우선순위 낮음, v1.1 이후도 무방).

---

## 앱 개발자 전달 사항

- **STT/문장분리 관련 화면·로직은 API 연동이 필요 없다** — 이전 전달 사항 중 "STT 동의 Bottom Sheet 신규 화면", "설정 'AI 처리 동의 상태' 항목", "업로드 presigned 분할 업로드/재개 로직", "`SegmentationJobState` 서버 enum 공유"는 **모두 철회한다.** 무음 감지/자막 파싱은 순수 로컬 로직이므로 관련 구현 세부사항은 `02_app_architecture.md`를 따르면 되고, 이 문서(API 연동)에서 더 요구할 것이 없다.
- **콘텐츠 라이브러리/구독 관련 전달 사항은 전부 철회한다** — `LibraryContent.audioUrl` 필드 추가 요청, `SubscriptionRepository.cancel()`의 딥링크 동작 안내 등 이전 버전의 라이브러리·구독 관련 항목은 해당 기능이 별도 앱(English News Shadowing Lab)으로 이전되며 이 앱과 무관해졌다.
- **`PurchaseRepository`는 `cancel()`이 없다** — 일회성 구매라 "해지" UI/로직 자체가 필요 없다. 구독 시절처럼 스토어 구독 관리 화면으로 딥링크시키는 버튼은 이 앱에는 불필요. 다만 **환불 시 광고가 다시 노출되는 것을 사용자에게 어떻게 안내할지**(예: 환불 확인 시점에 조용히 반영 vs. 별도 알림)는 아직 정해지지 않았으므로 UX 설계자/app-developer와 확인 필요(5-2절).
- **`PurchaseStatus` 엔티티가 아직 코드에 없다** — 실 서버 검증을 붙이기 전이라도, `RemotePurchaseRepository` 작성 시점에는 6절의 `isAdRemoved`/`purchasedAt` 필드로 신규 엔티티를 만들어야 한다(기존 `SubscriptionStatus`를 재활용하지 말 것 — `plan`/`nextBillingDate` 등 정기결제 전용 필드가 섞여 들어가면 혼란스럽다).
- **Repository 교체 지점은 `repository_providers.dart` 한 곳, 대상은 `PurchaseRepository` 하나뿐** — 11절 가이드 참고. `SegmentationRepository`는 로컬 구현체가 최종본이라 교체 대상이 아님을 재확인.
- **개인정보처리방침 관련**: 설정 화면의 "이용약관/개인정보처리방침" 하위에 있던(있었을) STT/AI 처리 동의 및 콘텐츠 라이브러리 관련 UI 항목은 삭제 대상 — store-manager와 함께 `04_store_listing.md`의 개인정보처리방침 문구도 맞춰 정리 필요(10절 참고).

## QA 엔지니어 전달 사항

- **백엔드 연동 범위가 (미구현) 구매 영수증 검증 하나로 축소되었다** — 이전 버전에 있던 STT Mock 서버, 콘텐츠 라이브러리/구독 관련 Mock·시나리오는 **모두 철회한다.** 문장분리(무음 감지/자막 파싱) 테스트는 API mock이 필요 없는 순수 클라이언트 로직 테스트이므로 `05_qa_report.md`에서 별도로 다룬다.
- **현재는 전부 Fake라 "실제 결제 API 테스트"는 아직 성립하지 않는다** — `FakePurchaseRepository`는 로컬 KV 저장만 하므로, 지금 시점의 QA는 (a) 구매/복원 버튼 탭 시 로딩 상태·완료 상태 전환이 UX대로 되는지, (b) `watchAdsRemoved()` 변화가 배너 광고/전면 광고/설정 화면 표시에 즉시 반영되는지에 집중한다. 실 스토어 SDK/서버 검증 연동 이후에 iOS Sandbox 테스터 계정/Android 라이선스 테스트 계정을 활용한 실결제 시나리오 QA를 별도로 계획해야 한다(store-manager와 조율).
- **우선 검증 시나리오(축소됨)**:
  1. 오프라인 상태에서 내 파일 업로드→문장분리(무음 감지/자막 파싱)가 정말로 네트워크 호출 없이 끝까지 동작하는지(비행기 모드에서 검증) — 4절/8절, 이번 결정의 핵심 약속이므로 회귀 방지 차원에서 최우선순위 검증 요청.
  2. `purchaseRemoveAds()` 실패 시 `PurchaseFailure`가 구매 시트에 인라인 에러로 노출되고 재시도가 가능한지.
  3. `restorePurchases()`가 (현재 Fake 기준으로는) 재설치 후에도 로컬 저장값을 정확히 복원하는지 — 단, 지금은 기기 로컬 저장소 기반 시뮬레이션이라 "다른 기기에서의 복원"은 의미 있게 테스트할 수 없다는 한계를 인지하고, 실 스토어 연동 후 별도로 재검증 필요.
  4. (2절 관련) 자체 인증을 실제로 채택하게 될 경우, 401 동시다발 상황에서 refresh가 중복 호출되지 않는지 — 3-2절. 현재는 호출 대상 자체가 없어 해당 사항 없음.
