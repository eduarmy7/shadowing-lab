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
  // 2026-08-13: importance를 default→high로 올리면서 채널 id도 바꿨다. 채널은
  // 한 번 만들어지면 이후 같은 id로 다시 만들어도(importance 등 속성이 코드에서
  // 바뀌어도) OS가 기존 채널 설정을 그대로 유지한다 — 이미 설치된 기기에서는
  // 예전 채널(_legacyChannelId)이 계속 DEFAULT로 남아 새 설정이 적용 안 된다.
  static const _channelId = 'ttara.study_reminder.v2';
  static const _legacyChannelId = 'ttara.study_reminder';
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
    // 기존 기기에 남아있는 구채널 정리 — 없어도(신규 설치) 조용히 무시된다.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel(_legacyChannelId);
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

  /// 정확한 알람(SCHEDULE_EXACT_ALARM) 권한 확인/요청 — iOS/Android 12 미만은
  /// 이 개념이 아예 없어 항상 true. 이미 허용돼 있으면 시스템 설정 화면을 띄우지
  /// 않고 바로 true를 돌려준다(중복 호출 안전).
  Future<bool> hasExactAlarmPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    final can = await androidImpl.canScheduleExactNotifications();
    return can ?? true;
  }

  /// "알람 및 리마인더" 특별 접근 설정 화면을 띄우고, 사용자가 돌아온 뒤의
  /// 최종 허용 여부를 돌려준다(내부적으로 `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`).
  Future<bool> requestExactAlarmPermission() async {
    await _ensureInitialized();
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return true;
    final granted = await androidImpl.requestExactAlarmsPermission();
    return granted ?? false;
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
          // 2026-08-13: default importance는 화면이 꺼져있으면 알림 패널에만
          // 조용히 쌓이고 화면을 켜기 전엔 알아챌 방법이 없다는 실사용 피드백으로
          // high로 상향 — heads-up(팝업)으로 뜨면서 화면도 깨운다.
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // scheduled를 이미 절대 시각(UTC 인스턴트)으로 계산해뒀으므로 절대시간 해석.
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // 2026-08-13: inexactAllowWhileIdle → exactAllowWhileIdle로 변경. "몇 분 오차
      // 허용"이면 되겠다 싶었지만 실사용 결과 오차가 아니라 Doze 유지보수 창까지
      // 통째로 미뤄지는 문제였다(11:50 예약 → 앱을 열어 프로세스를 깨운 12:10에야
      // 발동). 정확한 알람은 SCHEDULE_EXACT_ALARM 권한이 필요 — 호출부
      // (notification_settings_screen.dart)에서 scheduleDaily 전에 반드시
      // hasExactAlarmPermission()/requestExactAlarmPermission()으로 확보해야
      // 하며, 없이 exactAllowWhileIdle로 예약하면 플러그인이 ExactAlarmPermissionException을 던진다.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
