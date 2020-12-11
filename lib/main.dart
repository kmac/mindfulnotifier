import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/router.dart' as router;

import 'package:mindfulnotifier/components/schedule.dart' as schedule;
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart' as ui;

// Issues:
// https://stackoverflow.com/questions/63068311/run-a-background-task-with-android-alarm-manager-in-flutter

// MAYBE THE SOLUTION IS TO COORDINATE ALL OF THE NOTIFICATION INFO THROUGH THE SHARED PREFERENCES,
// this is how it's done in the android_alarm_manager example
// the only problem then is the alarm manager initialization issue.
// maybe that needs to be handled via this MethodChannel to interface with the plugin to see if it's already initialized or something
//  --> surely someone has run into this???
//

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  String title = 'Mindful Notifier';

  // GetxService schedulerService;
  schedule.initializeSchedule(title);
  schedule.initializeFromAlarmManagerReceivePort();
  // TODO Turn schedule into a GetxService
  // TODO Turn datastores into a GetxService

  // Eventual idea is to turn the Scheduler into an instance that is only accessible
  // via the alarm callback isolate. It would read all data from shared preferences.
  // And create the next alarm from that data on the fly.
  // - complete decoupling of the alarm/notification from the UI
  // - all data is shared via shared prefs
  // Alarms for:
  // - raising a notification
  // - quiet hours start/end (maybe end not required - just reschedule past next)
  // The notification raised would either have the reminder in payload, or
  // we just stick the notification in shared prefs and always read from that
  // on the UI side.

  runApp(
    // GetMaterialApp(MindfulNotifierApp());
    GetMaterialApp(
      title: title,
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.rightToLeft,
      getPages: router.Router.route,
      initialRoute: '/',
      smartManagement: SmartManagement.full,
      theme: ThemeData(
        // primarySwatch: Colors.deepOrange,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          // color: Colors.deepOrange,
          color: Colors.indigo,
          // textTheme: TextTheme(
          //   headline6: GoogleFonts.exo2(
          //     color: Colors.white,
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //   ),
        ),
      ),
    ),
  );
}
