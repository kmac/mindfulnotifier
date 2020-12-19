// import 'dart:async';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:get/get.dart';
// import 'package:mindfulnotifier/components/datastore.dart';
// import 'package:mindfulnotifier/components/constants.dart' as constants;
// import 'package:mindfulnotifier/components/schedule.dart' as schedule;
// import 'package:mindfulnotifier/components/utils.dart';

// void startScheduler() async {
//   print("startScheduler");
//   await schedule.initializeScheduler();
// }

// FlutterBackgroundService service;

// FlutterBackgroundService getServiceInstance() {
//   return FlutterBackgroundService();
// }

// void onStartService() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   service = FlutterBackgroundService();

//   bool isRunning = await service.isServiceRunning();
//   print("onStartService using foreground service, running=$isRunning");
//   service.setNotificationInfo(title: constants.appName, content: 'Running');

//   doForegroundService();
//   ScheduleDataStore ds = await ScheduleDataStore.getInstance();
//   Get.put(ds);
//   startScheduler();
//   // service.setForegroundMode(false);
// }

// void doForegroundService() {
//   service.onDataReceived.listen((event) {
//     if (event["action"] == "setAsForeground") {
//       service.setForegroundMode(true);
//       return;
//     }
//     if (event["action"] == "setAsBackground") {
//       service.setForegroundMode(false);
//     }
//     if (event["action"] == "stopService") {
//       service.stopBackgroundService();
//     }
//   });

//   Timer.periodic(Duration(minutes: 15), (timer) async {
//     if (!(await service.isServiceRunning())) {
//       timer.cancel();
//     }
//     service.setNotificationInfo(
//       title: constants.appName,
//       content: "Updated at ${formatHHMMSS(DateTime.now())}",
//     );
//     service.sendData(
//       {"current_date": formatHHMMSS(DateTime.now())},
//     );
//   });
// }
