import 'package:package_info_plus/package_info_plus.dart';
import 'package:get/get.dart';

String get appName {
  try {
    PackageInfo info = Get.find();
    return info.appName;
  } catch (e) {}
  return "Mindful Notifier";
}

String get appVersion {
  try {
    PackageInfo info = Get.find();
    return "${info.version}:${info.buildNumber}";
  } catch (e) {}
  return "undefined";
}

const bool useForegroundService = false;

// The name associated with the background isolate's [SendPort].
const String toAppSendPortName = 'toAppIsolate';
const String toAlarmServiceSendPortName = 'toAlarmServiceIsolate';

// 'Get' tags
const String tagApplicationDocumentsDirectory = 'ApplicationDocumentsDirectory';
const String tagExternalStorageDirectory = 'ExternalStorageDirectory';
const String tagAlarmServiceAlreadyRunning = 'AlarmServiceAlreadyRunning';

// Messages
const String reminderMessageQuietHours = 'In quiet hours';
const String reminderMessageDisabled = 'Not Enabled';
const String reminderMessageWaiting = 'Enabled. Waiting for notification...';
const String infoMessageDisabled = 'Disabled';
const String infoMessageWaiting = 'Enabled. Waiting for notification.';
