import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// 학습 리마인더(마이 > 알림 설정) 실제 발동 담당. 서버 푸시가 아니라 기기에 예약하는
/// 로컬 알림이다 — "HH:mm" 문자열 하나를 받아 매일 그 시간에 반복 알림을 띄운다.
///
/// **재부팅 대응**: `AndroidManifest.xml`에 등록해둔 `ScheduledNotificationBootReceiver`가
/// 재부팅(`BOOT_COMPLETED`) 시 플러그인이 자체적으로 예약을 복원해준다 — 앱을 다시
/// 열 필요 없음.
class ReminderNotificationService {
  static const _notificationId = 1001;
  static const _channelId = 'ttara.study_reminder';
  static const _channelName = '학습 리마인더';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit),
    );
    _initialized = true;
  }

  /// 알림 권한 요청 — Android 13+(POST_NOTIFICATIONS)/iOS 공통. 이미 허용돼 있으면
  /// OS가 즉시 true를 돌려준다(중복 요청 안전).
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? true; // 구버전 OS(권한 개념 자체가 없는 Android 12 이하)는 null → 허용으로 간주.
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  /// [time]은 "HH:mm" — 기존 예약이 있으면 먼저 취소하고 다시 건다(시간 변경 시
  /// 재호출해도 중복 알림이 쌓이지 않도록).
  ///
  /// **시간대 처리**: `zonedSchedule`은 API 타입상 `TZDateTime`을 요구하지만, 기기의
  /// IANA 시간대 이름(예: `Asia/Seoul`)을 알아내려면 별도 플러그인이 더 필요해서
  /// (이번 범위에서는 추가하지 않음), 대신 Dart 기본 `DateTime`(기기 로컬 시각을
  /// 이미 정확히 반영함)으로 목표 시각을 계산한 뒤 UTC로 변환해 `tz.UTC`(내장 상수,
  /// 지역 데이터베이스 로딩 불필요)로만 감싼다 — 실제 "언제 울릴지" 계산은 이미
  /// 끝난 상태라 정확하다. 한국(DST 없음) 기준으로는 완전히 정확하고, 서머타임을
  /// 쓰는 지역에서는 연 2회 전환 시점에 최대 1시간 오차가 생길 수 있다(리마인더
  /// 알림 특성상 감수 가능한 수준으로 판단).
  Future<void> scheduleDaily(String time) async {
    await _ensureInitialized();
    await cancel();

    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = DateTime.now();
    var scheduledLocal = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledLocal.isBefore(now)) {
      scheduledLocal = scheduledLocal.add(const Duration(days: 1));
    }
    final scheduled = tz.TZDateTime.from(scheduledLocal.toUtc(), tz.UTC);

    await _plugin.zonedSchedule(
      _notificationId,
      _studyReminderTitle,
      _studyReminderBody,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: '설정한 시간에 학습을 상기시켜주는 알림',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // scheduled를 이미 절대 시각(UTC 인스턴트)으로 계산해뒀으므로 절대시간 해석.
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // 정확한 알람 권한(SCHEDULE_EXACT_ALARM) 없이도 동작하는 근사 스케줄링 —
      // 학습 리마인더는 초 단위 정확도가 필요 없으므로(몇 분 오차 허용) 굳이 별도
      // 권한을 요구하지 않는 쪽을 택했다.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복.
    );
  }

  Future<void> cancel() async {
    await _ensureInitialized();
    await _plugin.cancel(_notificationId);
  }
}

// 2026-08-10: 알림 문구는 l10n을 직접 참조하기 부담스러운 위치(BuildContext 없는
// 서비스 레이어)라 일단 한국어 기본값으로 고정한다 — 다국어 대응이 필요해지면
// LearningSettings.languageOption을 읽어와 셋 중 하나를 고르는 정도로 확장 가능.
const _studyReminderTitle = '쉐도잉랩';
const _studyReminderBody = '공부할 시간이에요! 오늘도 한 문장씩 따라 말해볼까요?';
