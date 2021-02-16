import 'dart:async';
import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/router.dart' as router;
import 'package:mindfulnotifier/components/alarmservice.dart';
import 'package:mindfulnotifier/theme/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> initServices() async {
  print('starting services ...');
  await initializeAlarmService();
  print('All services started...');
}

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  Get.put(sharedPreferences);

  ScheduleDataStore ds = await ScheduleDataStore.getInstance();
  Get.put(ds);

  PackageInfo info = await PackageInfo.fromPlatform();
  Get.put(info);

  Directory outputDir = await path_provider.getApplicationDocumentsDirectory();
  Get.put(outputDir,
      permanent: true, tag: constants.tagApplicationDocumentsDirectory);

  AndroidBuildVersion buildVersion = await getAndroidBuildVersion();
  Get.put(buildVersion, permanent: true);

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
