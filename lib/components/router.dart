import 'package:get/get.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';
import 'package:mindfulnotifier/screens/sound.dart';
import 'package:mindfulnotifier/screens/general.dart';
import 'package:mindfulnotifier/screens/schedulesview.dart';
import 'package:mindfulnotifier/screens/reminderview.dart';

class Router {
  static final route = [
    GetPage(
      name: '/',
      page: () => MindfulNotifierWidget(),
    ),
    GetPage(
      name: '/schedules',
      page: () => SchedulesWidget(),
    ),
    GetPage(
      name: '/reminders',
      page: () => ReminderWidget(),
    ),
    GetPage(
      name: '/sound',
      page: () => SoundWidget(),
    ),
    GetPage(
      name: '/general',
      page: () => GeneralWidget(),
    ),
  ];
}
