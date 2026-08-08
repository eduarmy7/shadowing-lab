import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/entities/media_item.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../common_widgets/primary_button.dart';
import 'home_controller.dart';
import 'upload_controller.dart';

/// #2 파일 불러오기 — 선택 → (영상이면) 자막 첨부 여부 → 등록/분석 진입.
///
/// 2026-08-05 STT 완전 폐기 결정(00_input.md) 이후 이 화면에는 더 이상 "동의" 단계가
/// 없다 — 음성이 어디로도 전송되지 않으니 전송 동의를 받을 대상 자체가 없다. 대신
/// 영상 파일을 골랐을 때만 "자막 파일이 있나요?"를 물어 문장분리 경로(자막 파싱 vs
/// 무음 감지)를 결정한다.
class FileUploadScreen extends ConsumerWidget {
  const FileUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uploadControllerProvider);

    // 2026-08-06: 화면 전환은 반드시 여기(FileUploadScreen 자신의, 항상 살아있는
    // context)에서 한다 — `_PickerView`/`_SubtitleDecisionView`처럼 `state.phase`가
    // 바뀌면 그 즉시 트리에서 사라지는 자식 위젯의 context로 pushReplacement를
    // 호출하면, 그 호출이 실제로 실행되기 전에 이미 unmount되어 있어서 조용히
    // 무시된다("등록 100%에서 영원히 멈춤" 버그의 원인 — upload_controller.dart의
    // UploadController 클래스 doc 참고).
    ref.listen(uploadControllerProvider, (prev, next) {
      if (next.registeredMediaId != null && next.registeredMediaId != prev?.registeredMediaId) {
        context.pushReplacement('/home/analyzing/${next.registeredMediaId}');
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.fileUploadTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: switch (state.phase) {
          UploadPhase.uploading => _UploadingView(state: state),
          UploadPhase.awaitingSubtitleDecision => _SubtitleDecisionView(state: state),
          UploadPhase.idle || UploadPhase.error => _PickerView(state: state, ref: ref),
        },
      ),
    );
  }
}

class _PickerView extends StatelessWidget {
  final UploadState state;
  final WidgetRef ref;
  const _PickerView({required this.state, required this.ref});

  /// 2026-08-07: "파일에서 선택"을 누르면 먼저 음성/영상 중 뭘 고를지 물어본다 —
  /// 예전엔 확장자만 보고 자동으로 종류를 판별했는데, 사용자가 음성/영상 트랙을
  /// 각각 따로 테스트하고 싶어해서(샘플 체험하기가 이미 두 버튼으로 나뉜 것과 동일한
  /// 구분) 실제 업로드 흐름도 미리 물어보게 맞췄다. 고른 종류로 피커의 허용 확장자
  /// 자체를 좁혀서(mp3/m4a/wav 또는 mp4/mov만) 원하는 파일을 더 쉽게 찾을 수 있다.
  ///
  /// 2026-08-06: 큰 실제 파일(content:// URI)을 고르면 안드로이드가 앱 캐시로 파일을
  /// 통째로 복사하는데(수 분 걸릴 수 있음), 그 사이 화면이 꺼지면 일부 기기에서
  /// FlutterEngine이 끊겨 피커의 응답을 영원히 못 받는 버그가 실기기+에뮬레이터 양쪽에서
  /// 재현됐다 — `ShadowingScreen`이 학습 중 화면 꺼짐을 막는 것과 같은 이유로, 파일을
  /// 고르는 동안에는 화면이 꺼지지 않게 한다.
  Future<void> _pick(BuildContext context) async {
    final sourceType = await showModalBottomSheet<MediaSourceType>(
      context: context,
      builder: (sheetContext) => const _SourceTypeSheet(),
    );
    if (sourceType == null) return; // 시트를 닫기만 하고 고르지 않음

    await WakelockPlus.enable();
    try {
      // 화면 전환은 FileUploadScreen의 ref.listen이 처리한다(이 위젯 자신은
      // pickMedia()가 끝나기 전에 언마운트될 수 있어 context를 직접 쓰면 안 된다).
      await ref.read(uploadControllerProvider.notifier).pickMedia(sourceHint: sourceType);
    } finally {
      await WakelockPlus.disable();
    }
  }

  Future<void> _startSampleVideo(BuildContext context) async {
    final media = await ref.read(homeControllerProvider).getOrCreateSampleVideoMedia();
    if (!context.mounted) return;
    navigateForMediaStatus(context, media);
  }

  Future<void> _startSampleAudio(BuildContext context) async {
    final media = await ref.read(homeControllerProvider).getOrCreateSampleAudioMedia();
    if (!context.mounted) return;
    navigateForMediaStatus(context, media);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pickSourceQuestion, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        _SourceOption(
          icon: Icons.folder_open,
          label: l10n.pickFromFiles,
          onTap: () => _pick(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceOption(
          icon: Icons.mic_none,
          label: l10n.justRecorded,
          onTap: () => AppToast.show(context, l10n.comingSoonFeature, type: AppToastType.info),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceOption(
          icon: Icons.subtitles_outlined,
          label: l10n.trySampleVideo,
          onTap: () => _startSampleVideo(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SourceOption(
          icon: Icons.graphic_eq,
          label: l10n.trySampleMp3,
          onTap: () => _startSampleAudio(context),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.supportedFormats,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (state.phase == UploadPhase.error) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Text(state.errorMessage ?? l10n.genericError, style: theme.textTheme.bodySmall),
          ),
        ],
      ],
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// 영상 파일을 고른 직후에만 노출 — 자막(SRT/VTT) 첨부 여부로 문장분리 경로를 정한다.
/// 00_input.md: 자막 있으면 자막 텍스트 그대로 사용, 없으면 무음 구간 감지로 텍스트 없이 진행.
class _SubtitleDecisionView extends ConsumerWidget {
  final UploadState state;
  const _SubtitleDecisionView({required this.state});

  // 2026-08-06: 화면 전환은 FileUploadScreen의 ref.listen이 처리한다 — 이 위젯은
  // pickSubtitleAndContinue()/continueWithoutSubtitle()이 끝나기 전에 언마운트될 수
  // 있어(등록 성공 시 state.phase가 바뀌며 이 위젯 자체가 교체됨) context로 직접
  // 내비게이션하면 안 된다("등록 100%에서 영원히 멈춤" 버그, upload_controller.dart 참고).
  Future<void> _withSubtitle(WidgetRef ref) =>
      ref.read(uploadControllerProvider.notifier).pickSubtitleAndContinue();

  Future<void> _withoutSubtitle(WidgetRef ref) =>
      ref.read(uploadControllerProvider.notifier).continueWithoutSubtitle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.pickedFileTitle(state.fileName ?? l10n.videoFallbackLabel), style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.subtitleExplain,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: l10n.chooseSubtitleFile,
          onPressed: () => _withSubtitle(ref),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => _withoutSubtitle(ref),
            child: Text(l10n.continueWithoutSubtitle),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => ref.read(uploadControllerProvider.notifier).reset(),
            child: Text(l10n.cancelAndReselect),
          ),
        ),
      ],
    );
  }
}

/// 2026-08-07 추가 — "파일에서 선택" 진입 시 음성/영상 중 어느 쪽인지 먼저 물어보는
/// 바텀시트. 샘플 체험하기(영상/MP3)가 이미 두 버튼으로 나뉜 것과 같은 아이콘·문구를
/// 써서 일관성을 맞췄다.
class _SourceTypeSheet extends StatelessWidget {
  const _SourceTypeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.whichFileType, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            _SourceOption(
              icon: Icons.graphic_eq,
              label: l10n.audioFileOption,
              onTap: () => Navigator.of(context).pop(MediaSourceType.audio),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SourceOption(
              icon: Icons.subtitles_outlined,
              label: l10n.videoFileOption,
              onTap: () => Navigator.of(context).pop(MediaSourceType.video),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadingView extends ConsumerWidget {
  final UploadState state;
  const _UploadingView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.preparingFile(state.fileName ?? ''), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: state.progress, strokeWidth: 5),
                Text('${(state.progress * 100).round()}%', style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.pleaseWait, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: l10n.cancel,
            expand: false,
            onPressed: () => ref.read(uploadControllerProvider.notifier).reset(),
          ),
        ],
      ),
    );
  }
}
