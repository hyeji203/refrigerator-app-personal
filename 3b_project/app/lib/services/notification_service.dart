import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/ingredient.dart';
import 'ingredient_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // 권한 안내를 이미 보여줬는지 (거절해도 매번 묻지 않도록)
  static const _permissionAskedKey = 'notificationPermissionAsked';

  /// 앱 시작 시 1회 초기화
  static Future<void> initialize() async {
    if (kIsWeb || _initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 권한은 앱 시작 시 바로 묻지 않고, 처음 유통기한을 등록할 때 설명 후 요청
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  /// 유통기한 알림이 필요한 순간(처음 유통기한 등록 시)에 이유를 설명하고 권한 요청.
  /// 이미 허용됐거나 한 번 안내한 적이 있으면 다시 묻지 않음
  static Future<void> requestPermissionWithRationale(
      BuildContext context) async {
    if (kIsWeb) return;
    await initialize();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null && await android.areNotificationsEnabled() == true) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_permissionAskedKey) == true) return;
    if (!context.mounted) return;

    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined,
            size: 40, color: Color(0xFF4CAF50)),
        title: const Text('유통기한 알림을 받아볼까요?'),
        content: const Text(
          '등록한 재료의 유통기한 3일 전과 하루 전 오전 9시에 알려드려요.\n'
          '재료를 버리지 않고 제때 사용할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('알림 받기'),
          ),
        ],
      ),
    );
    await prefs.setBool(_permissionAskedKey, true);
    if (agreed != true) return;

    await android?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 유통기한 임박 재료 조회 후 알림 스케줄링
  static Future<void> scheduleExpiryNotifications(int userId) async {
    if (kIsWeb) return;
    await initialize();

    List<Ingredient> expiring = [];
    try {
      expiring = await IngredientApiService.getExpiringIngredients(userId);
    } catch (_) {
      return;
    }

    if (expiring.isEmpty) return;

    // 기존 예약된 알림 모두 취소 후 재등록
    await _plugin.cancelAll();

    // 즉시 알림: 오늘 유통기한 임박 재료 요약
    final names = expiring.map((e) => e.ingredientName).join(', ');
    await _showImmediateNotification(
      id: 0,
      title: '🚨 유통기한 임박 재료가 있어요!',
      body: '$names 의 유통기한이 3일 이내입니다. 빨리 사용해보세요!',
    );

    // 개별 재료별 D-1 알림 스케줄링
    for (int i = 0; i < expiring.length; i++) {
      final ingredient = expiring[i];
      if (ingredient.expiryDate == null) continue;

      final expiryDate = DateTime.tryParse(ingredient.expiryDate!);
      if (expiryDate == null) continue;

      final daysBefore1 = expiryDate.subtract(const Duration(days: 1));
      final now = DateTime.now();

      if (daysBefore1.isAfter(now)) {
        // 유통기한 하루 전 오전 9시에 알림
        final scheduledTime = DateTime(
          daysBefore1.year,
          daysBefore1.month,
          daysBefore1.day,
          9,
          0,
        );
        await _scheduleNotification(
          id: i + 1,
          title: '⚠️ ${ingredient.ingredientName} 내일 유통기한 만료!',
          body:
              '${ingredient.ingredientName}의 유통기한이 내일(${ingredient.expiryDate})입니다. 오늘 사용해보세요.',
          scheduledDate: scheduledTime,
        );
      }
    }

    // 매일 오전 9시 정기 알림 등록 (다음날부터)
    await _scheduleDailyReminderAt9AM();
  }

  static Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expiry_channel',
      '유통기한 알림',
      channelDescription: '재료 유통기한 임박 알림',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.show(id, title, body, details);
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expiry_channel',
      '유통기한 알림',
      channelDescription: '재료 유통기한 임박 알림',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> _scheduleDailyReminderAt9AM() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'daily_channel',
      '일일 냉장고 알림',
      channelDescription: '매일 오전 냉장고 관리 알림',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // 내일 오전 9시
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      999,
      '🍳 오늘 뭐 해먹을까요?',
      '냉장고를 확인하고 유통기한 재료로 맛있는 요리를 만들어보세요!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 반복
    );
  }

  /// 수동으로 특정 재료 유통기한 알림 등록
  static Future<void> scheduleExpiryAlert({
    required int id,
    required String ingredientName,
    required String expiryDateStr,
  }) async {
    if (kIsWeb) return;
    await initialize();

    final expiryDate = DateTime.tryParse(expiryDateStr);
    if (expiryDate == null) return;

    // 유통기한 3일 전 알림
    final alertDate3 = expiryDate.subtract(const Duration(days: 3));
    final alertDate1 = expiryDate.subtract(const Duration(days: 1));
    final now = DateTime.now();

    if (alertDate3.isAfter(now)) {
      await _scheduleNotification(
        id: id * 10,
        title: '📅 $ingredientName 유통기한 3일 전',
        body: '$ingredientName의 유통기한이 3일 후($expiryDateStr)입니다. 미리 확인하세요!',
        scheduledDate:
            DateTime(alertDate3.year, alertDate3.month, alertDate3.day, 9, 0),
      );
    }

    if (alertDate1.isAfter(now)) {
      await _scheduleNotification(
        id: id * 10 + 1,
        title: '⚠️ $ingredientName 유통기한 내일!',
        body: '$ingredientName의 유통기한이 내일($expiryDateStr)입니다. 오늘 꼭 사용하세요!',
        scheduledDate:
            DateTime(alertDate1.year, alertDate1.month, alertDate1.day, 9, 0),
      );
    }
  }

  /// 모든 알림 취소
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
