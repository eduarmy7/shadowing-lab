import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/ads/ad_service.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/audio/cover_art_extractor.dart';
import '../../core/permissions/permission_service.dart';
import '../../data/local/local_kv_store.dart';
import '../../data/repositories/fake_purchase_repository.dart';
import '../../data/repositories/fake_segmentation_repository.dart';
import '../../data/repositories/local_media_repository.dart';
import '../../data/repositories/local_settings_repository.dart';
import '../../data/repositories/local_stats_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../domain/repositories/segmentation_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/stats_repository.dart';

/// ── 의존성 주입 루트 ─────────────────────────────────────────────────
/// 이 파일 하나가 앱의 DI 컨테이너 역할을 한다(코드젠 없는 수동 Riverpod Provider).
/// api-integrator가 실제 서버 연동 구현체를 추가할 때는:
///   1. domain/repositories/*.dart 인터페이스는 그대로 두고
///   2. data/repositories/remote_*.dart 구현체를 새로 추가한 뒤
///   3. 아래 Provider의 반환값만 Fake* → Remote* 로 교체하면
/// presentation 레이어(컨트롤러/화면)는 단 한 줄도 바꿀 필요가 없다.

final localKvStoreProvider = Provider<LocalKvStore>((ref) => LocalKvStore());

final coverArtExtractorProvider = Provider<CoverArtExtractor>((ref) => CoverArtExtractor());

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return LocalMediaRepository(ref.watch(localKvStoreProvider));
});

/// 문장분리(자막 파싱/무음 감지) — 100% 로컬 처리(2026-08-05 STT 폐기, 00_input.md).
/// 자막 파싱은 이미 실제 로직이고, 무음 감지만 실 amplitude 분석 도입 전까지 시뮬레이션.
/// 이 계열은 서버로 교체할 대상이 아니라 로컬 구현이 유지되어야 하는 지점이다.
final segmentationRepositoryProvider = Provider<SegmentationRepository>((ref) {
  return FakeSegmentationRepository(ref.watch(localKvStoreProvider));
});

/// 2026-08-06: 문장 편집/학습 화면의 파형을 장식용 대신 실제 음원 파형으로 보여주기
/// 위한 provider — 무음 감지 때 이미 뽑아둔 진폭 데이터 중 이 문장 구간만 잘라온다.
/// 저장된 실측 데이터가 없으면(자막 파싱 경로, 라이브러리 콘텐츠 등) 빈 리스트가
/// 오는데, `WaveformPlayer`가 빈 리스트를 null과 동일하게 취급해 장식용으로 폴백한다.
final segmentWaveformProvider = FutureProvider.autoDispose
    .family<List<double>, ({String mediaId, int startMs, int endMs})>((ref, args) {
  return ref.watch(segmentationRepositoryProvider).getWaveformForSegment(
        args.mediaId,
        startMs: args.startMs,
        endMs: args.endMs,
      );
});

/// "광고 제거" 단발성 구매 — 현재 Fake 구현체.
final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return FakePurchaseRepository(ref.watch(localKvStoreProvider));
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return LocalStatsRepository(ref.watch(localKvStoreProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(ref.watch(localKvStoreProvider));
});

/// 광고 SDK 연동 지점 — 현재 NoOpAdService(플레이스홀더). 실 SDK 연동 시 이 Provider만 교체.
final adServiceProvider = Provider<AdService>((ref) => NoOpAdService());

final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());

/// 앱 전체에서 하나만 유지되는 진짜 싱글톤이어야 한다.
///
/// **2026-08-06 버그 수정**: 원래 `Provider.autoDispose`였다 — 의도는 "화면을 벗어나면
/// 자동으로 정리"였지만, 실제 사용처(`ShadowingController`, `SentenceEditScreen._preview`
/// 등)는 전부 `ref.read(audioPlayerServiceProvider)`만 호출하고 `ref.watch`로 지속
/// 구독하는 곳이 어디에도 없었다 — autoDispose는 "구독 중인 곳이 하나도 없으면" 거의
/// 즉시(다음 마이크로태스크에) dispose하므로, 매 `ref.read()` 직후 실제로는 이미 dispose
/// 스케줄이 걸린 상태였다. 그 결과 `await player.setSource(...)` 같은 비동기 호출이
/// 끝나기도 전에 내부 `AudioPlayer`가 dispose돼 있는 경우가 실기기에서 실제로 재현됨
/// (`ExoPlayerImpl: Init`이 재생 버튼을 누를 때마다 매번 새로 찍힘 — 매번 새 인스턴스가
/// 만들어지고 있었다는 뜻) — 에러 없이 조용히 재생이 안 되고 버퍼링 스피너만 도는
/// 증상으로 나타났다. 화면별로 자원을 굳이 정리해야 할 만큼 무거운 서비스가 아니라서,
/// 그냥 앱 전역 singleton으로 바꿨다 — `_currentSource` 캐싱([AudioPlayerService.setSource]
/// 참고)도 이래야 원래 의도대로 동작한다(화면이 바뀌어도 같은 소스면 재로딩 안 함).
final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
