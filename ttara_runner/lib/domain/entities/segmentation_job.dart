import 'package:equatable/equatable.dart';

/// #3 "문장 분리 중" 화면의 진행 상태.
///
/// **2026-08-05 결정으로 STT 완전 폐기 — 로컬 처리로 전환**(00_input.md). 예전에는
/// 업로드→서버 job 생성→폴링/웹소켓→완료 라는 비동기 원격 파이프라인이었지만, 지금은
/// 기기 안에서 끝나는 두 갈래 로컬 연산 중 하나일 뿐이다:
/// - 자막(SRT/VTT) 파싱: 사실상 즉시 끝남(파일 파싱).
/// - 무음/일시정지 구간 감지: 긴 오디오 파일이면 몇 초 정도 걸릴 수 있어 [processing]
///   상태로 진행률을 보여줄 가치가 있다.
/// 그래서 `queued`(서버 대기열)나 `partial`(부분 STT 결과) 같은 원격 job 개념은 제거하고,
/// 실패 사유도 로컬에서 실제로 발생할 수 있는 것만 남겼다([SegmentationFailureReason]).
enum SegmentationJobState { processing, succeeded, failed }

/// 로컬 처리가 실패할 수 있는 사유. 예전 `STT_VENDOR_ERROR` 같은 원격 벤더 에러는
/// 개념 자체가 사라졌다 — 네트워크가 전혀 관여하지 않기 때문.
enum SegmentationFailureReason {
  /// 첨부된 자막 파일이 SRT/VTT 형식으로 파싱되지 않음(손상/미지원 형식).
  unsupportedSubtitleFormat,

  /// 오디오에서 뚜렷한 무음/일시정지 구간을 찾지 못해 문장 경계를 나눌 수 없음
  /// (예: 배경음이 계속 깔린 음악, 매우 짧은 파일 등).
  noClearSilenceDetected,

  /// 그 외 로컬 처리 중 예외(파일 손상, 지원하지 않는 코덱 등).
  unknown,
}

class SegmentationJobStatus extends Equatable {
  final String jobId;
  final String mediaId;
  final SegmentationJobState state;
  final double progress; // 0.0~1.0
  final SegmentationFailureReason? failureReason;
  final String? errorMessage;
  // 2026-08-07 추가: 실제 파일 길이를 프로브한 직후부터 채워지는, 이 파일 기준
  // 예상 총 소요시간(초) — #3 화면이 "보통 10분당 약 X초" 같은 일반론 대신 "약 N분
  // 예상"처럼 이 파일에 맞는 구체적 안내를 보여줄 수 있게 한다. 길이를 아직 모르거나
  // (자막 파싱 경로처럼 빨라서 필요 없거나) 프로브 전이면 null.
  final double? estimatedTotalSeconds;

  const SegmentationJobStatus({
    required this.jobId,
    required this.mediaId,
    required this.state,
    this.progress = 0,
    this.failureReason,
    this.errorMessage,
    this.estimatedTotalSeconds,
  });

  @override
  List<Object?> get props =>
      [jobId, mediaId, state, progress, failureReason, errorMessage, estimatedTotalSeconds];
}
