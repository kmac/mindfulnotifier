import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/backgroundservice.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/router.dart' as router;
import 'package:mindfulnotifier/components/schedule.dart' as schedule;
import 'package:mindfulnotifier/theme/themes.dart';

// Issues:
// https://stackoverflow.com/questions/63068311/run-a-background-task-with-android-alarm-manager-in-flutter

// MAYBE THE SOLUTION IS TO COORDINATE ALL OF THE NOTIFICATION INFO THROUGH THE SHARED PREFERENCES,
// this is how it's done in the android_alarm_manager example
// the only problem then is the alarm manager initialization issue.
// maybe that needs to be handled via this MethodChannel to interface with the plugin to see if it's already initialized or something
//  --> surely someone has run into this???
//

Future<void> initServices() async {
  print('starting services ...');
  // await Get.putAsync(() => ds.ScheduleDataStore.create());
  // GetxService schedulerService;
  // await Get.putAsync(schedule.Scheduler()).init();

  startScheduler();
  print('All services started...');
}

void startScheduler() async {
  print("startScheduler");
  await schedule.initializeScheduler();
}

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  ScheduleDataStore ds = await ScheduleDataStore.getInstance();
  Get.put(ds);

  if (constants.useForegroundService) {
    await FlutterBackgroundService.initialize(onStartService,
        autoStart: true, foreground: true);
  } else {
    await initServices();
  }

  ThemeData themeData = defaultTheme;
  if (allThemes.containsKey(ds.theme)) {
    themeData = allThemes[ds.theme];
  }

  runApp(
    // GetMaterialApp(MindfulNotifierApp());
    GetMaterialApp(
      title: constants.appName,
      debugShowCheckedModeBanner: true,
      // defaultTransition: Transition.rightToLeft,
      // defaultTransition: Transition.fade,
      getPages: router.Router.route,
      initialRoute: '/',
      smartManagement: SmartManagement.full,
      theme: themeData,
    ),
  );
}
