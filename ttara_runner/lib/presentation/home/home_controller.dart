import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/entities/user_stats.dart';
import '../providers/repository_providers.dart';

/// #1 홈 화면의 파일 목록 — 로컬 저장소 변경(추가/삭제/진행률 갱신)을 실시간 반영.
final homeMediaListProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  return ref.watch(mediaRepositoryProvider).watchAll();
});

/// 스트릭 미니배지(#1 "🔥 3일째 학습 중") — 마이 탭과 동일한 통계 소스를 공유.
final userStatsProvider = StreamProvider.autoDispose<UserStats>((ref) {
  return ref.watch(statsRepositoryProvider).watchStats();
});

final homeControllerProvider = Provider<HomeController>((ref) => HomeController(ref));

/// 홈 화면의 사용자 액션(삭제/이름변경)을 담당하는 얇은 커맨드 컨트롤러.
/// 목록 상태 자체는 [homeMediaListProvider] 스트림이 단일 진실 소스(SSOT)로 관리한다.
class HomeController {
  final Ref _ref;
  HomeController(this._ref);

  /// QA 🔴-3: App Review 심사자를 포함해 자기 소유 파일이 없는 사용자도 핵심 기능
  /// (자동 문장분리→쉐도잉)을 바로 체험할 수 있도록, 앱 번들에 포함된 샘플을 소스로 하는
  /// 고정 ID의 [MediaItem]을 준비한다. 이미 한 번 체험했다면 기존 항목(및 그 진행 상태)을
  /// 그대로 재사용한다.
  ///
  /// 2026-08-05 STT 완전 폐기 이후 애초에 이 앱 전체에 음성을 어딘가로 전송하는 흐름이
  /// 없으므로, 샘플 체험 역시 "동의가 필요 없다"는 설명 자체가 더 이상 의미가 없다 —
  /// 모든 경로가 항상 로컬 전용이다.
  ///
  /// 두 갈래를 각각 보여준다(01_ux_design.md #2 두 카드):
  /// - [getOrCreateSampleAudioMedia]: 음성만 → 무음 감지 경로(텍스트 없음)를 체험.
  ///   `registerLocalMedia`를 거치지 않고 곧바로 분석 화면으로 보내며,
  ///   [FakeSegmentationRepository]는 자막 등록 이력이 없는 mediaId에 대해 자동으로
  ///   무음 감지 경로로 폴백한다(별도 특수 처리 불필요).
  /// - [getOrCreateSampleVideoMedia]: 영상+자막 → 자막 파싱 경로(텍스트 있음)를 체험.
  ///   실제 자막 파싱 로직을 그대로 타야 의미가 있으므로, 번들 SRT 문자열을 임시
  ///   파일로 한 번 써두고 `registerLocalMedia`(고정 mediaId 지정)로 정식 등록한다.
  static const sampleAudioMediaId = 'sample-001';
  static const sampleVideoMediaId = 'sample-002';

  Future<MediaItem> getOrCreateSampleAudioMedia() async {
    final repo = _ref.read(mediaRepositoryProvider);
    final existing = await repo.getById(sampleAudioMediaId);
    if (existing != null) return existing;

    final created = MediaItem(
      id: sampleAudioMediaId,
      fileName: '샘플 오디오 파일 (MP3)',
      localPath: 'asset:///assets/sample/sample_interview_en.wav',
      sourceType: MediaSourceType.audio,
      durationMs: 45000,
      status: MediaStatus.analyzing,
      createdAt: DateTime.now(),
    );
    await repo.save(created);
    return created;
  }

  Future<MediaItem> getOrCreateSampleVideoMedia() async {
    final repo = _ref.read(mediaRepositoryProvider);
    final existing = await repo.getById(sampleVideoMediaId);
    if (existing != null) return existing;

    final subtitleFilePath = await _writeSampleSubtitleFile();
    await _ref.read(segmentationRepositoryProvider).registerLocalMedia(
          localFilePath: 'asset:///assets/sample/sample_interview_en.wav',
          fileName: '샘플 영상 파일',
          subtitleFilePath: subtitleFilePath,
          mediaId: sampleVideoMediaId,
          onProgress: (_) {},
        );

    final created = MediaItem(
      id: sampleVideoMediaId,
      fileName: '샘플 영상 파일',
      localPath: 'asset:///assets/sample/sample_interview_en.wav',
      sourceType: MediaSourceType.video,
      durationMs: 45000,
      status: MediaStatus.analyzing,
      createdAt: DateTime.now(),
    );
    await repo.save(created);
    return created;
  }

  /// 번들에 미디어 에셋으로 들어있지 않은(순수 텍스트) 샘플 자막을 실제 파일 시스템
  /// 경로로 한 번 써둔다 — `FakeSegmentationRepository`가 일반 사용자 업로드와 동일하게
  /// `File(subtitleFilePath).readAsString()`으로 읽으므로, 데모도 진짜 자막 파싱
  /// 로직(`core/utils/subtitle_parser.dart`)을 그대로 타게 하기 위함(가짜 텍스트를
  /// 직접 주입하지 않음).
  Future<String> _writeSampleSubtitleFile() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sample_video_en.srt');
    if (!await file.exists()) {
      await file.writeAsString(_sampleSrtContent);
    }
    return file.path;
  }

  static const _sampleSrtContent = '''
1
00:00:00,500 --> 00:00:03,800
Hi, thanks for trying ShadowingLab.

2
00:00:04,200 --> 00:00:08,500
This is a sample video with subtitles attached.

3
00:00:09,000 --> 00:00:13,200
Notice how each sentence shows up as real text here.

4
00:00:13,800 --> 00:00:18,000
That's because the subtitle file itself sets the boundaries.
''';

  Future<void> deleteMedia(String id) => _ref.read(mediaRepositoryProvider).delete(id);

  Future<void> renameMedia(String id, String newFileName) =>
      _ref.read(mediaRepositoryProvider).rename(id, newFileName);
}

/// 파일 카드/샘플 체험 CTA에서 공유하는 상태별 이동 규칙. [MediaItem.status]에 따라
/// 업로드 재개/분석 중/학습 화면 중 알맞은 곳으로 진입시킨다.
void navigateForMediaStatus(BuildContext context, MediaItem item) {
  switch (item.status) {
    case MediaStatus.uploading:
    case MediaStatus.analyzing:
      context.push('/home/analyzing/${item.id}');
      break;
    case MediaStatus.ready:
      context.push('/shadowing/${item.id}');
      break;
    case MediaStatus.failed:
      context.push('/home/analyzing/${item.id}?retry=true');
      break;
  }
}
