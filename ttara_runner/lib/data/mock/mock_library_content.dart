import '../../domain/entities/library_content.dart';

/// [FakeLibraryRepository]가 서빙하는 데모 큐레이션 콘텐츠(#7/#8 화면).
///
/// `audioUrl`(전체 재생)과 `previewAudioUrl`(30초 미리듣기)을 서로 다른 값으로 채워
/// 두 필드가 실제로 분리되어 쓰이고 있음을 코드 레벨에서도 드러낸다(QA 🔴-1 재발 방지).
/// 실 서버 연동 시 `audioUrl`은 구독자에게만 채워지고 비구독자에게는 null로 응답되지만,
/// 이 Fake 저장소는 구독 상태를 알지 못하므로 항상 값을 채운다 — 실제 접근 제어는
/// UI 레이어(#8 Paywall 게이트)에서 이미 이뤄지므로 Fake 단계에서는 문제되지 않는다.
///
/// **2026-08-05(2차) 결정 — PRO 콘텐츠는 두 트랙으로 구성된다** (00_input.md):
/// 1. **오늘의 뉴스**(`today`): CNN/BBC 공식 트랜스크립트 기반, 매일 CNN 2편 + BBC 2편 = 4편
///    갱신. 저작권/라이선싱 리스크가 있어 실제 출시 전 법무 확인 필요(04_store_listing.md
///    4-(d)절, 아직 미해결 — 이 카테고리는 그 리스크가 클리어되기 전까지 실제 배포 불가).
/// 2. **일상회화/비즈니스/여행**(`daily`/`business`/`travel`): CNN/BBC와 무관한 **자체 제작
///    다이얼로그** — 팀이 직접 대본을 쓰고(추후 녹음까지) 카테고리당 10편 정도로 시작해
///    계속 추가하는 것으로 결정(사용자 확인 완료). 자체 저작물이므로 CNN/BBC와 달리
///    저작권 리스크가 없고, AI로 생성하지도 않는다(원칙: 무료뿐 아니라 PRO 콘텐츠 제작도
///    벤더 API 비용이 들지 않아야 한다는 00_input.md의 취지와 일치).
///
/// **이번 패스는 "문서+코드 구조만" 반영 범위**(사용자 확인) — 아래 3개 카테고리는 각각
/// 자리만 잡아둔 플레이스홀더 2편씩이고, 실제 다이얼로그 10편/카테고리 작문은 아직
/// 진행되지 않았다. `source`는 CNN/BBC와 명확히 구분되도록 `'쉐도잉랩'`으로 통일.
const List<LibraryCategory> mockCategories = [
  LibraryCategory(id: 'today', label: '오늘의 뉴스'),
  LibraryCategory(id: 'daily', label: '일상회화'),
  LibraryCategory(id: 'business', label: '비즈니스'),
  LibraryCategory(id: 'travel', label: '여행'),
];

final List<LibraryContent> mockLibraryContent = [
  // ── 오늘의 뉴스 — CNN 2편 + BBC 2편 ─────────────────────────────
  LibraryContent(
    id: 'lib-001',
    title: 'AI reshapes the future of work',
    source: 'CNN',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-news-1/400/240',
    durationSec: 200,
    difficulty: ContentDifficulty.mid,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-1.mp3',
    audioUrl: 'asset:///mock/full-1.mp3',
    publishedAt: DateTime.now().subtract(const Duration(hours: 4)),
    categoryId: 'today',
    sentenceCount: 18,
  ),
  LibraryContent(
    id: 'lib-002',
    title: 'How remote teams stay connected',
    source: 'BBC',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-news-2/400/240',
    durationSec: 165,
    difficulty: ContentDifficulty.easy,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-2.mp3',
    audioUrl: 'asset:///mock/full-2.mp3',
    publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
    categoryId: 'today',
    sentenceCount: 14,
  ),
  LibraryContent(
    id: 'lib-003',
    title: 'What the latest jobs report really means',
    source: 'CNN',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-news-3/400/240',
    durationSec: 210,
    difficulty: ContentDifficulty.hard,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-3.mp3',
    audioUrl: 'asset:///mock/full-3.mp3',
    publishedAt: DateTime.now().subtract(const Duration(hours: 9)),
    categoryId: 'today',
    sentenceCount: 16,
  ),
  LibraryContent(
    id: 'lib-004',
    title: 'Inside the UK\'s new climate plan',
    source: 'BBC',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-news-4/400/240',
    durationSec: 180,
    difficulty: ContentDifficulty.mid,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-4.mp3',
    audioUrl: 'asset:///mock/full-4.mp3',
    publishedAt: DateTime.now().subtract(const Duration(hours: 11)),
    categoryId: 'today',
    sentenceCount: 15,
  ),

  // ── 일상회화/비즈니스/여행 — 자체 제작(팀 직접 작문), 카테고리당 10편 목표 중
  //    지금은 구조 확인용 플레이스홀더 2편씩만. source는 CNN/BBC와 구분되도록 '쉐도잉랩'.
  LibraryContent(
    id: 'lib-101',
    title: 'Ordering coffee like a local',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-cafe/400/240',
    durationSec: 90,
    difficulty: ContentDifficulty.easy,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-101.mp3',
    audioUrl: 'asset:///mock/full-101.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    categoryId: 'daily',
    sentenceCount: 10,
  ),
  LibraryContent(
    id: 'lib-102',
    title: 'Catching up with an old friend',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-catchup/400/240',
    durationSec: 100,
    difficulty: ContentDifficulty.easy,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-102.mp3',
    audioUrl: 'asset:///mock/full-102.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 3)),
    categoryId: 'daily',
    sentenceCount: 11,
  ),
  LibraryContent(
    id: 'lib-201',
    title: 'Nailing your job interview',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-interview/400/240',
    durationSec: 180,
    difficulty: ContentDifficulty.hard,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-201.mp3',
    audioUrl: 'asset:///mock/full-201.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 1)),
    categoryId: 'business',
    sentenceCount: 16,
  ),
  LibraryContent(
    id: 'lib-202',
    title: 'Leading a Monday morning stand-up',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-standup/400/240',
    durationSec: 140,
    difficulty: ContentDifficulty.mid,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-202.mp3',
    audioUrl: 'asset:///mock/full-202.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 4)),
    categoryId: 'business',
    sentenceCount: 13,
  ),
  LibraryContent(
    id: 'lib-301',
    title: 'Small talk at the airport',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-airport/400/240',
    durationSec: 110,
    difficulty: ContentDifficulty.easy,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-301.mp3',
    audioUrl: 'asset:///mock/full-301.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 3)),
    categoryId: 'travel',
    sentenceCount: 12,
  ),
  LibraryContent(
    id: 'lib-302',
    title: 'Checking into a hotel',
    source: '쉐도잉랩',
    thumbnailUrl: 'https://picsum.photos/seed/ttara-hotel/400/240',
    durationSec: 95,
    difficulty: ContentDifficulty.easy,
    isLocked: true,
    previewAudioUrl: 'asset:///mock/preview-302.mp3',
    audioUrl: 'asset:///mock/full-302.mp3',
    publishedAt: DateTime.now().subtract(const Duration(days: 5)),
    categoryId: 'travel',
    sentenceCount: 9,
  ),
];
