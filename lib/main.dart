import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
// import 'package:mindfulnotifier/components/backgroundservice.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/router.dart' as router;
import 'package:mindfulnotifier/components/scheduler.dart' as schedule;
import 'package:mindfulnotifier/theme/themes.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

Future<void> initServices() async {
  print('starting services ...');
  // await Get.putAsync(() => ds.ScheduleDataStore.create());
  // GetxService schedulerService;
  // await Get.putAsync(schedule.Scheduler()).init();

  Directory outputDir = await path_provider.getApplicationDocumentsDirectory();
  Get.put(outputDir,
      permanent: true, tag: constants.tagApplicationDocumentsDirectory);

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

  PackageInfo info = await PackageInfo.fromPlatform();
  Get.put(info);

  // if (constants.useForegroundService) {
  //   await FlutterBackgroundService.initialize(onStartService,
  //       autoStart: true, foreground: true);
  // } else {
  //   await initServices();
  // }

  await initServices();

  ThemeData themeData = defaultTheme;
  if (allThemes.containsKey(ds.theme)) {
    themeData = allThemes[ds.theme];
  }

  runApp(
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
