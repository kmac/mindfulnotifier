import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/reminders.dart';
import 'package:mindfulnotifier/components/utils.dart';

// The name associated with the UI isolate's [SendPort].
const String isolateName = 'alarmIsolate';

// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort receivePort = ReceivePort();

enum ScheduleType { PERIODIC, RANDOM }

class Scheduler {
  final MindfulNotifierWidgetController controller;
  final String appName;
  final int scheduleAlarmID = 10;
  Notifier _notifier;
  static bool running = false;
  static bool initialized = false;
  Reminders reminders;
  DelegatedScheduler delegate;
  static DataStore _ds;
  static var receivePortSubscription;

  // The background
  static SendPort uiSendPort;

  Scheduler(this.controller, this.appName) {
    _notifier = new Notifier(appName);
    _getDS();
  }

  void _getDS() async {
    _ds ??= await DataStore.create();
  }

  void init() async {
    reminders = Reminders();
    reminders.init();

    if (!Scheduler.initialized) {
      print("Initializing scheduler");

      await AndroidAlarmManager.initialize();

      // Register the UI isolate's SendPort to allow for communication from the
      // background isolate.
      bool regResult = IsolateNameServer.registerPortWithName(
        receivePort.sendPort,
        isolateName,
      );
      print("registerPortWithName: $regResult");
      assert(regResult);

      uiSendPort = null;

      // Register for events from the background isolate. These messages will
      // always coincide with an alarm firing.
      receivePortSubscription = receivePort.listen((_) {
        switch (_) {
          case 'scheduleCallback':
            _triggerNotification();
            break;
          case 'quietStartCallback':
            delegate.quietHours.quietStart();
            break;
          case 'quietEndCallback':
            delegate.quietHours.quietEnd();
            break;
        }
      }, onDone: () {
        print("receivePort is closed");
      });
    }
    Scheduler.initialized = true;
  }

  void shutdown() async {
    print("shutdown");
    disable();
    await receivePortSubscription.cancel();
    receivePort.close();
    // Register the UI isolate's SendPort to allow for communication from the
    // background isolate.
    IsolateNameServer.removePortNameMapping(isolateName);
  }

  void enable() {
    init();
    delegate = _ds.buildSchedulerDelegate(this);
    delegate.scheduleNext();
  }

  void disable() {
    delegate.cancel();
    Notifier.cancelAll();
    running = false;
  }

  void initialScheduleComplete() {
    running = true;
  }

  void _triggerNotification() {
    if (!running) {
      return;
    }
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] _triggerNotification isolate=$isolateId");

    // if (quietHours.isInQuietHours(now)) {
    if (delegate.quietHours.inQuietHours) {
      print("In quiet hours... ignoring notification");
      return;
    }
    var reminder = reminders.randomReminder();
    _notifier.showNotification(reminder);
    controller.setMessage(reminder);
    delegate.scheduleNext();
  }

  // alarmCallback will not run in the same isolate as the main application.
  // Unlike threads, isolates do not share memory and communication between
  // isolates must be done via message passing (see more documentation on isolates here).
  static void alarmCallback() {
    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] alarmCallback isolate=$isolateId, running=$running");
    //if (running) {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    //  uiSendPort?.send('scheduleCallback');
    //}
  }
}

// Best thing to do would be to make these delegated pattern
// and get rid of the inheritance. Then the scheduler is a singleton, and
// doesn't go away. But the underlying delegated task can change
abstract class DelegatedScheduler {
  final ScheduleType scheduleType;
  final Scheduler scheduler;
  final QuietHours quietHours;
  bool scheduled = false;

  DelegatedScheduler(this.scheduleType, this.scheduler, this.quietHours);

  void cancel() async {
    print("Cancelling notification schedule");
    quietHours.cancelTimers();
    await AndroidAlarmManager.cancel(scheduler.scheduleAlarmID);
  }

  void scheduleNext() {
    if (!scheduled) {
      quietHours.initializeTimers();
    }
    print("Scheduling notification, type=$scheduleType");
  }

  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
  }
}

class PeriodicScheduler extends DelegatedScheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  PeriodicScheduler(Scheduler scheduler, QuietHours quietHours,
      this.durationHours, this.durationMinutes)
      : super(ScheduleType.PERIODIC, scheduler, quietHours);

  void cancel() async {
    super.cancel();
  }

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

  void scheduleNext() async {
    if (Scheduler.running) {
      // don't need to schedule anything
      if (!scheduled) {
        scheduler.controller.setInfoMessage(
            "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}");
        scheduled = true;
      }
      return;
    }
    super.scheduleNext();
    DateTime startTime = getInitialStart();
    print("Scheduling: now: ${DateTime.now()}, startTime: $startTime");
    var firstNotifDate =
        formatDate(startTime, [h, ':', nn, " ", am]).toString();
    //controller.setMessage("First notification scheduled for $firstNotifDate");
    scheduler.controller.setInfoMessage(
        "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}," +
            " beginning at $firstNotifDate");
    await AndroidAlarmManager.periodic(
        Duration(hours: durationHours, minutes: durationMinutes),
        scheduler.scheduleAlarmID,
        Scheduler.alarmCallback,
        startAt: startTime,
        exact: true,
        wakeup: true);

    initialScheduleComplete();
  }
}

class RandomScheduler extends DelegatedScheduler {
  final int minMinutes;
  final int maxMinutes;

  RandomScheduler(Scheduler scheduler, QuietHours quietHours, this.minMinutes,
      this.maxMinutes)
      : super(ScheduleType.RANDOM, scheduler, quietHours);

  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
    scheduled = true;
  }

  void scheduleNext() async {
    super.scheduleNext();
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
      scheduler.controller.setInfoMessage(
          "In quiet hours, next reminder at ${nextDate.hour}:${timeNumToString(nextDate.minute)}");
    } else {
      print("Scheduling next random notifcation at $nextDate");
      // controller.setNextNotification(nextDate);
      scheduler.controller.setInfoMessage(
          "Next: $nextDate, nextMinutes: $nextMinutes, min: $minMinutes, max: $maxMinutes");
    }
    await AndroidAlarmManager.oneShotAt(
        nextDate, scheduler.scheduleAlarmID, Scheduler.alarmCallback,
        exact: true, wakeup: true);

    if (!scheduled) {
      initialScheduleComplete();
    }
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
    /* 
              now1              now2                now3 (same as now1)
               V                 V                   V
        ----------------|---------------------|-------------
                    quiet start            quiet end
        
      Is now before today's quiet start?
          Y -> not in quiet
      Is now after today's quiet start?
          Y -> Is now before today's quiet end?
              Y -> in quiet
          N -> Is now before tomorrow's quiet end?

     */
    if (date.isBefore(_getTimeOfDayToday(startTime))) {
      return false;
    } else {
      // We've past today's quiet start time.
      // Check if we're within either quiet end times.
      if (date.isBefore(_getTimeOfDayToday(endTime)) ||
          date.isBefore(_getTimeOfDayTomorrow(endTime))) {
        return true;
      }
    }
    return false;
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
