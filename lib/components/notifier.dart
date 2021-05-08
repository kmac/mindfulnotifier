import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:mindfulnotifier/components/audio.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('notifier');

const bool useSeparateAudio = true;

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

  // Use this if ever need to get access to the notication launched details:
  // final NotificationAppLaunchDetails notificationAppLaunchDetails =
  //     await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

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
}

class Notifier {
  static const int notifId = 0;

  File customSoundFile;
  NotifyAudioPlayer audioPlayer;

  static Notifier _instance;

  /// Private constructor
  Notifier._internal() {
    _instance = this;
    _instance._init();
  }

  factory Notifier() => _instance ?? Notifier._internal();

  factory Notifier.withCustomSoundFile(File customSoundFile) {
    if (_instance == null) {
      Notifier._internal();
      _instance.customSoundFile = customSoundFile;
    }
    return _instance;
  }

  void _init() async {
    logger.i("Initializing Notifier");
  }

  void shutdown() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Future<void> _startAudioService() async {
  //   if (useSeparateAudio) {
  //     audioPlayer ??= NotifyAudioPlayer.useNotificationChannel()..init();
  //   }
  // }

  // void _stopAudioService() {
  //   if (useSeparateAudio) {
  //     audioPlayer?.dispose();
  //     audioPlayer = null;
  //   }
  // }

  void showQuietHoursNotification(bool start) async {
    final String notifText =
        start ? 'In Quiet Hours' : 'Quiet Hours have ended';
    showNotification(notifText, mute: true, vibrate: false);
  }

  void showInfoNotification(String notifText) async {
    showNotification(notifText, mute: true, vibrate: false);
  }

  void showReminderNotification(String notifText) async {
    bool mute = false;
    bool vibrate = false;
    try {
      ScheduleDataStore ds = await ScheduleDataStore.getInstance();
      ds.reload();
      mute = ds.mute;
      vibrate = ds.vibrate;
    } catch (e) {
      logger.e("Could not get ScheduleDataStore, e=$e");
    }
    showNotification(notifText, mute: mute, vibrate: vibrate);
  }

  void showNotification(String notifText,
      {bool mute = false, bool vibrate}) async {
    // Some reference links:
    // https://developer.android.com/training/notify-user/channels
    // https://itnext.io/android-notification-channel-as-deep-as-possible-1a5b08538c87
    //
    // channelId cannot be changed after channel is submitted to notification manager;
    String channelId = constants.appName;
    // channelName can be changed after channel is submitted to notification manager;
    // NOTE: we will use channelId for channelName
    // channelDescription can be changed after channel is submitted to notification manager;
    String channelDescription = 'Notifications for ' + constants.appName;

    final String notifTitle = constants.appName;
    DateTime now = DateTime.now();

    AndroidNotificationSound notifSound;
    if (!useSeparateAudio) {
      if (customSoundFile == null) {
        channelId += '-tibetan_bell_ding_b';
        notifSound = RawResourceAndroidNotificationSound(channelId);
      } else {
        // todo this will have to be shortened to the file name no extension:
        channelId += '-' + customSoundFile.path;
        notifSound = UriAndroidNotificationSound(customSoundFile.path);
      }
      // Use another channelId if mute is enabled (because of android):
      if (mute) {
        channelId += '-muted';
        channelDescription += '/muted';
      }
    }
    // Use another channelId if vibrate is enabled (because of android):
    if (vibrate) {
      channelId += '-vibration';
      channelDescription += '/with vibration';
    }
    logger.i(
        "[$now] showNotification [channelId=$channelId]: title=$notifTitle " +
            "text=$notifText mute=$mute vibrate=$vibrate");

    var styleInfo = BigTextStyleInformation('');
    AndroidBuildVersion buildVersion = await getAndroidBuildVersion();
    if (buildVersion.sdkInt <= 23) {
      styleInfo = null;
    }

    bool sticky = true;
    try {
      ScheduleDataStore ds = await ScheduleDataStore.getInstance();
      ds.reload();
      sticky = ds.useStickyNotification;
    } catch (e) {
      logger.e("Could not get ScheduleDataStore, e=$e");
    }

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelId, channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: vibrate,
            playSound: !useSeparateAudio && !mute,
            sound: notifSound,
            ongoing: false,
            autoCancel: !sticky,
            styleInformation: styleInfo,
            ticker: notifText);
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    if (sticky) {
      await flutterLocalNotificationsPlugin.cancel(notifId);
    }
    await flutterLocalNotificationsPlugin.show(
        notifId, notifTitle, notifText, platformChannelSpecifics,
        payload: notifText);

    if (useSeparateAudio && !mute) {
      String ringerStatus = await SoundMode.ringerModeStatus;
      if (ringerStatus == "Normal Mode") {
        audioPlayer ??= NotifyAudioPlayer.useNotificationChannel()..init();
        audioPlayer.playBell();
      }
    }
  }

  void playSound(dynamic fileOrPath) {
    audioPlayer ??= NotifyAudioPlayer.useNotificationChannel()..init();
    audioPlayer.play(fileOrPath);
  }
}
