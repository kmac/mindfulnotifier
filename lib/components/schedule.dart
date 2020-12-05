import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';

import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/reminders.dart';
import 'package:mindfulnotifier/components/utils.dart';

void initializeAlarmManager() async {
  await AndroidAlarmManager.initialize();
}

// The name associated with the UI isolate's [SendPort].
const String isolateName = 'alarmIsolate';

// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort port = ReceivePort();

enum ScheduleType { PERIODIC, RANDOM }

abstract class Scheduler {
  final MindfulNotifierWidgetController controller;
  final ScheduleType scheduleType;
  final QuietHours quietHours;
  final String appName;
  final int scheduleAlarmID = 10;
  Notifier _notifier;
  bool running = false;
  static bool initialized = false;
  final Reminders reminders = Reminders();

  // The background
  static SendPort uiSendPort;

  Scheduler(this.controller, this.scheduleType, this.quietHours, this.appName) {
    quietHours.controller = controller;
    _notifier = new Notifier(appName);
  }

  void init() {
    print("Initializing scheduler");

    // IsolateNameServer.registerPortName(receivePort.sendPort, isolateName);
    reminders.init();

    uiSendPort = null;

    if (!Scheduler.initialized) {
      // Register the UI isolate's SendPort to allow for communication from the
      // background isolate.
      bool regResult = IsolateNameServer.registerPortWithName(
        port.sendPort,
        isolateName,
      );
      print("registerPortWithName: $regResult");
      // assert(regResult);

      // Register for events from the background isolate. These messages will
      // always coincide with an alarm firing.
      port.listen((_) {
        switch (_) {
          case 'scheduleCallback':
            _triggerNotification();
            break;
          case 'quietStartCallback':
            quietHours.quietStart();
            break;
          case 'quietEndCallback':
            quietHours.quietEnd();
            break;
        }
      });
    }
    Scheduler.initialized = true;
  }

  void cancelSchedule() async {
    print("Cancelling notification schedule");
    await AndroidAlarmManager.cancel(scheduleAlarmID);
  }

  void enable() {
    init();
    quietHours.initializeTimers();
    schedule();
    running = true;
  }

  void disable() {
    cancelSchedule();
    Notifier.cancelAll();
    quietHours.cancelTimers();
    // port.close();
    // IsolateNameServer.removePortNameMapping(isolateName);
    running = false;
  }

  void schedule() {
    print("Scheduling notification, type=$scheduleType");
  }

  void _triggerNotification() {
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] _triggerNotification isolate=$isolateId");

    // if (quietHours.isInQuietHours(now)) {
    if (quietHours.inQuietHours) {
      print("In quiet hours... ignoring notification");
      return;
    }
    var reminder = reminders.randomReminder();
    _notifier.showNotification(reminder);
    controller.setMessage(reminder);
  }

  // alarmCallback will not run in the same isolate as the main application.
  // Unlike threads, isolates do not share memory and communication between
  // isolates must be done via message passing (see more documentation on isolates here).
  static void alarmCallback() {
    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] alarmCallback isolate=$isolateId");

    // Send to the UI thread

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('scheduleCallback');
  }
}

// Best thing to do would be to make these delegated pattern
// and get rid of the inheritance. Then the scheduler is a singleton, and
// doesn't go away. But the underlying delegated task can change
abstract class DelegatedScheduler {
  void triggerNotification();
  void schedule();
  void reschedule();
}

class PeriodicScheduler extends Scheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  PeriodicScheduler(var controller, this.durationHours, this.durationMinutes,
      var quietHours, var appName)
      : super(controller, ScheduleType.PERIODIC, quietHours, appName);

  DateTime getInitialStart({DateTime now}) {
    now ??= DateTime.now();
    // int periodInMins = 60 * durationHours + durationMinutes;
    DateTime startTime;
    switch (durationMinutes) {
      case 0:
        // case 45:
        // schedule next for top of the hour
        DateTime startTimeRaw = now.add(Duration(hours: 1));
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        break;
      case 30:
        // schedule next for either top or bottom the hour (< 30m)
        DateTime startTimeRaw = now.add(Duration(minutes: 30));
        if (startTimeRaw.minute < 30) {
          startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        } else {
          startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 30, 0, 0, 0);
        }
        break;
      case 15:
        // schedule next for < 15m
        DateTime startTimeRaw = now.add(Duration(minutes: 15));
        int newMinute = now.minute + 15;
        int newHour = startTimeRaw.hour;
        if (newMinute >= 60) {
          ++newHour;
          newMinute = 0;
        } else if (newMinute >= 45) {
          newMinute = 45;
        } else if (newMinute >= 30) {
          newMinute = 30;
        } else if (newMinute >= 15) {
          newMinute = 15;
        } else {
          newMinute = 0;
        }
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, newHour, newMinute, 0, 0, 0);
        break;
    }
    return startTime;
  }

  void _triggerNotification() {
    super._triggerNotification();
    controller.setInfoMessage(
        "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}");
  }

  void schedule() async {
    super.schedule();
    DateTime startTime = getInitialStart();
    print("Scheduling: now: ${DateTime.now()}, startTime: $startTime");
    var firstNotifDate =
        formatDate(startTime, [h, ':', nn, " ", am]).toString();
    //controller.setMessage("First notification scheduled for $firstNotifDate");
    controller.setInfoMessage(
        "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}," +
            " beginning at $firstNotifDate");
    await AndroidAlarmManager.periodic(
        Duration(hours: durationHours, minutes: durationMinutes),
        scheduleAlarmID,
        Scheduler.alarmCallback,
        startAt: startTime,
        exact: true,
        wakeup: true);
  }
}

class RandomScheduler extends Scheduler {
  final int minMinutes;
  final int maxMinutes;

  RandomScheduler(var controller, this.minMinutes, this.maxMinutes,
      var quietHours, var appName)
      : super(controller, ScheduleType.RANDOM, quietHours, appName);

  void _triggerNotification() {
    super._triggerNotification();
    schedule();
  }

  void schedule() async {
    super.schedule();
    int nextMinutes;
    if ((maxMinutes == minMinutes) || (minMinutes > maxMinutes)) {
      nextMinutes = maxMinutes;
    } else {
      nextMinutes = minMinutes + Random().nextInt(maxMinutes - minMinutes);
    }
    if (nextMinutes <= 1) {
      nextMinutes = 2;
    }
    DateTime nextDate = DateTime.now().add(Duration(minutes: nextMinutes));
    // if (quietHours.inQuietHours(nextDate)) {
    //   print("Scheduling past next quiet hours");
    //   nextDate = quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
    // }
    if (quietHours.inQuietHours) {
      print("Scheduling past next quiet hours");
      nextDate =
          quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
      controller.setInfoMessage(
          "In quiet hours, next reminder at ${nextDate.hour}:${timeNumToString(nextDate.minute)}");
    } else {
      print("Scheduling next random notifcation at $nextDate");
      // controller.setNextNotification(nextDate);
      controller.setInfoMessage(
          "Next: $nextDate, nextMinutes: $nextMinutes, min: $minMinutes, max: $maxMinutes");
    }
    await AndroidAlarmManager.oneShotAt(
        nextDate, scheduleAlarmID, Scheduler.alarmCallback,
        exact: true, wakeup: true);
  }
}

class QuietHours {
  static const int quietHoursStartAlarmID = 21;
  static const int quietHoursEndAlarmID = 22;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  bool inQuietHours = false;
  static SendPort uiSendPort;
  MindfulNotifierWidgetController controller;

  QuietHours(this.startTime, this.endTime);
  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));

  DateTime _getTimeOfDayToday(TimeOfDay tod) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime _getTimeOfDayTomorrow(TimeOfDay tod) {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart() {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    if (quietStart.isBefore(DateTime.now())) {
      quietStart = _getTimeOfDayTomorrow(startTime);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd() {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = _getTimeOfDayToday(endTime);
    if (quietEnd.isBefore(quietStart)) {
      quietEnd = _getTimeOfDayTomorrow(endTime);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime date) {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = getNextQuietEnd();
    return (date.isAfter(quietStart) && date.isBefore(quietEnd));
  }

  void initializeTimers() async {
    if (isInQuietHours(DateTime.now())) {
      quietStart();
    }
    var nextQuietStart = getNextQuietStart();
    var nextQuietEnd = getNextQuietEnd();
    print(
        "Initializing quiet hours timers, start=$nextQuietStart, end=$nextQuietEnd");
    assert(nextQuietStart.isAfter(DateTime.now()));
    assert(nextQuietStart.isBefore(nextQuietEnd));
    await AndroidAlarmManager.periodic(Duration(days: 1),
        quietHoursStartAlarmID, QuietHours.alarmCallbackStart,
        startAt: nextQuietStart, exact: true, wakeup: true);
    await AndroidAlarmManager.periodic(
        Duration(days: 1), quietHoursEndAlarmID, QuietHours.alarmCallbackEnd,
        startAt: nextQuietEnd, exact: true, wakeup: true);
  }

  void cancelTimers() async {
    print("Cancelling quiet hours timers");
    await AndroidAlarmManager.cancel(quietHoursStartAlarmID);
    await AndroidAlarmManager.cancel(quietHoursEndAlarmID);
  }

  void quietStart() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours start");
    inQuietHours = true;
    controller?.setMessage('In quiet hours');
  }

  static void alarmCallbackStart() {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('quietStartCallback');
  }

  void quietEnd() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours end");
    inQuietHours = false;
    controller?.setMessage('Quiet Hours have ended.');
  }

  static void alarmCallbackEnd() {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('quietEndCallback');
  }
}
