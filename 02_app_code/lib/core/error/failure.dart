import 'package:equatable/equatable.dart';

/// 도메인/데이터 레이어에서 던지는 대신 반환하는 실패 타입.
/// UI 레이어는 이 타입을 보고 화면별 상태 처리 명세(Empty/Loading/Error/Success/Partial)의
/// Error/Partial 분기를 그린다. 02_app_architecture.md "에러 처리 전략" 표와 1:1 대응.
sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// 네트워크 요청 실패(오프라인, 타임아웃, 5xx 등) — 재시도 + 캐시 폴백 대상.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '네트워크 연결을 확인해주세요']);
}

/// 로컬 문장 분리(무음 감지/자막 파싱) 실패 — #3 화면 "다시 시도" / "수동으로 나누기"
/// 대체 경로. 2026-08-05 STT 폐기 이후 네트워크/벤더 오류 개념은 없고, 로컬에서 실제로
/// 발생 가능한 사유만 남았다(`SegmentationFailureReason` 참고).
class SegmentationFailure extends Failure {
  const SegmentationFailure([super.message = '문장을 나누는 중 문제가 발생했어요']);
}

/// 인증/세션 만료 — 토큰 갱신 실패 시 로그인 화면 이동.
class AuthFailure extends Failure {
  const AuthFailure([super.message = '로그인이 필요해요']);
}

/// 파일 형식/용량/권한 등 입력 유효성 오류.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// 파일 접근 권한 거부.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = '권한이 필요한 기능이에요']);
}

/// 스토어 결제/영수증 검증 실패 — #9 화면 인라인 에러 대상.
class PurchaseFailure extends Failure {
  const PurchaseFailure([super.message = '결제 처리에 실패했어요']);
}

/// 로컬 저장소 읽기/쓰기 실패(드물지만 명세상 존재).
class StorageFailure extends Failure {
  const StorageFailure([super.message = '데이터를 저장하지 못했어요']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = '알 수 없는 오류가 발생했어요']);
}
