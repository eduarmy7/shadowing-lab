import 'dart:async';

import '../../domain/entities/library_content.dart';
import '../../domain/entities/sentence_segment.dart';
import '../../domain/repositories/library_repository.dart';
import '../mock/mock_library_content.dart';
import '../mock/mock_sentences.dart';

/// [LibraryRepository]의 Fake 구현체 — 라이브러리(#7/#8) UI를 실 API 없이 데모.
/// api-integrator가 실제 콘텐츠 CMS/API로 교체할 대상.
class FakeLibraryRepository implements LibraryRepository {
  final Set<String> _cachedIds = {};

  @override
  Future<List<LibraryContent>> getTodayContent() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return mockLibraryContent.where((e) => e.categoryId == 'today').toList();
  }

  @override
  Future<List<LibraryCategory>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockCategories;
  }

  @override
  Future<Paginated<LibraryContent>> getContentByCategory(
    String categoryId, {
    String? cursor,
    int limit = 10,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final items = mockLibraryContent.where((e) => e.categoryId == categoryId).toList();
    // 데모 데이터가 limit보다 적으므로 항상 1페이지로 종료.
    return Paginated(items: items, nextCursor: null, hasMore: false);
  }

  @override
  Future<LibraryContent> getContentDetail(String contentId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return mockLibraryContent.firstWhere((e) => e.id == contentId);
  }

  @override
  Future<List<SentenceSegment>> getContentSegments(String contentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // 라이브러리 콘텐츠는 CNN/BBC 공식 자막/트랜스크립트 기반이라 항상 텍스트가 있다
    // (STT 없음 — 00_input.md). 자막 파싱 경로와 동일한 데모 데이터를 재사용.
    return buildMockSubtitleSentences(contentId);
  }

  @override
  Future<void> cacheForOffline(String contentId) async {
    _cachedIds.add(contentId);
  }

  @override
  Future<List<LibraryContent>> getCachedContent() async {
    return mockLibraryContent.where((e) => _cachedIds.contains(e.id)).toList();
  }
}
