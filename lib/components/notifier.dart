import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:audio_session/audio_session.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('notifier'));

const bool useSeparateAudio = false;

// const MethodChannel platform = MethodChannel('kmsd.ca/mindfulnotifier');

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
      logger.d('notification payload: $payload');
    }
    selectNotificationSubject.add(payload);
  });

  // audio
  if (useSeparateAudio) {
    final session = await AudioSession.instance;
    // await session.configure(AudioSessionConfiguration.music());
    await session.configure(AudioSessionConfiguration.speech());
  }
}

class Notifier {
  static const int notifId = 0;
  static const bool useOngoing = false;
  static const String channelName = 'Mindful Notifier';
  static const String channelDescription = 'Notifications for Mindful Notifier';

  static String channelId = 'Main Channel';

  final String notifTitle = constants.appName;
  final String defaultBellAsset = 'media/defaultbell.mp3';

  File customSoundFile;

  Notifier();
  Notifier.withCustomSound(File customSoundFile) {
    this.customSoundFile = customSoundFile;
  }

  void init() async {}

  static void cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  void showNotification(String notifText) async {
    DateTime now = DateTime.now();
    ScheduleDataStoreRO ds = Get.find();
    bool mute = ds.mute;
    bool vibrate = ds.vibrate;

    AndroidNotificationSound notifSound;
    if (!useSeparateAudio) {
      if (customSoundFile == null) {
        channelId = 'defaultbell';
        notifSound = RawResourceAndroidNotificationSound(channelId);
      } else {
        // TODO this will have to be shortened to the file name no extension:
        channelId = customSoundFile.path;
        notifSound = UriAndroidNotificationSound(customSoundFile.path);
      }
      if (mute) {
        channelId += '-mute';
      }
      if (vibrate) {
        channelId += '-vibrate';
      }
    }
    logger.i(
        "[$now] showNotification [channelId=$channelId]: title=$notifTitle text=$notifText mute=$mute");

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelName, channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: vibrate,
            playSound: !useSeparateAudio && !mute,
            sound: notifSound,
            ongoing: useOngoing,
            styleInformation: BigTextStyleInformation(''),
            ticker: notifText);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    if (useOngoing) {
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }
    await flutterLocalNotificationsPlugin.show(
        notifId, notifTitle, notifText, platformChannelSpecifics,
        payload: notifText);

    if (useSeparateAudio && !mute) {
      final player = AudioPlayer();
      if (customSoundFile == null) {
        await player.setAsset(defaultBellAsset);
      } else {
        await player.setFilePath(customSoundFile.path);
      }
      logger.d('player.play');
      await player.play();
      logger.d('player.play done');
      await player.stop();
      await player.dispose();
      logger.d('player.play done');
    }
  }
}
