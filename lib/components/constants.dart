import 'package:package_info/package_info.dart';
import 'package:get/get.dart';

String get appName {
  PackageInfo info = Get.find();
  return info.appName;
}

String get appVersion {
  PackageInfo info = Get.find();
  return "${info.version}:${info.buildNumber}";
}

const bool useForegroundService = false;

// The name associated with the background isolate's [SendPort].
const String toAppSendPortName = 'toAppIsolate';
const String toSchedulerSendPortName = 'toSchedulerIsolate';

// 'Get' tags
const String tagApplicationDocumentsDirectory = 'ApplicationDocumentsDirectory';
