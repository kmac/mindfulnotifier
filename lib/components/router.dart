import 'package:get/get.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/screens/schedules/schedulesview.dart';

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
      page: () => MindfulNotifierWidget(),
    ),
    GetPage(
      name: '/bell',
      page: () => MindfulNotifierWidget(),
    ),
    GetPage(
      name: '/advanced',
      page: () => MindfulNotifierWidget(),
    ),
  ];
}
