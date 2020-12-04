import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audio_session/audio_session.dart';

// const MethodChannel platform = MethodChannel('kmsd.ca/remindfulbell');

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Streams are created so that app can respond to notification-related events
// since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('app_icon');

class ReceivedNotification {
  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });
  final int id;
  final String title;
  final String body;
  final String payload;
}

void initializeNotifications() async {
  tz.initializeTimeZones();
  final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(currentTimeZone));

  final NotificationAppLaunchDetails notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          onDidReceiveLocalNotification:
              (int id, String title, String body, String payload) async {
            didReceiveLocalNotificationSubject.add(ReceivedNotification(
                id: id, title: title, body: body, payload: payload));
          });

  const MacOSInitializationSettings initializationSettingsMacOS =
      MacOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false);

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectNotificationSubject.add(payload);
  });

  // audio
  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());
}

class Notifier {
  static String channelId = 'remindfulbell_channel_id';
  static const String channelName = 'remindfulbell_channel_name';
  static const String channelDescription = 'Notifications for remindful bell';
  final String notifTitle;
  static bool mute = false;
  static bool vibrate = false;
  static String customBellPath;
  final String defaultBellAsset = 'media/defaultbell.mp3';
  String customSoundFile;
  final bool useSeparateAudio = true;

  Notifier(this.notifTitle);

  void init() async {
    // Platform.environment
  }

  void showNotification(String notifText) async {
    DateTime now = DateTime.now();

    AndroidNotificationSound notifSound;
    if (!useSeparateAudio) {
      if (customBellPath == null) {
        channelId = 'defaultbell';
        notifSound = RawResourceAndroidNotificationSound(channelId);
      } else {
        notifSound = UriAndroidNotificationSound(customBellPath);
        channelId = customBellPath;
      }
    }
    print(
        "[$now] showNotification [channelId=$channelId]: title=$notifTitle text=$notifText mute=$mute");
    // "[$now] showNotification [channelId=$channelId]: title=$notifTitle text=$notifText mute=$mute, sound=$notifSound");
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelName, channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: vibrate,
            playSound: !useSeparateAudio && !mute,
            sound: notifSound,
            ticker: 'ticker');
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        0, notifTitle, notifText, platformChannelSpecifics,
        payload: 'item x');

    if (useSeparateAudio && !mute) {
      final player = AudioPlayer();
      if (customSoundFile == null) {
        await player.setAsset(defaultBellAsset);
      } else {
        await player.setFilePath(customBellPath);
      }
      await player.play();
      await player.dispose();
    }
  }
}
