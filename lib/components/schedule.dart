import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:android_alarm_manager/android_alarm_manager.dart';

import 'package:remindfulbell/screens/app/remindfulbell.dart';
import 'package:remindfulbell/components/notifier.dart';
import 'package:remindfulbell/components/reminders.dart';

const bool testing = false;

void initializeAlarmManager() async {
  await AndroidAlarmManager.initialize();
}

// The name associated with the UI isolate's [SendPort].
const String isolateName = 'alarmIsolate';

// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort port = ReceivePort();

enum ScheduleType { PERIODIC, RANDOM }

abstract class Scheduler {
  final RemindfulWidgetController controller;
  final ScheduleType scheduleType;
  final QuietHours quietHours;
  final String appName;
  final int scheduleAlarmID = 10;
  Notifier _notifier;
  bool running = false;
  static bool initialized = false;
  Reminders reminders;

  // The background
  static SendPort uiSendPort;

  Scheduler(this.controller, this.scheduleType, this.quietHours, this.appName) {
    _notifier = new Notifier(appName);
    _init();
  }

  void _init() async {
    // Register the UI isolate's SendPort to allow for communication from the
    // background isolate.
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      isolateName,
    );

    uiSendPort = null;
    if (!Scheduler.initialized) {
      print("Initializing scheduler");
      // IsolateNameServer.registerPortName(receivePort.sendPort, isolateName);
      reminders = new Reminders();
      reminders.init();

      // Register for events from the background isolate. These messages will
      // always coincide with an alarm firing.
      //port.listen((_) async => await _triggerNotification());
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
    quietHours.initializeTimers();
    schedule();
    running = true;
  }

  void disable() {
    cancelSchedule();
    quietHours.cancelTimers();
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
    if (QuietHours.inQuietHours) {
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

class PeriodicScheduler extends Scheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  PeriodicScheduler(var controller, this.durationHours, this.durationMinutes,
      var quietHours, var appName)
      : super(controller, ScheduleType.PERIODIC, quietHours, appName);

  DateTime getInitialStart({DateTime now}) {
    now ??= DateTime.now();
    int periodInMins = 60 * durationHours + durationMinutes;
    DateTime startTime = now.add(Duration(minutes: periodInMins));
    switch (durationMinutes) {
      case 0:
      case 45:
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
        int newMinute;
        int newHour = startTimeRaw.hour;
        // want to use the diff here, between now and 15m interval
        if (startTimeRaw.minute >= 0 && startTimeRaw.minute < 15) {
          newMinute = 0;
        } else if (startTimeRaw.minute >= 15 && startTimeRaw.minute < 30) {
          newMinute = 15;
        } else if (startTimeRaw.minute >= 30 && startTimeRaw.minute < 45) {
          newMinute = 30;
        } else {
          if (++newHour > 23) {
            // day rollover
            startTimeRaw = now.add(Duration(days: 1));
            newHour = 0;
          }
          newMinute = 0;
        }
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, newHour, newMinute, 0, 0, 0);
        break;
    }
    return startTime;

    // // Schedule first notification to align with the top of the hour,
    // // based on the hours/mins. The minimum granularity is 15m.
    // int periodInMins = 60 * durationHours + durationMinutes;

    // DateTime startTime = now.add(Duration(minutes: periodInMins));

    // int nowMillisecondsSinceEpoch = now.millisecondsSinceEpoch;
    // int nowMinSinceEpoch = (nowMillisecondsSinceEpoch / 60000).round();

    // int nextIntervalMin = (nowMinSinceEpoch + periodInMins) % periodInMins + 1;

    // DateTime startTimeRaw = DateTime.fromMillisecondsSinceEpoch(
    //     nowMillisecondsSinceEpoch + (nextIntervalMin * 60000));
    // DateTime startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
    //     startTimeRaw.day, startTimeRaw.hour, startTimeRaw.minute, 0, 0, 0);
    // print(
    //     "Scheduling: now: $now, nextIntervalMin: $nextIntervalMin, startTime: $startTime");
  }

  void schedule() async {
    super.schedule();
    if (testing) {
      print("Scheduling for periodic testing");
      await AndroidAlarmManager.periodic(
          Duration(seconds: 30), scheduleAlarmID, Scheduler.alarmCallback,
          exact: true, wakeup: true);
      return;
    }
    DateTime startTime = getInitialStart();
    print("Scheduling: now: ${DateTime.now()}, startTime: $startTime");
    controller.setNextNotification(
        new TimeOfDay(hour: startTime.hour, minute: startTime.minute));
    _notifier.showNotification("Scheduled periodic reminders");
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
  //DateTimeRange range;
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
    Random random = new Random();
    int nextMinutes = minMinutes + random.nextInt(maxMinutes - minMinutes);
    DateTime nextDate = DateTime.now().add(Duration(minutes: nextMinutes));
    // if (quietHours.inQuietHours(nextDate)) {
    //   print("Scheduling past next quiet hours");
    //   nextDate = quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
    // }
    print("Scheduling next random notifcation at $nextDate");
    controller.setNextNotification(
        new TimeOfDay(hour: nextDate.hour, minute: nextDate.minute));
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
  static bool inQuietHours = false;
  static SendPort uiSendPort;

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
    print("Initializing quiet hours timers");
    await AndroidAlarmManager.periodic(Duration(days: 1),
        quietHoursStartAlarmID, QuietHours.alarmCallbackStart,
        startAt: getNextQuietStart(), exact: true, wakeup: true);
    await AndroidAlarmManager.periodic(
        Duration(days: 1), quietHoursEndAlarmID, QuietHours.alarmCallbackEnd,
        startAt: getNextQuietEnd(), exact: true, wakeup: true);
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
  }

  static void alarmCallbackEnd() {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('quietEndCallback');
  }
}
