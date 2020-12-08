import 'dart:async';
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

// A port used to communicate from the alarm isolate to the UI isolate.
ReceivePort receivePort;
StreamSubscription receivePortSubscription;

// The port used to send back to the UI thread from the alarm isolate,
// i.e. it is the receivePort.sendPort
SendPort alarmCallbackSendPort;

void initializeReceivePort() async {
  print("initializeReceivePort");

  if (receivePort == null) {
    print("new receivePort");
    receivePort = ReceivePort();
    // Register the UI isolate's SendPort to allow for communication from the
    // background isolate.
    bool regResult = IsolateNameServer.registerPortWithName(
      receivePort.sendPort,
      isolateName,
    );
    print("registerPortWithName: $regResult");
    assert(regResult);

    // Register for events from the background isolate. These messages will
    // always coincide with an alarm firing.
    receivePortSubscription = receivePort.listen((_) {
      print("receivePort received: $_");
      // This is running in the UI thread.
      // The Scheduler instance should be the current one.
      Scheduler scheduler = Scheduler();
      switch (_) {
        case 'scheduleCallback':
          scheduler.triggerNotification();
          break;
        case 'quietStartCallback':
          scheduler.delegate.quietHours.quietStart();
          break;
        case 'quietEndCallback':
          scheduler.delegate.quietHours.quietEnd();
          break;
      }
    }, onDone: () {
      print("receivePort is closed");
    });
  }
}

void shutdownReceivePort() async {
  print("shutdownReceivePort");
  receivePort.close();
  await receivePortSubscription.cancel();
  IsolateNameServer.removePortNameMapping(isolateName);
}

// alarmCallback will not run in the same isolate as the main application.
// This method does not share memory with anything else here!

void scheduleCallback() {
  print("[${DateTime.now()}] scheduleCallback " +
      "isolate=${Isolate.current.hashCode}");
  // Send to the UI thread
  // This will be null if we're running in the background.
  alarmCallbackSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
  alarmCallbackSendPort?.send('scheduleCallback');
}

void quietHoursStartCallback() {
  print(
      "[${DateTime.now()}] quietHoursStartCallback isolate=${Isolate.current.hashCode}");
  // Send to the UI thread
  // This will be null if we're running in the background.
  alarmCallbackSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
  alarmCallbackSendPort?.send('quietStartCallback');
}

void quietHoursEndCallback() {
  print(
      "[${DateTime.now()}] quietHoursEndCallback isolate=${Isolate.current.hashCode}");
  // Send to the UI thread
  // This will be null if we're running in the background.
  alarmCallbackSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
  alarmCallbackSendPort?.send('quietEndCallback');
}

enum ScheduleType { PERIODIC, RANDOM }

class Scheduler {
  MindfulNotifierWidgetController controller;
  String appName = 'Mindful Notifier';
  final int scheduleAlarmID = 10;
  Notifier _notifier;
  static bool running = false;
  static bool initialized = false;
  Reminders reminders;
  DelegatedScheduler delegate;
  static DataStore _ds;

  static Scheduler _instance;

  Scheduler._internal() {
    _instance = this;
  }

  factory Scheduler() => _instance ?? Scheduler._internal();

  void init() async {
    print("Initializing scheduler, initialized=$initialized");
    _notifier = new Notifier(appName);

    reminders = Reminders();
    reminders.init();

    if (!initialized) {
      _ds = await DataStore.create();
      await AndroidAlarmManager.initialize();
    }
    initialized = true;
  }

  void shutdown() {
    print("shutdown");
    disable();
  }

  void enable() {
    delegate = _ds.buildSchedulerDelegate(this);
    delegate.quietHours.initializeTimers();
    delegate.scheduleNext();
  }

  void disable() {
    delegate?.cancel();
    Notifier.cancelAll();
    running = false;
  }

  void initialScheduleComplete() {
    running = true;
  }

  void triggerNotification() {
    if (!running) {
      return;
    }
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] triggerNotification isolate=$isolateId");

    if (delegate.quietHours.inQuietHours) {
      print("In quiet hours... ignoring notification");
      return;
    }
    if (delegate.quietHours.isInQuietHours(now)) {
      print("In quiet hours (!missed alarm!)... ignoring notification");
      return;
    }
    var reminder = reminders.randomReminder();
    _notifier.showNotification(reminder);
    controller.setMessage(reminder);
    delegate.scheduleNext();
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

  DelegatedScheduler(this.scheduleType, this.scheduler, this.quietHours) {
    quietHours.controller = scheduler.controller;
  }

  void cancel() async {
    print("Cancelling notification schedule");
    quietHours.cancelTimers();
    await AndroidAlarmManager.cancel(scheduler.scheduleAlarmID);
  }

  void scheduleNext() {
    print("Scheduling next notification, type=$scheduleType");
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
    super.scheduleNext();
    if (Scheduler.running) {
      // don't need to schedule anything
      if (!scheduled) {
        scheduler.controller.setInfoMessage(
            "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}");
        scheduled = true;
      }
      return;
    }
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
        scheduleCallback,
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
    if (quietHours.inQuietHours || quietHours.isInQuietHours(nextDate)) {
      nextDate =
          quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
      print("Scheduling next random notification, past quiet hours: $nextDate");
      scheduler.controller.setInfoMessage(
          "In quiet hours, next reminder at ${nextDate.hour}:${timeNumToString(nextDate.minute)}");
    } else {
      print("Scheduling next random notifcation at $nextDate");
      // controller.setNextNotification(nextDate);
      // This is temporary (switch to above when solid):
      scheduler.controller.setInfoMessage(
          "Next: $nextDate, nextMinutes: $nextMinutes, min: $minMinutes, max: $maxMinutes");
    }
    await AndroidAlarmManager.oneShotAt(
        nextDate, scheduler.scheduleAlarmID, scheduleCallback,
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
  MindfulNotifierWidgetController controller;

  QuietHours(this.startTime, this.endTime);
  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));

  DateTime _getTimeOfDayToday(TimeOfDay tod, {DateTime now}) {
    now ??= DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime _getTimeOfDayTomorrow(TimeOfDay tod, {DateTime now}) {
    now ??= DateTime.now();
    final tomorrow = now.add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart({DateTime now}) {
    now ??= DateTime.now();
    DateTime quietStart = _getTimeOfDayToday(startTime, now: now);
    if (quietStart.isBefore(now)) {
      quietStart = _getTimeOfDayTomorrow(startTime, now: now);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd({DateTime now}) {
    now ??= DateTime.now();
    DateTime quietEnd = _getTimeOfDayToday(endTime, now: now);
    // if (quietEnd.isAtSameMomentAs(now) || quietEnd.isBefore(now)) {
    if (quietEnd.isBefore(now)) {
      quietEnd = _getTimeOfDayTomorrow(endTime, now: now);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime date, {DateTime now}) {
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
    now ??= DateTime.now();
    if (date.isBefore(_getTimeOfDayToday(startTime, now: now))) {
      return false;
    } else {
      // We've past today's quiet start time.
      // Check if we're within either quiet end times.
      if (date.isBefore(_getTimeOfDayToday(endTime, now: now)) ||
          date.isBefore(_getTimeOfDayTomorrow(endTime, now: now))) {
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
    if (!await AndroidAlarmManager.periodic(
        Duration(days: 1), quietHoursStartAlarmID, quietHoursStartCallback,
        startAt: nextQuietStart,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: false)) {
      var message =
          "periodic schedule failed on quiet hours start timer: $quietHoursStartAlarmID";
      print(message);
      throw AssertionError(message);
    }
    if (!await AndroidAlarmManager.periodic(
        Duration(days: 1), quietHoursEndAlarmID, quietHoursEndCallback,
        startAt: nextQuietEnd,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: false)) {
      var message =
          "periodic schedule failed on quiet hours end timer: $quietHoursEndAlarmID";
      print(message);
      throw AssertionError(message);
    }
    print(
        "Initialized quiet hours timers, start=$nextQuietStart, end=$nextQuietEnd");
  }

  void cancelTimers() async {
    print("Cancelling quiet hours timers");
    if (!await AndroidAlarmManager.cancel(quietHoursStartAlarmID)) {
      print("cancel failed on quiet hours timers: $quietHoursStartAlarmID");
    }
    if (!await AndroidAlarmManager.cancel(quietHoursEndAlarmID)) {
      print("cancel failed on quiet hours timers: $quietHoursEndAlarmID");
    }
  }

  void quietStart() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours start");
    inQuietHours = true;
    controller?.setMessage('In quiet hours');
  }

  void quietEnd() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours end");
    inQuietHours = false;
    controller?.setMessage('Quiet Hours have ended.');
  }
}
