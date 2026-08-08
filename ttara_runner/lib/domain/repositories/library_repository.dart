import 'dart:async';

import '../entities/library_content.dart';
import '../entities/sentence_segment.dart';

/// **api-integrator에게 전달되는 인터페이스.** 라이브러리(#7/#8) PRO 큐레이션 콘텐츠.
///
/// 대응 엔드포인트(추정): `GET /library/today`, `GET /library/categories`,
/// `GET /library/content/{id}`, 콘텐츠의 문장 목록은 SegmentationRepository와
/// 동일한 [SentenceSegment] 모델을 재사용(서버가 큐레이션 시점에 미리 세그멘테이션 완료).
/// cursor 기반 페이지네이션 권장(01_ux_design.md).
abstract class LibraryRepository {
  Future<List<LibraryContent>> getTodayContent();
  Future<List<LibraryCategory>> getCategories();

  Future<Paginated<LibraryContent>> getContentByCategory(
    String categoryId, {
    String? cursor,
    int limit,
  });

  Future<LibraryContent> getContentDetail(String contentId);

  /// 콘텐츠의 문장 목록(구독자만 전체, 비구독자는 미리듣기 30초 분량만 반환하도록
  /// 서버에서 제한하는 것을 권장 — 클라이언트는 isLocked만 보고 UI 분기).
  Future<List<SentenceSegment>> getContentSegments(String contentId);

  /// 오프라인 지원: 최근 열람 콘텐츠 오디오 캐싱(최근 N개, 용량 상한).
  Future<void> cacheForOffline(String contentId);
  Future<List<LibraryContent>> getCachedContent();
}
