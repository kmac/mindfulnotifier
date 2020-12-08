import 'package:get/get.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/screens/schedules/schedulesview.dart';

class Router {
  static final route = [
    GetPage(
      name: '/',
      page: () => MindfulNotifierAppWidget(),
    ),
    GetPage(
      name: '/schedules',
      page: () => SchedulesWidget(),
    ),
  ];
}
