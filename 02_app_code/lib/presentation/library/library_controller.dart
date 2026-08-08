import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/library_content.dart';
import '../../domain/entities/subscription.dart';
import '../providers/repository_providers.dart';

final libraryTodayProvider = FutureProvider.autoDispose<List<LibraryContent>>((ref) {
  return ref.watch(libraryRepositoryProvider).getTodayContent();
});

final libraryCategoriesProvider = FutureProvider.autoDispose<List<LibraryCategory>>((ref) {
  return ref.watch(libraryRepositoryProvider).getCategories();
});

final libraryCategoryContentProvider =
    FutureProvider.autoDispose.family<Paginated<LibraryContent>, String>((ref, categoryId) {
  return ref.watch(libraryRepositoryProvider).getContentByCategory(categoryId);
});

final libraryContentDetailProvider =
    FutureProvider.autoDispose.family<LibraryContent, String>((ref, contentId) {
  return ref.watch(libraryRepositoryProvider).getContentDetail(contentId);
});

/// #7/#8/#9 화면 공통 — 구독 상태 실시간 관찰.
final subscriptionStatusProvider = StreamProvider.autoDispose<SubscriptionStatus>((ref) {
  return ref.watch(subscriptionRepositoryProvider).watchStatus();
});
