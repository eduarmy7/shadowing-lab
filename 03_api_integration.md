# API 연동 명세 — 쉐도잉랩(ShadowingLab, 구 따라/TTARA) 쉐도잉 학습 앱

> 작성: api-integrator · 기준일: 2026-08-05
> 참고 문서: `00_input.md`(2026-08-05 STT 완전 폐기 결정), `01_ux_design.md`(UX 설계·API 연동 전달 사항), `02_app_architecture.md`(Repository 인터페이스, 로컬 문장분리 구현), `04_store_listing.md`(개인정보/심사 리스크)
> 대상 Repository: `library_repository.dart`, `subscription_repository.dart` (실제 백엔드 연동 대상, `_workspace/02_app_code/lib/`) / `segmentation_repository.dart` (2026-08-05부터 **로컬 전용, 이 문서의 API 연동 대상 아님** — 4절 참고)
>
> **2026-08-05 결정 반영**: 유료 STT 벤더(AssemblyAI 등)를 앱 전체에서 완전히 제거한다. 사용자가 개발자의 유료 API를 소비시키는 흐름을 하나도 남기지 않는 것이 확정 요구사항이며, 이는 무료 티어에 국한된 정책이 아니라 앱 전체 원칙이다. 이 결정으로 이전 버전(2026-08-04)의 4절(STT/문장분리 API) 전체와, 그에 의존하던 여러 절의 서술이 대체/삭제되었다.

---

## 0. 문서 범위와 전제

- 실제 백엔드는 아직 존재하지 않는다. 이 문서는 **자체 백엔드 API(`api.ttara.app`)를 새로 설계**하되, 2026-08-05 결정 이후 이 백엔드가 실제로 담당하는 일은 **(1) 콘텐츠 라이브러리(CNN/BBC 큐레이션 뉴스) 서빙**과 **(2) 스토어 구독 영수증 검증** 두 가지뿐이다. 벤더 STT 호출, 오디오 업로드/작업큐, 문장분리 파이프라인은 백엔드 설계 범위에서 완전히 제외되었다.
- `SegmentationRepository`(문장 자동분리)는 **이 문서의 API 연동 대상이 아니다.** 무음 감지(음성만 업로드)와 자막 파일 파싱(영상+자막 업로드) 모두 클라이언트 로컬 처리이며 어떤 네트워크 호출도 발생시키지 않는다. 따라서 `MediaRepository`/`StatsRepository`/`SettingsRepository`와 마찬가지로 **로컬 전용 Repository**로 재분류한다 — 실제 구현 로직은 app-developer가 담당하는 `02_app_architecture.md`를 참고하고, 이 문서에서는 4절에서 그 이유와 경계만 짧게 명시한다.
- 우선순위: **LibraryRepository(CNN/BBC 콘텐츠 서빙) > SubscriptionRepository(스토어 영수증 검증)** 순으로 상세도를 배분한다 — 이 두 가지가 이제 백엔드가 실제로 처리하는 전부이기 때문이다. SegmentationRepository는 API 연동이 없으므로 상세 설계 대상에서 제외한다.

---

## 1. 전체 아키텍처

```
Flutter App (dio)
   │  Bearer accessToken (JWT)
   ▼
자체 백엔드 API  api.ttara.app/v1   ← 이 문서가 설계하는 대상
   │                                                    │
   │ 콘텐츠 CMS/DB (일 1회 배치 수집, 5절)                    │ 영수증 검증
   ▼                                                    ▼
큐레이션 콘텐츠 DB                              App Store Server API /
(CNN/BBC 공식 트랜스크립트 기반,                    Google Play Developer API
 매일 1건 자동/반자동 수집 파이프라인이 등록)

※ 사용자 업로드 음성/영상 파일은 이 다이어그램에 등장하지 않는다 — 문장 분리는
  전적으로 기기 내(로컬)에서 처리되고, 원본 파일도 서버로 전송되지 않는다(4절).
```

- **백엔드가 실제로 하는 일은 두 가지뿐이다**: (1) CNN/BBC 큐레이션 콘텐츠를 매일 수집·저장하고 구독 상태에 따라 서빙(5절), (2) 스토어 구독 영수증/구매 토큰을 서버에서 재검증(6절). 벤더 STT 프록시, 오디오 업로드, 문장분리 후처리 파이프라인은 2026-08-05 결정으로 백엔드 설계에서 제거되었다 — 사용자가 업로드한 음성/영상은 기기 밖으로 나가지 않는다.
- **인증은 남아있는 두 API 호출의 전제**: 익명 사용자도 백엔드가 발급한 JWT를 갖고 호출한다(2절). 구독 엔타이틀먼트 조회(라이브러리 잠금 해제 여부 판별 포함)에 필요하다. STT Job 소유권 확인이나 음성 데이터 삭제 요청 식별 같은 용도는 더 이상 존재하지 않는다.

---

## 2. 인증 흐름 — 기기 기반 익명 인증 (+ 선택적 이메일 연결)

### 2-1. 방식 결정 및 근거

| 검토 옵션 | 채택 여부 | 근거 |
|---|---|---|
| 이메일/비밀번호 회원가입 필수 | ❌ | UX 설계서의 두 페르소나 모두 "복잡해서 이탈"이 핵심 리스크로 지목됨. 무료 핵심 기능(내 파일 쉐도잉)은 로그인 없이도 100% 동작해야 한다는 00_input.md/01_ux_design.md 원칙과 충돌 |
| 완전 무인증(디바이스 로컬 상태만 사용) | ❌ | 구독 엔타이틀먼트를 기기에만 묶으면 기기 변경/재설치 시 구독을 잃는 문제 발생. (2026-08-05 결정 이후로는 STT Job 소유권 식별이라는 사유는 더 이상 없다 — 남은 이유는 구독 엔타이틀먼트 하나뿐이지만 그것만으로도 충분히 인증이 필요) | 
| **기기 기반 익명 인증(JWT) + 선택적 이메일 연결** | ✅ **채택** | 앱 최초 실행 시 마찰 없이 자동 발급. 구독은 `userId`에 귀속되므로 앱 재설치 후 `restorePurchases()`로 복구 가능(스토어 영수증 재검증 시 동일 userId로 재연결). 설정 화면(#12)에 이미 "로그인 계정" 항목이 존재하므로, 이메일 연결은 UX와 이미 정합됨 — 단, 필수가 아닌 "백업/기기변경 대비" 선택 기능으로 위치시킴 |

### 2-2. 토큰 저장

| 플랫폼 | 저장소 |
|---|---|
| iOS | Keychain (`flutter_secure_storage`, `first_unlock_this_device` 접근성) |
| Android | EncryptedSharedPreferences (`flutter_secure_storage` 동일 패키지가 자동 위임) |

저장 키: `accessToken`, `refreshToken`, `userId`, `deviceId`(최초 1회 생성 후 고정, `uuid` v4).

### 2-3. 엔드포인트

| 메서드 | 엔드포인트 | 설명 |
|---|---|---|
| POST | `/v1/auth/anonymous` | 최초 실행 시 1회 호출. Body: `{ "deviceId": "uuid", "platform": "ios\|android", "appVersion": "1.0.0" }` → `{ "userId", "accessToken", "refreshToken", "expiresIn": 3600 }` |
| POST | `/v1/auth/refresh` | Body: `{ "refreshToken" }` → 새 토큰 쌍. Refresh Token도 만료/폐기 시 401 → 재로그인(=`/v1/auth/anonymous` 재호출, 단 기존 `deviceId` 유지 시 서버가 동일 `userId`로 매핑 시도) |
| POST | `/v1/auth/link-email` | 선택 기능. Body: `{ "email" }` → 매직링크 이메일 발송(비밀번호 없음) |
| GET | `/v1/auth/link-email/verify?token=...` | 딥링크로 앱 복귀 시 호출 → 기존 익명 `userId`에 이메일 연결, 응답으로 갱신된 토큰 쌍 |
| POST | `/v1/auth/logout` | 이메일 연결된 계정만 유효(로컬 토큰 폐기 + 서버 refreshToken revoke) |

### 2-4. 플로우

```
1. 앱 최초 실행 → deviceId 로컬 생성(1회) → POST /v1/auth/anonymous
2. accessToken(1시간)/refreshToken(90일) 수신 → Secure Storage 저장
3. 모든 API 요청에 Authorization: Bearer {accessToken} 첨부
4. 401 수신 → AuthInterceptor가 refreshToken으로 갱신 시도(동시 요청은 단일 refresh로 합류, 4-2 참조)
5. refresh도 401/실패 → accessToken/refreshToken 삭제 후 /v1/auth/anonymous 재발급(사용자는 인지 못함,
   단 이 경우 서버측 userId가 바뀔 수 있어 구독 상태는 restorePurchases()로 재연결 필요 — #9 화면에 안내 토스트)
6. (선택) 설정 화면에서 이메일 연결 시 이후 재설치해도 이메일 인증으로 동일 userId 복구 가능
```

- 무료 핵심 기능(파일 업로드/쉐도잉 학습)은 익명 토큰만으로 전부 동작. 로그인 여부와 무관하게 온보딩 완료 직후 백그라운드에서 조용히 발급되므로 UX 흐름에 로그인 화면이 끼어들지 않는다.

---

## 3. 네트워크 계층 공통 설계

### 3-1. HTTP 클라이언트

- **패키지**: `dio` (+ `dio_smart_retry` 대신 커스텀 RetryInterceptor로 도메인별 재시도 정책 세분화), `connectivity_plus`(네트워크 상태 감지), `flutter_secure_storage`(토큰), `pretty_dio_logger`(디버그 빌드 전용).
- **BaseOptions**: `baseUrl: https://api.ttara.app/v1`, `connectTimeout: 10s`, `receiveTimeout: 20s` — API 호출 대상이 라이브러리 조회(5절)/구독 검증(6절)뿐인 가벼운 REST 호출이라 도메인별 특수 타임아웃 오버라이드가 불필요해졌다(이전 버전의 업로드/STT job 폴링용 타임아웃 예외는 해당 기능 자체가 제거되어 함께 삭제).
- **인터셉터 체인 순서** (`InterceptorsWrapper` 여러 개를 순서대로 등록):
  1. `AuthInterceptor` — 모든 요청에 `Authorization: Bearer {accessToken}` 첨부. 응답 401 감지 시 갱신 로직 수행(3-2).
  2. `RetryInterceptor` — 멱등 요청(GET, PUT, 그리고 명시적으로 멱등 설계된 POST — 예: `POST /v1/subscription/verify`는 동일 영수증 재전송해도 안전, 6-2절)에 한해 5xx/timeout/connection error를 지수 백오프(0.5s→1s→2s, ±20% jitter)로 최대 3회 재시도. 4xx는 재시도하지 않음.
  3. `ErrorMappingInterceptor` — `DioException` → 앱 도메인 `Failure` 타입(`core/error/failure.dart`)으로 변환 후 rethrow. 매핑 규칙은 10절 에러 매트릭스 참고.
  4. `LoggingInterceptor` — `kDebugMode`에서만 활성화, 토큰/영수증 등 민감 필드는 마스킹 후 로그.

### 3-2. 401 처리 / 토큰 갱신 동시성 제어

여러 요청이 동시에 401을 맞는 경우(예: 학습화면에서 오디오 URL 요청 + 통계 요청이 동시 실행) 중복 refresh 호출을 막기 위해 **단일 Completer 락**을 사용한다:

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
| **느린 네트워크** | 연결은 있으나 최근 요청 평균 RTT ≥ 1.5s | 라이브러리 화면에 "네트워크가 느려요, 시간이 더 걸릴 수 있어요" 인라인 안내만 추가(차단하지 않음). 내 파일 업로드/문장분리는 로컬 처리이므로 네트워크 상태와 무관 |
| **오프라인** | `connectivity_plus`가 `none` 보고 | 라이브러리(#7/#8) 등 서버 의존 화면은 캐시 데이터 + "오프라인" 배너로 대체(8절). 내 파일 쉐도잉(#1/#5)은 완전 오프라인 정상 동작(무음 감지/자막 파싱이 모두 로컬 처리이므로 서버 호출 자체가 없음) |

### 3-4. 보안 원칙

- Library/Subscription API가 내부적으로 사용하는 키(CNN/BBC 피드 접근 자격증명, App Store/Google Play 서버 API 키 등)는 전부 **백엔드에만 보관**, 클라이언트 코드/빌드 산출물에는 어떤 API 키도 하드코딩하지 않는다. 클라이언트가 아는 것은 `baseUrl`과 발급받은 사용자 JWT뿐이다. (참고: STT 벤더 키 자체가 더 이상 존재하지 않는다 — 2026-08-05 결정으로 벤더 연동이 전부 제거됨.)
- `baseUrl`, 환경별(dev/staging/prod) 엔드포인트는 `--dart-define` 빌드 변수 또는 `flutter_dotenv`(단, `.env`는 `.gitignore` 처리)로 주입.
- 전 구간 TLS 1.2+ 강제, 인증서 피닝은 MVP 범위 밖(v2 검토).

---

## 4. 문장분리 — `SegmentationRepository` (API 연동 없음, 로컬 전용)

**이 절의 결론은 한 문장으로 요약된다: `SegmentationRepository`는 백엔드/외부 API를 전혀 호출하지 않는다.** 아래는 이전 버전(2026-08-04, STT 벤더 채택안)이 왜 폐기되었는지와, 그 결과 이 문서의 책임 범위가 어떻게 줄어드는지를 짧게 기록한다. 실제 로컬 처리 구현(무음 감지 알고리즘, SRT/VTT 파서 등)은 `02_app_architecture.md`가 소유하며, 이 문서는 "여기엔 API가 없다"는 경계만 명시한다.

### 4-1. 왜 API가 없는가 — 2026-08-05 결정 배경

- **이전 설계(폐기됨)**: 클라우드 STT 벤더(AssemblyAI 등)에 오디오를 업로드해 문장 경계+신뢰도를 받아오는 비동기 Job 파이프라인(Presigned 분할 업로드 → Job 제출/폴링/SSE → 결과 저장 → 벤더 삭제 정책)을 설계했었다. 이 구조는 사용자 1인의 파일 업로드마다 벤더에 종량 과금이 발생하는 구조였다.
- **폐기 사유**: 개발자가 "사용자가 어떤 경로로든 개발자의 유료 API 호출을 트리거하는 일이 없어야 한다"를 하드 요구사항으로 확정(`00_input.md` 2026-08-05). 이는 무료 티어에만 적용되는 제약이 아니라 앱 전체 원칙이며, 유료 구독자에게도 사용자 업로드 파일에 대한 STT 호출은 발생하지 않는다.
- **대체 방식**: 두 가지 로컬 경로만 존재한다.
  1. **음성만 업로드**: 클라이언트가 무음/휴지(pause) 구간을 신호 처리로 감지해 문장 경계만 나눈다. 텍스트는 없음 — 문장 번호만 표시하고 사용자는 듣고 따라 말한다.
  2. **영상+자막(SRT/VTT) 업로드**: 자막 파일 자체의 큐 타임스탬프/텍스트를 그대로 문장 경계·텍스트로 사용한다(파싱만 필요, AI 인식 없음).
- 두 경로 모두 **네트워크 호출이 0건**이다. 오디오/영상 원본은 기기 밖으로 전송되지 않는다.

### 4-2. Repository 분류 변경

- `SegmentationRepository`는 이제 `MediaRepository`/`StatsRepository`/`SettingsRepository`와 동일하게 **로컬 전용 Repository**로 취급한다(0절 참고). `repository_providers.dart`에서 이 Repository는 애초에 "Fake → Real(원격)" 교체 대상이 아니다 — 로컬 구현체가 곧 최종 구현체다.
- 이전 버전 4-7절의 `SentenceSegment` 스키마(`id/mediaId/index/text/translation/startMs/endMs/confidence/edited/repeatCountOverride`)는 필드 구조 자체는 유지 가능하지만, `confidence`(벤더 신뢰도)·`translation`(번역 API 결과)처럼 서버/벤더 응답에서 채우던 필드는 이제 값을 채울 소스가 없다 — 로컬 처리 방식에 맞는 필드 축소/의미 재정의는 app-developer의 `02_app_architecture.md` 소관이며, 이 문서는 "서버가 이 필드들을 채워주지 않는다"는 점만 알린다.
- 이전 버전의 Presigned 분할 업로드, Job 폴링/SSE, `SttProvider` 어댑터, 벤더 삭제 API 연동, Mock STT 서버는 전부 **삭제 대상**이며 어떤 형태로도 재사용하지 않는다.

### 4-3. app-developer/QA 확인 필요 사항

- 로컬 무음 감지·자막 파싱 로직의 성능(대용량 파일 처리 시간, 배터리 소모)과 정확도는 API 연동 이슈가 아니므로 이 문서 범위 밖이다 — `02_app_architecture.md`/QA(`05_qa_report.md`)에서 다룬다.
- 오프라인 지원(9절)에서 "내 파일 쉐도잉"은 애초에 서버 호출이 없으므로 네트워크 상태와 완전히 무관하게 동작한다는 점만 이 문서에서 재확인한다.

---

## 5. 콘텐츠 라이브러리 API — `LibraryRepository`

**2026-08-05(2차) 결정으로 큐레이션 콘텐츠는 두 트랙으로 구성된다**(00_input.md): (a) **오늘의 뉴스** — CNN/BBC 데일리 뉴스, 각 방송사의 **공식 트랜스크립트/자막 피드(RSS 등)를 그대로 사용**(4절의 클라이언트 자막 매칭과 동일 원칙: "소스 자체의 타임스탬프/텍스트를 그대로 쓴다, AI 음성인식으로 새로 만들지 않는다"), (b) **일상회화/비즈니스/여행** — CNN/BBC와 무관하게 **팀이 직접 작성(추후 녹음)하는 자체 제작 다이얼로그**, 카테고리당 10편 정도로 시작해 계속 추가. 두 트랙 모두 클라이언트 관점에서는 동일한 `LibraryContent`/`SentenceSegment` 스키마와 5-1 엔드포인트로 서빙되며, 차이는 순전히 **콘텐츠가 서버 DB에 어떻게 채워지는지**(자동 수집 vs. 수동 등록)에 있다 — 어느 쪽도 STT 파이프라인이 필요 없는 단순한 표준 REST + 페이지네이션 설계로 충분하다.

### 5-0. 콘텐츠 적재 방식 (트랙별로 다름, 설계 수준 개요)

라이브러리 콘텐츠는 사용자 요청 시점이 아니라 **백엔드가 사전에 CMS/DB에 적재**해두고, 아래 5-1 엔드포인트는 이미 적재된 콘텐츠를 읽기만 한다(사용자당 과금이 아닌 고정 비용이라는 점이 `00_input.md` 수익모델의 전제 — 두 트랙 모두 동일).

**(a) 오늘의 뉴스 — 자동/반자동 수집 잡** (매일 CNN 2편 + BBC 2편 = 4편 갱신):
```
[스케줄러, 매일 1회] → CNN·BBC 뉴스 API/RSS에서 오늘자 아이템 CNN 2건 + BBC 2건 선택
   → 각 아이템의 공식 오디오(또는 영상의 오디오 트랙) + 공식 트랜스크립트/자막(SRT/VTT 등) 취득
   → 트랜스크립트 자체의 타임스탬프를 문장 경계로 그대로 사용해 세그먼트화(AI STT 미사용)
   → 오브젝트 스토리지에 오디오 저장 + DB(segments/LibraryContent 테이블)에 등록, categoryId="today"
   → 이후 5-1의 GET 엔드포인트들이 이 데이터를 서빙
```
- 완전 자동화 여부(무인 잡 vs. 사람이 매일 4건 골라 트리거)는 운영 단계에서 결정할 세부사항이며 이 문서 범위 밖이다.
- 수집 실패 시(오늘자 아이템 없음, 피드 장애 등) "오늘의 뉴스"가 갱신되지 않고 전일 콘텐츠가 유지되는 정도의 낮은 심각도로 처리하면 충분 — 실시간성이 핵심 가치가 아니므로 알림/재시도는 운영 스크립트 수준에서 다룬다.

**(b) 일상회화/비즈니스/여행 — 수동 콘텐츠 등록** (자동 수집 잡 없음):
```
[팀이 오프라인으로 작업] → 대본 작성(카테고리당 10편 목표로 시작, 계속 추가) → (추후) 성우 녹음/오디오 제작
   → 대본 자체의 문장 구분을 타임스탬프로 변환(수동 또는 간단한 툴, AI STT 미사용)
   → 관리자 콘솔/CMS를 통해 DB(segments/LibraryContent 테이블)에 직접 등록, categoryId="daily"|"business"|"travel"
   → 이후 5-1의 GET 엔드포인트들이 이 데이터를 서빙 — (a)와 동일한 엔드포인트, 클라이언트 변경 없음
```
- 이 트랙은 CNN/BBC와 무관한 자체 저작물이므로 아래 저작권 리스크 대상이 **아니다**.
- 관리자 콘솔/CMS의 구체적 형태(스프레드시트 임포트 vs. 전용 어드민 UI)는 운영 단계 결정 사항 — 이 문서 범위 밖.
- **2026-08-05 기준 진행 상태**: 문서/코드 구조(스키마, mock 데이터)만 반영됨. 실제 대본 10편/카테고리 작문 및 등록은 아직 진행되지 않았다(00_input.md와 동일 상태).

> ⚠️ **미해결 리스크 (이 문서에서 해결하지 않음, 법무/사업 검토 필요) — (a) 오늘의 뉴스 트랙에만 해당**: CNN/BBC의 오디오와 트랜스크립트를 자체 앱에서 재가공·재배포하는 것은 **저작권/라이선싱 클리어런스가 선행되어야 하는 사안**이다. 공식 피드가 공개돼 있다는 사실이 상업적 재배포 허가를 의미하지 않는다. 이 리스크는 `04_store_listing.md`(store-manager 소관)에서 추적하도록 이관하며, 법무 검토/방송사와의 라이선스 계약 없이는 (a) 트랙의 설계를 실제 구현으로 진행해서는 안 된다. (b) 일상회화/비즈니스/여행 트랙은 자체 저작물이라 이 리스크와 무관하며 별도 법무 검토 없이 진행 가능하다.

### 5-1. 엔드포인트

| 메서드 | 엔드포인트 | 요청 | 응답 |
|---|---|---|---|
| GET | `/v1/library/categories` | - | `[{ id, label }]` (`today`=오늘의 뉴스, `daily`=일상회화, `business`=비즈니스, `travel`=여행 — 4개 고정 카테고리) |
| GET | `/v1/library/today` | - | `LibraryContent[]` |
| GET | `/v1/library/content` | Query: `categoryId, cursor?, limit=20` | `{ items: LibraryContent[], nextCursor, hasMore }` (`Paginated<LibraryContent>` 1:1) |
| GET | `/v1/library/content/{id}` | - | `LibraryContent` |
| GET | `/v1/library/content/{id}/segments` | Header: `Authorization` 필수(엔타이틀먼트 판별용) | `{ segments: SentenceSegment[] }` |

- `getContentSegments`: 서버가 `Authorization` 토큰으로 구독 상태를 조회해 **비구독자는 앞 30초 분량 세그먼트만**, **구독자는 전체**를 반환한다(01_ux_design.md 권장 그대로 — 클라이언트는 `isLocked` 필드만 보고 UI 분기, 실제 접근 제한은 서버가 강제).
- `LibraryContent`에 현재 `previewAudioUrl`만 있고 전체 재생용 `audioUrl`이 없는 문제(02_app_architecture.md 인지된 gap)는 **서버가 매 요청마다 만료 15분짜리 서명된 URL을 `audioUrl` 필드로 추가 반환**하는 방식으로 해결 권장(구독자에게만 값 포함, 비구독자는 `null` — 저작권 있는 뉴스/회화 콘텐츠이므로 URL 유출로 인한 무단 접근을 짧은 TTL로 방지). 엔티티에 `audioUrl` 필드 추가는 app-developer와 별도 협의 필요.

### 5-2. 페이지네이션

- Cursor 기반(`nextCursor`는 서버가 발급하는 불투명 토큰, 클라이언트는 그대로 다음 요청에 전달). `limit` 기본 20, 최초 로드는 섹션별 10개 프리페치(01_ux_design.md 지침).
- 카드 높이 고정(썸네일 16:9 + 2줄 타이틀 고정 높이)으로 스켈레톤→실데이터 전환 시 레이아웃 시프트 방지 — 이는 UI 구현 사항이라 app-developer에게 재확인 요청.

### 5-3. 캐싱/오프라인

8절(캐싱 전략)/9절(오프라인 지원) 공통 정책을 따르되, 라이브러리 특화 사항:

- `cacheForOffline(contentId)`: 오디오 파일을 `flutter_cache_manager`로 앱 캐시 디렉토리에 다운로드, 메타데이터(`LibraryContent`, `segments`)는 로컬 KV/Drift에 저장. **최근 5개, 총 300MB 상한**(초과 시 LRU로 가장 오래된 항목 자동 축출).
- `getCachedContent()`: 로컬 인덱스만 조회(네트워크 호출 없음) — 오프라인 배너와 함께 #7 화면에 노출.
- 오늘의 뉴스(`/v1/library/today`)는 서버가 매일 06시(KST) 갱신하므로 `Cache-Control: max-age=3600` + `ETag` 응답, 클라이언트는 `If-None-Match`로 304 시 로컬 캐시 재사용(불필요 대역폭 절감).

---

## 6. 구독/결제 연동 — `SubscriptionRepository`

### 6-1. 흐름 (클라이언트 스토어 SDK + 서버 검증 2단계)

```
1. 클라이언트: in_app_purchase 패키지로 StoreKit2(iOS)/Play Billing(Android) 구매 UI 호출
2. 사용자 결제 완료 → 클라이언트가 영수증(iOS: JWS transaction) / 구매 토큰(Android: purchaseToken) 획득
3. POST /v1/subscription/verify
   Body: { platform: "ios"|"android", productId, receiptData (iOS) | purchaseToken (Android) }
   → 서버가 App Store Server API(JWS 검증) 또는 Google Play Developer API
     (purchases.subscriptions.get)로 실제 유효성 재검증
   → 서버 DB에 엔타이틀먼트를 userId에 귀속 저장
   → { isActive: true, plan, nextBillingDate, isTrialEligible } (SubscriptionStatus 그대로)
4. purchase()는 위 1~3을 하나로 감싼 Repository 메서드로 구현(UI는 구현 세부사항 모름 — 인터페이스 그대로 유지)
```

### 6-2. 엔드포인트

| 메서드 | 엔드포인트 | 설명 |
|---|---|---|
| GET | `/v1/subscription/status` | 현재 엔타이틀먼트 조회 → `getStatus()` |
| POST | `/v1/subscription/verify` | 위 흐름의 3번 → `purchase()`/`restorePurchases()` 공용(멱등 — 동일 영수증 재전송해도 안전) |
| POST | `/v1/subscription/webhooks/apple` | Apple **App Store Server Notifications V2** 수신(서버-서버, 클라이언트 무관). 갱신/해지/환불/결제실패를 서버가 즉시 반영 |
| POST | `/v1/subscription/webhooks/google` | Google **RTDN(Real-time Developer Notifications, Pub/Sub)** 수신, 동일 목적 |

### 6-3. `watchStatus()` / `restorePurchases()` / `cancel()` 구현 방식

- **`watchStatus()`**: 서버 푸시(RTDN/App Store 알림)가 즉시 클라이언트로 전달되지 않으므로, 클라이언트는 `StreamProvider`를 **폴링 기반**으로 구현한다 — 앱 포그라운드 전환 시 1회 + 구매/복원 직후 1회 `GET /v1/subscription/status` 호출로 로컬 스트림에 방출. (v2 검토: 실시간성이 중요해지면 FCM/APNs 무음 푸시로 웹훅 수신 즉시 클라이언트에 무효화 신호를 보내는 방식으로 개선 가능.)
- **`restorePurchases()`**: 네이티브 스토어의 "구매 내역 복원"을 호출해 로컬에서 활성 영수증을 다시 얻은 뒤, 동일한 `/v1/subscription/verify`로 재전송 — 새 엔드포인트 불필요(멱등이라 안전).
- **`cancel()`— 중요한 구현 주의사항**: iOS/Android 모두 **서드파티 앱이 스토어 구독을 프로그래밍적으로 취소하는 API는 제공하지 않는다**. `SubscriptionRepository.cancel()`은 실제로는 백엔드에 취소를 요청하는 게 아니라, **네이티브 구독 관리 화면으로 딥링크**시키는 것으로 구현해야 한다: iOS `https://apps.apple.com/account/subscriptions`, Android `https://play.google.com/store/account/subscriptions?sku={productId}&package={packageName}`. 실제 해지 완료 여부는 이후 Apple/Google 웹훅으로 서버가 알게 되고, 클라이언트는 `watchStatus()` 폴링으로 반영받는다. **UX #9 화면의 "구독 해지" 버튼 문구/기대와 실제 동작(딥링크 이동)이 다르므로 app-developer에게 명시적으로 전달 필요**(9-3절 반영).

### 6-4. 가격 정보

`SubscriptionPlanOption`의 가격 문자열은 하드코딩하지 않고, `in_app_purchase` 패키지의 `queryProductDetails()`로 스토어에 등록된 실제 가격/통화를 조회해 표시(국가별 가격 자동 대응). 서버는 `productId`(월간/연간 SKU 식별자)만 관리하고 가격 표시는 클라이언트가 스토어 SDK 응답으로 채운다 — `01_ux_design.md`의 "가정 사항"에 명시된 월 4,900원/연 39,000원은 App Store Connect/Play Console에 실제 등록될 값의 예시일 뿐, API 레벨에서는 다루지 않는다.

---

## 7. 데이터 모델 매핑

| 모델명 | 필드 | 타입 | API 매핑 | 비고 |
|---|---|---|---|---|
| `SentenceSegment` | id, mediaId, index, text, translation, startMs, endMs, confidence, edited, repeatCountOverride | String, String, int, String, String?, int, int, double, bool, int? | **내 파일(Tab1)**: API 매핑 없음 — 로컬 무음감지/자막파싱으로 클라이언트가 직접 생성(4절). **라이브러리(Tab2)**: `GET /v1/library/content/{id}/segments`만 서버 매핑 대상 | `confidence`/`translation`은 라이브러리 콘텐츠(서버가 CNN/BBC 공식 트랜스크립트 기반으로 채움)에서만 의미 있는 값이 온다 — 내 파일 세그먼트는 이 필드들을 서버에서 받을 방법이 없으므로 로컬 처리 방식에 맞게 값/필요성을 app-developer가 재검토(02_app_architecture.md) |
| `LibraryContent` | id, title, source, thumbnailUrl, durationSec, difficulty, isLocked, previewAudioUrl, publishedAt, categoryId, sentenceCount (+ 신규 `audioUrl`) | 기존 `fromJson` 그대로 | `GET /v1/library/*` | `difficulty`는 서버가 `easy/mid/hard` 문자열로 응답(엔티티 enum과 동일 네이밍 유지 필요 — 서버 팀에 명시) |
| `LibraryCategory` | id, label | String, String | `GET /v1/library/categories` | - |
| `Paginated<T>` | items, nextCursor, hasMore | List<T>, String?, bool | 모든 목록형 응답 공통 래퍼 | 서버 JSON 키를 `items/nextCursor/hasMore`로 통일해 제네릭 파서 재사용 |
| `SubscriptionStatus` | isActive, plan, nextBillingDate, isTrialEligible | bool, enum?, DateTime?, bool | `GET /v1/subscription/status`, `POST /v1/subscription/verify` | `plan`은 서버가 `monthly/yearly` 문자열 반환 |

---

## 8. 캐싱 전략

| 데이터 유형 | 캐시 방식 | TTL | 무효화 조건 |
|---|---|---|---|
| 사용자 세션(accessToken) | 메모리 + Secure Storage | 1시간(만료 시 자동 refresh) | 로그아웃, refresh 실패 |
| 내 파일 문장 세그먼트(로컬 무음감지/자막파싱 결과, API 아님) | 로컬 DB(Drift/Isar, 무제한) | 없음(사용자 삭제 전까지 영구) | 사용자 삭제, 재분석 요청 |
| 라이브러리 오늘의 뉴스/카테고리 | 메모리(세션 내) + 디스크(ETag) | 오늘의 뉴스 1시간 / 카테고리 24시간 | Pull-to-refresh, 자정 갱신, ETag 불일치 |
| 라이브러리 콘텐츠 상세 | 디스크 + ETag | 1시간 | 콘텐츠 재생 시작 시 재검증 |
| 라이브러리 오프라인 오디오 | 디스크(`flutter_cache_manager`, LRU) | 캐시 후 7일 또는 5개/300MB 상한 중 먼저 도달하는 조건 | 신규 캐싱으로 상한 초과, 구독 해지(선택적 즉시 정리) |
| 구독 상태 | 메모리 + 디스크(마지막 조회값) | 5분(포그라운드 재조회) | 구매/복원/해지 직후 즉시 무효화 |

---

## 9. 오프라인 지원

- **읽기**: 내 파일(Tab1)은 로컬 저장이 원본이고 문장분리도 로컬 처리이므로 오프라인에서도 완전 정상 동작(서버 호출 자체가 없음, MediaRepository/StatsRepository/SettingsRepository/SegmentationRepository는 전부 로컬 전용이므로 이 문서 범위 밖). 라이브러리(Tab2)는 8절 캐시 정책에 따라 최근 열람/캐싱한 콘텐츠만 오프라인 재생 가능 — 그 외 콘텐츠는 "오프라인" 배너 + 캐시된 콘텐츠만 표시(01_ux_design.md #7 Error 상태 그대로).
- **쓰기(오프라인 동기화 큐가 더 이상 필요 없음)**: 이전 버전은 문장 편집 결과(`saveEditedSegments`)를 서버 백업용으로 동기화하는 아웃박스 큐(`pending_sync` 테이블 → `PATCH /v1/media/{id}/segments`)를 설계했었다. **4절 결정으로 내 파일 세그먼트는 서버에 애초에 저장되지 않으므로 이 동기화 큐 자체가 통째로 불필요해졌다** — 문장 편집은 로컬 DB에만 저장되는 순수 로컬 쓰기이며, 온라인/오프라인 여부와 무관하게 항상 동일하게 동작한다. 이 앱에서 서버로 향하는 "쓰기"는 사실상 구독 영수증 검증(`POST /v1/subscription/verify`, 6절) 하나만 남아 있으며, 이는 온라인 상태에서만 시도하는 명시적 사용자 액션(결제)이라 오프라인 큐잉 대상이 아니다.
- **충돌 해결**: 위와 같은 이유로 "서버 우선/클라이언트 우선" 충돌 해결 정책 자체가 적용될 데이터가 남아있지 않다(세그먼트는 로컬에만 존재, 라이브러리 콘텐츠는 사용자가 쓰지 않는 읽기 전용, 구독 상태는 스토어가 유일한 진실 소스). 이 항목은 참고용으로만 남겨두고 v2에서 서버 동기화가 필요한 기능이 새로 생기면 그때 재설계한다.

---

## 10. 에러 처리 매트릭스

백엔드 호출 대상이 라이브러리 조회(5절)와 구독 검증(6절)뿐으로 줄어들면서, 업로드/STT 파이프라인에서만 발생하던 코드(409 파트 충돌, 413 파일 용량 초과, 415 지원하지 않는 형식, 422 STT 동의 누락)는 트리거할 엔드포인트 자체가 사라져 **매트릭스에서 삭제**한다.

| HTTP 코드 | 의미 | 앱 처리 | 사용자 메시지 |
|---|---|---|---|
| 400 | 요청 형식 오류(예: 잘못된 쿼리 파라미터) | `ValidationFailure`, 입력 검증 | "입력을 확인해주세요" |
| 401 | 토큰 만료/무효 | `AuthInterceptor`가 자동 refresh 후 재시도(3-2), 재실패 시 익명 재발급 | 사용자에게는 대부분 비노출(자동 처리) |
| 403 | 권한 없음(비구독자가 라이브러리 잠금 콘텐츠 전체 접근 시도 등) | `EntitlementFailure` | 라이브러리는 Paywall 시트로 유도 |
| 404 | 리소스 없음(존재하지 않는 콘텐츠 id 등) | 빈 상태 UI | "데이터를 찾을 수 없습니다" |
| 429 | 레이트리밋(라이브러리/구독 API 일반) | `RetryInterceptor` 지수 백오프 | "잠시 후 다시 시도" |
| 500/502/503 | 서버 오류 | `RetryInterceptor` 재시도(멱등 요청만), 최종 실패 시 `ServerFailure` | "서버 오류, 재시도 중" → 재시도 소진 시 "다시 시도" 버튼 |
| 타임아웃/연결 끊김 | 네트워크 불안정 | `NetworkFailure`, 3단계 네트워크 상태 배너(3-3) | "네트워크 연결을 확인해주세요" |

---

## 11. 음성 데이터 외부 전송 관련 개인정보 기술 대응 — 대부분 해소됨

**2026-08-05 결정으로 이 절이 다루던 문제 대부분이 사라졌다.** 이전 버전은 사용자가 업로드한 음성이 STT 벤더(AssemblyAI 등)로 전송되는 것을 전제로 사전 동의 Bottom Sheet, 서버측 동의 감사 로그, 벤더/원본 오디오 삭제 정책, Apple/Google 심사 답변 정합성 확보 방안을 상세히 설계했었다. **사용자 업로드 음성/영상이 문장분리를 위해 기기 밖으로 나가는 경로 자체가 완전히 제거되었으므로, 이 모든 절차가 통째로 불필요해졌다.** 이는 리스크 완화가 아니라 리스크의 소거이며, 무료 핵심 기능 관점에서 상당한 개인정보/심사 리스크 단순화다.

### 11-1. 더 이상 필요 없는 것 (참고용 기록)

- STT 전송 동의 Bottom Sheet(업로드 전 1회 노출) — **불필요**. 어떤 사용자 오디오도 제3자/자사 서버로 전송되지 않으므로 동의를 받을 대상 행위 자체가 없다.
- 서버측 동의 감사 로그, 동의 거부 시 업로드 차단(구 422 케이스) — **불필요**.
- 원본 오디오/STT 벤더 사본 삭제 정책(스토리지 라이프사이클 TTL, 벤더 삭제 API 연동) — **불필요**. 오디오가 애초에 서버에 도달하지 않으므로 삭제할 서버측 사본이 없다.
- 국외 이전 고지("음성 데이터가 미국 소재 벤더로 전송") — **불필요**. 사용자 업로드 음성에 대해서는 국외 이전 항목 자체가 없어진다(store-manager에게 `04_store_listing.md` 개인정보처리방침에서 이 조항을 삭제/수정하도록 전달 필요 — 12절 전달 사항 참고).

### 11-2. 실제로 남아있는 데이터 흐름

이제 앱이 외부로 전송하는 사용자 관련 데이터는 사실상 다음 하나뿐이다.

| 데이터 | 전송 대상 | 목적 | 보존 기간 |
|---|---|---|---|
| 스토어 영수증(iOS JWS)/구매 토큰(Android purchaseToken) | 자체 백엔드 → App Store Server API / Google Play Developer API | 구독 유효성 검증(6절) | 백엔드가 엔타이틀먼트 상태만 `userId`에 귀속 보관, 원본 영수증 원문은 검증 즉시 폐기 권장(장기 보관 불필요) |
| 기기 식별자(`deviceId`, 익명 `userId`) | 자체 백엔드 | 익명 인증(2절), 구독 엔타이틀먼트 식별 | 계정 존재 기간 동안 |

- CNN/BBC 큐레이션 콘텐츠(5절)는 사용자 데이터가 아니라 방송사 공식 피드에서 서버가 가져오는 콘텐츠이므로 이 절의 "사용자 개인정보 외부 전송" 범주에 해당하지 않는다(단, 5-0절에 기록한 저작권/라이선싱 리스크는 별개 사안으로 여전히 미해결).
- store-manager에게 전달: App Privacy Nutrition Label / Google Data Safety Form에서 "오디오 데이터 → 제3자 공유" 항목은 **삭제(해당 없음)로 변경**하고, 남는 데이터 공유 항목은 "구매/거래 정보 → 스토어 사업자와 공유(영수증 검증 목적)" 정도로 대폭 축소해도 된다 — 이는 이전 버전 대비 심사 리스크가 크게 낮아지는 방향의 변경이다.

---

## 12. Fake → Real 구현체 교체 가이드

app-developer의 산출물은 `presentation/providers/repository_providers.dart` **한 곳**에서 구현체를 주입하므로, 교체는 이 파일 몇 줄 + 새 구현체 클래스 추가로 끝난다(presentation 레이어 수정 불필요 — 02_app_architecture.md 원칙 그대로). **`SegmentationRepository`는 이 교체 대상에서 제외된다** — 로컬 구현체가 곧 최종 구현체이므로 Fake→Real 전환 자체가 없다(4절).

1. `core/network/` 신설: `dio_client.dart`(3절 BaseOptions+인터셉터 조립), `auth_interceptor.dart`, `retry_interceptor.dart`, `error_mapping_interceptor.dart`, `token_storage.dart`(flutter_secure_storage 래퍼).
2. `data/repositories/`에 `RemoteLibraryRepository`, `RemoteSubscriptionRepository` 추가 — 각각 `LibraryRepository`/`SubscriptionRepository`를 `implements`하고 위 5/6절 엔드포인트를 `dio` 인스턴스로 호출. (`RemoteSegmentationRepository`는 만들지 않는다.)
3. `LibraryContent`/`SubscriptionStatus`는 이미 `fromJson`/`toJson`이 구현돼 있으므로 서버 응답 키를 7절 매핑표와 동일하게만 맞추면 별도 DTO 없이 엔티티에 직접 파싱 가능.
4. `repository_providers.dart`에서 `FakeLibraryRepository()` → `RemoteLibraryRepository(dioClient)`, `FakeSubscriptionRepository()` → `RemoteSubscriptionRepository(dioClient)`로 교체. 환경별(dev/staging/prod) 분기는 `--dart-define=API_BASE_URL=...`로 처리. `FakeSegmentationRepository`는 애초에 로컬 최종 구현체(무음감지/자막파싱)로 대체되므로 이 흐름과 무관.
5. 마이그레이션 순서 권장: (1) 인증(2절) 배선 → (2) SubscriptionRepository(스토어 심사 전 필수) → (3) LibraryRepository. 백엔드가 담당하는 범위가 이 두 가지뿐이므로 이전 버전 대비 마이그레이션 자체가 단순해졌다.

---

## 앱 개발자 전달 사항

- **STT/문장분리 관련 화면·로직은 API 연동이 필요 없다** — 이전 전달 사항 중 "STT 동의 Bottom Sheet 신규 화면", "설정 'AI 처리 동의 상태' 항목", "업로드 presigned 분할 업로드/재개 로직", "`SegmentationJobState` 서버 enum 공유"는 **모두 철회한다.** 무음 감지/자막 파싱은 순수 로컬 로직이므로 관련 구현 세부사항은 `02_app_architecture.md`를 따르면 되고, 이 문서(API 연동)에서 더 요구할 것이 없다.
- **Repository 교체 지점은 `repository_providers.dart` 한 곳, 대상은 Library/Subscription 2종뿐** — 12절 가이드 참고. `SegmentationRepository`는 로컬 구현체가 최종본이라 교체 대상이 아님을 재확인.
- **`LibraryContent`에 `audioUrl` 필드 추가 요청**(5-1절) — 현재 `previewAudioUrl`을 미리듣기/전체재생 공용으로 쓰고 있어, 서버가 구독자에게만 서명된 전체 재생 URL을 내려줄 신규 필드가 필요함. 엔티티/`fromJson`/`toJson`에 nullable `String? audioUrl` 추가 요청.
- **`SubscriptionRepository.cancel()`의 실제 동작이 UI 기대와 다름**(6-3절) — "구독 해지" 버튼(#9)은 실제로는 스토어 구독 관리 화면으로 딥링크 이동이며, 앱 내에서 즉시 해지 상태로 바뀌지 않는다. 버튼 문구/후속 안내("스토어 화면에서 해지를 완료해주세요")를 이에 맞게 조정 필요.
- **개인정보처리방침 관련**: 설정 화면의 "이용약관/개인정보처리방침" 하위에 있던(있었을) STT/AI 처리 동의 관련 UI 항목은 삭제 대상 — store-manager와 함께 `04_store_listing.md`의 개인정보처리방침 문구도 맞춰 정리 필요(11절 참고).

## QA 엔지니어 전달 사항

- **백엔드 연동 범위가 라이브러리 조회 + 구독 검증으로 축소되었다** — 이전 버전에 있던 STT Mock 서버(`json-server`/`mockoon`, 업로드→분석중 시뮬레이션) 관련 QA 준비물은 **모두 철회한다.** 문장분리(무음 감지/자막 파싱) 테스트는 API mock이 필요 없는 순수 클라이언트 로직 테스트이므로 `05_qa_report.md`에서 별도로 다룬다.
- **테스트용 인증 정보**: `/v1/auth/anonymous`는 별도 자격증명 없이 `deviceId`만으로 발급되므로 QA 계정 발급 절차 자체가 불필요. 구독 플로우 테스트는 iOS Sandbox 테스터 계정 / Android 라이선스 테스트 계정을 스토어 콘솔에서 별도 준비 필요(store-manager와 조율).
- **우선 검증 시나리오(축소됨)**:
  1. `cancel()` 호출 시 실제로 스토어 구독관리 화면으로 딥링크되는지, 이후 웹훅 반영까지의 지연 시간 동안 UI가 어색하게 멈추지 않는지 — 6-3절.
  2. 401 동시다발 상황(여러 화면에서 동시 API 호출)에서 refresh가 중복 호출되지 않는지 — 3-2절.
  3. 비구독자가 라이브러리 콘텐츠의 앞 30초 이후 구간(잠금 구간)에 실제로 접근할 수 없는지(서버 강제 여부, 5-1절) — Paywall 우회 가능성 점검.
  4. 오프라인 상태에서 내 파일 업로드→문장분리(무음 감지/자막 파싱)가 정말로 네트워크 호출 없이 끝까지 동작하는지(비행기 모드에서 검증) — 4절/9절, 이번 결정의 핵심 약속이므로 회귀 방지 차원에서 최우선순위 검증 요청.
  5. 라이브러리 "오늘의 뉴스"가 CNN/BBC 중 하나로 매일 갱신되는지, 갱신 실패 시 전일 콘텐츠가 깨지지 않고 유지되는지 — 5-0절.
