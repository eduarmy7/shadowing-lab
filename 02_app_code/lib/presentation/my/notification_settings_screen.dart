import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common_widgets/app_toast.dart';
import '../providers/repository_providers.dart';
import 'settings_providers.dart';

/// 2026-08-12: 릴리스 빌드에서 권한 요청/알림 예약 중 발생하는 예외가 사용자에게
/// 전혀 안 보이고 토글만 조용히 원위치로 돌아가던 버그 — `_toggleReminder`에
/// try/catch가 없어서, 디버그 모드에서는 콘솔에 찍히던 에러가 릴리스에서는 아무
/// 표시 없이 그냥 삼켜졌다. 실패하면 항상 원인이 보이는 다이얼로그를 띄운다.
Future<void> _showPermissionSettingsDialog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.notificationPermissionDialogTitle),
      content: Text(l10n.notificationPermissionDialogBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            ref.read(permissionServiceProvider).openSettings();
          },
          child: Text(l10n.goToSettingsButton),
        ),
      ],
    ),
  );
}

/// 마이 > 알림 설정 — 2026-08-10부터 분리(사용자 요청: "알림설정만 나오도록"). 리마인더
/// on/off와 시간만 다룬다. 켜면 실제로 [ReminderNotificationService]가 그 시간에
/// 로컬 알림을 매일 예약한다("공부할 시간이에요" 등 — 요청대로 실제 발동하는 알림).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// 알림 권한 + 정확한 알람(SCHEDULE_EXACT_ALARM) 권한을 순서대로 확보한다.
  /// 하나라도 거부되면 설정 화면 안내 다이얼로그를 띄우고 false를 돌려준다.
  ///
  /// **2026-08-13 재발 방지**: 리마인더를 켤 때만(`_toggleReminder`) 이 확보 절차를
  /// 거치고, 이미 켜진 상태에서 시간만 바꾸는 `_pickTime`은 곧장 `scheduleDaily`를
  /// 불러서 — 정확한 알람 권한을 아직 못 받은(예: 이 권한 로직이 생기기 전부터
  /// 리마인더가 켜져 있던) 사용자가 시간만 바꿔도 예외가 나고 그게 에러 토스트로
  /// 노출되던 버그가 있었다. 두 진입점 모두 이 헬퍼를 거치도록 통일.
  Future<bool> _ensurePermissions(BuildContext context, WidgetRef ref) async {
    final service = ref.read(reminderNotificationServiceProvider);
    final granted = await service.requestPermission();
    if (!granted) {
      if (context.mounted) await _showPermissionSettingsDialog(context, ref);
      return false;
    }
    if (!await service.hasExactAlarmPermission()) {
      final exactGranted = await service.requestExactAlarmPermission();
      if (!exactGranted) {
        if (context.mounted) await _showPermissionSettingsDialog(context, ref);
        return false;
      }
    }
    return true;
  }

  Future<void> _toggleReminder(BuildContext context, WidgetRef ref, bool enabled, String currentTime) async {
    try {
      if (enabled) {
        if (!await _ensurePermissions(context, ref)) return;
        await ref.read(reminderNotificationServiceProvider).scheduleDaily(currentTime);
      } else {
        await ref.read(reminderNotificationServiceProvider).cancel();
      }
      await updateLearningSettings(ref, (s) => s.copyWith(reminderEnabled: enabled));
    } catch (e) {
      // 2026-08-12: 이전엔 여기서 실패하면 토글이 그냥 조용히 원위치로 돌아가고
      // 사용자는 원인을 알 방법이 없었다 — 릴리스 빌드에서 특히 치명적(콘솔도 안 보임).
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppToast.show(context, '${l10n.notificationPermissionDenied}\n($e)', type: AppToastType.error);
      }
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, String currentTime, bool enabled) async {
    final parts = currentTime.split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final newTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await updateLearningSettings(ref, (s) => s.copyWith(reminderTime: newTime));
    if (enabled) {
      try {
        if (!context.mounted) return;
        if (!await _ensurePermissions(context, ref)) return;
        await ref.read(reminderNotificationServiceProvider).scheduleDaily(newTime);
      } catch (e) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          AppToast.show(context, '${l10n.notificationPermissionDenied}\n($e)', type: AppToastType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(learningSettingsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(l10n.settingsLoadError)),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          children: [
            SwitchListTile(
              title: Text(l10n.studyReminder),
              value: settings.reminderEnabled,
              onChanged: (v) => _toggleReminder(context, ref, v, settings.reminderTime),
            ),
            ListTile(
              title: Text(l10n.reminderTimeLabel),
              enabled: settings.reminderEnabled,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(settings.reminderTime, style: theme.textTheme.bodyMedium),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              onTap: settings.reminderEnabled ? () => _pickTime(context, ref, settings.reminderTime, true) : null,
            ),
            if (settings.reminderEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screenMargin, AppSpacing.sm, AppSpacing.screenMargin, 0),
                child: Text(
                  l10n.reminderMessagePreview(l10n.studyReminderNotificationBody),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
