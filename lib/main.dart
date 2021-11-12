import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/router.dart' as router;
import 'package:mindfulnotifier/components/alarmservice.dart';
import 'package:mindfulnotifier/theme/themes.dart';


void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  try {
    PackageInfo info = await PackageInfo.fromPlatform();
    Get.put(info);
  } catch (e) {
    // throws during testing
  }

  Get.put(await path_provider.getApplicationDocumentsDirectory(),
      permanent: true, tag: constants.tagApplicationDocumentsDirectory);
  Get.put(await path_provider.getExternalStorageDirectory(),
      permanent: true, tag: constants.tagExternalStorageDirectory);

  AndroidBuildVersion buildVersion = await getAndroidBuildVersion();
  Get.put(buildVersion, permanent: true);

  AppDataStore appDataStore = await AppDataStore.getInstance();
  Get.put(appDataStore);

  ThemeData themeData = defaultTheme;
  if (allThemes.containsKey(appDataStore.theme)) {
    themeData = allThemes[appDataStore.theme];
  }

  Get.put(await initializeAlarmService(bootstrap: true),
      permanent: true, tag: constants.tagAlarmServiceAlreadyRunning);

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
