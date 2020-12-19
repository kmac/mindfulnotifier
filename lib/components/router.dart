import 'package:get/get.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/screens/general/general.dart';
import 'package:mindfulnotifier/screens/schedules/schedulesview.dart';
import 'package:mindfulnotifier/screens/reminders/reminderview.dart';

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
      name: '/bell',
      page: () => MindfulNotifierWidget(),
    ),
    GetPage(
      name: '/general',
      page: () => GeneralWidget(),
    ),
  ];
}
