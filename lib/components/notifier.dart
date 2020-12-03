import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
