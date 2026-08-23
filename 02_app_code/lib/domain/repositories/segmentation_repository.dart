import 'dart:async';

import '../entities/segmentation_job.dart';
import '../entities/sentence_segment.dart';

/// **api-integrator에게 전달되는 핵심 인터페이스.**
///
/// **2026-08-05 아키텍처 결정(00_input.md)로 STT(AssemblyAI 등 유료 벤더) 완전 폐기 —
/// 문장 분리는 100% 온디바이스에서 끝나며 네트워크 호출이 전혀 없다.** 무료/유료 사용자
/// 구분 없이 어떤 사용자도 이 경로에서 개발자에게 사용자당 과금이 발생하는 제3자 API를
/// 트리거하지 않는 것이 확정 요구사항이다. 두 갈래뿐이다:
/// 1. **음성만**: 로컬 무음/일시정지 구간 감지로 경계만 산출 → [SentenceSegment.text]는 null.
/// 2. **영상 + 자막(SRT/VTT)**: 자막 파일을 그대로 파싱 → 자막 타임스탬프가 경계,
///    자막 텍스트가 [SentenceSegment.text](`core/utils/subtitle_parser.dart` 참고).
///
/// 이런 이유로 이 인터페이스는 더 이상 "업로드 → 원격 job 생성 → 폴링" 같은 비동기
/// 원격 파이프라인을 모델링하지 않는다. [watchJobStatus]가 여전히 존재하는 건 무음 감지가
/// 긴 오디오에서 몇 초 걸릴 수 있어 진행률 UI(#3)가 여전히 유용하기 때문이지, 네트워크
/// 폴링이 필요해서가 아니다 — 전부 로컬 연산의 진행률이다.
///
/// 현재는 [FakeSegmentationRepository](../../data/repositories/fake_segmentation_repository.dart)
/// 가 실제 자막 파싱(진짜 로직)과 무음 감지 시뮬레이션(실 amplitude 분석은 후속 작업)을
/// 구현한다. 인터페이스 시그니처는 실 amplitude 분석 도입 시에도 그대로 유지 가능하다.
abstract class SegmentationRepository {
  /// 사용자가 고른 로컬 파일(및 있다면 자막 파일)을 앱이 처리할 수 있게 등록한다.
  /// 순수 로컬 I/O만 수행— 네트워크 전송이 전혀 없다. [onProgress]는 큰 파일을 앱
  /// 저장소로 복사하는 동안의 로컬 디스크 I/O 진행률(#2 화면 원형 인디케이터용)이며,
  /// 사실상 즉시 끝나도 무방하다(스캐폴드에서는 짧게 시뮬레이션).
  ///
  /// [subtitleFilePath]: 영상 + 자막(SRT/VTT/SMI) 업로드 시에만 값이 있다. 값이 있으면
  /// [requestSegmentation]이 자막 파싱 경로를, 없으면 무음 감지 경로를 탄다.
  ///
  /// [subtitleLanguageClassId]: 자막이 여러 언어 트랙을 담은 SMI(`detectSamiLanguageTracks`
  /// 참고)일 때, 사용자가 고른 언어 트랙의 `Class` 값. 단일 언어 자막이면 null.
  ///
  /// [translationLanguageClassId]: **2026-08-22 추가** — 다국어 SMI에서 학습 언어와
  /// 별개로 "한글 뜻" 표시에 쓸 트랙의 `Class` 값(`findKoreanLanguageClassId` 참고).
  /// 단일 언어 자막이거나 한국어 트랙이 따로 없으면 null — 이 경우 [SentenceSegment.translation]은
  /// 채워지지 않는다.
  ///
  /// [mediaId]: 보통은 비워두면 이 레포지토리가 새 id를 발급한다(일반 업로드 경로).
  /// "샘플로 체험하기"(홈 컨트롤러의 고정 sample-* id)처럼 재호출 시 같은 id를 재사용해야
  /// 하는 데모 경로만 예외적으로 호출측이 id를 직접 지정한다.
  Future<String> registerLocalMedia({
    required String localFilePath,
    required String fileName,
    String? subtitleFilePath,
    String? subtitleLanguageClassId,
    String? translationLanguageClassId,
    String? mediaId,
    required void Function(double progress) onProgress,
  });

  /// 등록된 mediaId에 대해 로컬 문장 분리를 실행하고 진행 상태를 관찰할 jobId를 반환한다.
  /// (자막 있으면 파싱, 없으면 무음/일시정지 구간 감지 — 둘 다 로컬 전용.)
  Future<String> requestSegmentation(String mediaId);

  /// 로컬 처리 진행 상태를 관찰한다(#3 화면 진행률 %, 완료/실패 전이). 네트워크
  /// 폴링이 아니라 로컬 연산(무음 감지 등)의 진행률 스트림이다.
  Stream<SegmentationJobStatus> watchJobStatus(String jobId);

  /// 분리 완료된 문장(구간) 목록을 조회한다(#4 화면 초기 데이터).
  Future<List<SentenceSegment>> getSegments(String mediaId);

  /// 사용자가 #4 화면에서 병합/분리/경계조정한 결과를 저장한다(로컬 저장).
  Future<void> saveEditedSegments(String mediaId, List<SentenceSegment> segments);

  /// **2026-08-06 추가**: 무음 감지 과정에서 이미 뽑아둔 실측 진폭 데이터 중
  /// [startMs]~[endMs] 구간만 잘라 [barCount]개 막대로 리샘플링해 반환한다 — 학습/편집
  /// 화면의 파형이 seed 기반 장식용 그림 대신 실제 음원 파형을 보여줄 수 있게 한다.
  /// 저장된 실측 데이터가 없으면(예: 자막 파싱 경로, 라이브러리 콘텐츠, 샘플 asset)
  /// 빈 리스트를 반환한다 — 호출측은 이를 "실측 데이터 없음"으로 보고 장식용 표시로
  /// 폴백해야 한다.
  Future<List<double>> getWaveformForSegment(
    String mediaId, {
    required int startMs,
    required int endMs,
    int barCount = 64,
  });
}
