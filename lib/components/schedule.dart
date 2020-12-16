import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'dart:io';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

// import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/reminders.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('schedule'));

String getCurrentIsolate() {
  return "I:${Isolate.current.hashCode}";
}

enum ScheduleType { PERIODIC, RANDOM }

const bool useHeartbeat = true;
const bool rescheduleOnReboot = useHeartbeat;
const int controlAlarmId = 5;
bool androidAlarmManagerInitialized = false;

Future<void> initializeScheduler() async {
  // THIS IS ON THE 'MAIN' ISOLATE
  // Nothing else in this file should be on the main isolate.

  if (!androidAlarmManagerInitialized) {
    logger.i("Initializing AndroidAlarmManager ${getCurrentIsolate()}");
    await AndroidAlarmManager.initialize();
    androidAlarmManagerInitialized = true;
  }

  // Send ourselves a bootstrap message which will come back in on the
  // alarm manager isolate (which we're also calling the scheduler isolate)
  if (!await AndroidAlarmManager.oneShot(
      Duration(seconds: 1), controlAlarmId, controlCallback,
      exact: true, wakeup: true, rescheduleOnReboot: false)) {
    var errmsg =
        "Scheduling oneShot control alarm failed on timer id: $controlAlarmId";
    logger.e(errmsg);
    throw AssertionError(errmsg);
  }
}

void enableHeartbeat() async {
  // Heartbeat is a last-ditch alarm triggered hourly. This is just in case
  // we miss the scheduler alarm on a reboot.
  if (useHeartbeat) {
    await AndroidAlarmManager.cancel(controlAlarmId);
    logger.i("Enabling heartbeat");
    if (!await AndroidAlarmManager.periodic(
        Duration(hours: 1), controlAlarmId, controlCallback,
        // startAt: DateTime.now().add(Duration(hours: 1)),
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true)) {
      var errmsg =
          "Scheduling periodic control alarm failed on timer id: $controlAlarmId";
      logger.e(errmsg);
      throw AssertionError(errmsg);
    }
  }
}

void disableHeartbeat() async {
  if (useHeartbeat) {
    logger.i("Cancelling heartbeat");
    await AndroidAlarmManager.cancel(controlAlarmId);
  }
}

void controlCallback() async {
  logger.i("controlCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  // Create and initialize the Scheduler singleton
  // This is only available in the alarm manager isolate
  bool wasInit = await Scheduler.checkInitialized();
  if (useHeartbeat) {
    Scheduler.sendControlMessage(
        "HB:${formatHHMM(DateTime.now())}:${wasInit ? 'T' : 'F'}");
  } else {
    Scheduler.sendControlMessage(
        "CO:${formatHHMM(DateTime.now())}:${wasInit ? 'T' : 'F'}");
  }
}

class Scheduler {
  static const int scheduleAlarmID = 10;

  static bool running = false;
  static bool initialized = false;

  static ScheduleDataStoreRO _ds;
  bool alarmManagerInitialized = false;
  Notifier _notifier;
  static Reminders _reminders;
  DelegatedScheduler delegate;
  StreamSubscription fromAppIsolateStreamSubscription;
  ReceivePort fromAppIsolateReceivePort;

  // Singleton
  static Scheduler _instance;
  Scheduler._internal() {
    _instance = this;
  }
  factory Scheduler() => _instance ?? Scheduler._internal();

  Future<void> init() async {
    logger.i(
        "Initializing scheduler, initialized=$initialized ${getCurrentIsolate()}");
    // schedDS = await ScheduleDataStore.getInstance();
    initializeFromAppIsolateReceivePort();
    _notifier = Notifier();
    _notifier.init();
    _reminders = await Reminders.create();
    initialized = true;
    // this is the only time we read from SharedPreferences (to avoid race conditions I was hitting)
    if (_ds == null) {
      update((await ScheduleDataStore.getInstance()).getScheduleDataStoreRO());
    }
    if (_ds.enabled) {
      logger.i("Re-enabling on init!");
      enable();
    }
  }

  void shutdown() {
    logger.i("shutdown");
    disable();
    shutdownReceivePort();
    initialized = false;
  }

  void initializeFromAppIsolateReceivePort() async {
    logger.i("initializeFromAppIsolateReceivePort ${getCurrentIsolate()}");

    fromAppIsolateReceivePort = ReceivePort();

    // Register for events from the UI isolate. These messages will
    // be triggered from the UI side
    fromAppIsolateStreamSubscription = fromAppIsolateReceivePort.listen((map) {
      //
      // WE ARE IN THE ALARM ISOLATE
      //
      logger
          .i("fromAppIsolateReceivePort received: $map ${getCurrentIsolate()}");
      String key = map.keys.first;
      // String value = map.values.first;
      Scheduler scheduler = Scheduler();
      switch (key) {
        case 'update':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          scheduler.update(dataStoreRO);
          // scheduler.reenable();
          break;
        case 'enable':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          scheduler.enable(dataStoreRO);
          // scheduler.reenable();
          break;
        case 'disable':
          scheduler.disable();
          break;
        case 'restart':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          scheduler.restart(dataStoreRO);
          break;
        case 'shutdown':
          scheduler.shutdown();
          break;
      }
    }, onDone: () {
      logger.w("fromAppIsolateReceivePort is closed ${getCurrentIsolate()}");
    });

    // Register our SendPort for the app to be able to send to our ReceivePort
    bool result = IsolateNameServer.registerPortWithName(
      fromAppIsolateReceivePort.sendPort,
      constants.toSchedulerSendPortName,
    );
    logger.d(
        "registerPortWithName: ${constants.toSchedulerSendPortName}, result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void shutdownReceivePort() async {
    logger.i("shutdownReceivePort");
    fromAppIsolateReceivePort.close();
    await fromAppIsolateStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(constants.toSchedulerSendPortName);
  }

  static void setMessage(String msg) async {
    // schedDS.message = msg;
    var toAppSendPort =
        IsolateNameServer.lookupPortByName(constants.toAppSendPortName);
    toAppSendPort?.send({'message': msg});
  }

  static void setInfoMessage(String msg) async {
    var toAppSendPort =
        IsolateNameServer.lookupPortByName(constants.toAppSendPortName);
    toAppSendPort?.send({'infoMessage': msg});
  }

  static void sendControlMessage(String msg) async {
    var toAppSendPort =
        IsolateNameServer.lookupPortByName(constants.toAppSendPortName);
    toAppSendPort?.send({'controlMessage': msg});
  }

  void update([ScheduleDataStoreRO dataStoreRO]) {
    Get.delete<ScheduleDataStoreRO>(force: true);
    _ds = Get.put(dataStoreRO, permanent: true);
  }

  void enable([ScheduleDataStoreRO dataStoreRO]) {
    if (dataStoreRO != null) {
      update(dataStoreRO);
    }
    if (running) {
      disable();
    }
    logger.i("enable");
    enableHeartbeat();
    delegate = _buildSchedulerDelegate(this);
    delegate.quietHours.initializeTimers();
    delegate.scheduleNext();
  }

  void disable() async {
    logger.i("disable");
    delegate?.cancel();
    Notifier.cancelAll();
    disableHeartbeat();
    running = false;
  }

  void restart(ScheduleDataStoreRO store) {
    disable();
    sleep(Duration(seconds: 1));
    enable(store);
  }

  void initialScheduleComplete() {
    running = true;
  }

  DelegatedScheduler _buildSchedulerDelegate(Scheduler scheduler) {
    logger.i('Building scheduler delegate: ${_ds.scheduleTypeStr}');
    var scheduleType;
    if (_ds.scheduleTypeStr == 'periodic') {
      scheduleType = ScheduleType.PERIODIC;
    } else {
      scheduleType = ScheduleType.RANDOM;
    }
    QuietHours quietHours = new QuietHours(
        new TimeOfDay(
            hour: _ds.quietHoursStartHour, minute: _ds.quietHoursStartMinute),
        new TimeOfDay(
            hour: _ds.quietHoursEndHour, minute: _ds.quietHoursEndMinute));
    var delegate;
    if (scheduleType == ScheduleType.PERIODIC) {
      delegate = PeriodicScheduler(
          scheduler, quietHours, _ds.periodicHours, _ds.periodicMinutes);
    } else {
      delegate = RandomScheduler(
          scheduler,
          quietHours,
          _ds.randomMinHours * 60 + _ds.randomMinMinutes,
          _ds.randomMaxHours * 60 + _ds.randomMaxMinutes);
    }
    return delegate;
  }

  void triggerNotification() {
    if (!running) {
      return;
    }
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    logger.i("triggerNotification ${getCurrentIsolate()}");

    if (delegate.quietHours.inQuietHours) {
      logger.i("In quiet hours... ignoring notification");
      setInfoMessage("In quiet hours $now");
      return;
    }
    if (delegate.quietHours.isInQuietHours(now)) {
      // Note: this could happen if enabled in quiet hours:
      logger.i("In quiet hours (missed alarm)... ignoring notification");
      setInfoMessage("In quiet hours $now");
      return;
    }
    var reminder = _reminders.randomReminder();
    _notifier.showNotification(reminder);
    setMessage(reminder);
    delegate.scheduleNext();
  }

  static Future<bool> checkInitialized() async {
    if (!Scheduler.initialized) {
      logger.w('checkInitialized: Scheduler is not initialized');
      await Scheduler().init();
      return false; // was not initialized
    }
    return true;
  }

  static void scheduleCallback() {
    logger.i("[${DateTime.now()}] scheduleCallback  ${getCurrentIsolate()}");
    checkInitialized();
    Scheduler().triggerNotification();
  }

  static void quietHoursStartCallback() {
    logger.i(
        "[${DateTime.now()}] quietHoursStartCallback ${getCurrentIsolate()}");
    checkInitialized();
    Scheduler().delegate.quietHours.quietStart();
  }

  static void quietHoursEndCallback() {
    logger
        .i("[${DateTime.now()}] quietHoursEndCallback ${getCurrentIsolate()}");
    checkInitialized();
    Scheduler().delegate.quietHours.quietEnd();
  }
}

abstract class DelegatedScheduler {
  final ScheduleType scheduleType;
  final Scheduler scheduler;
  final QuietHours quietHours;
  bool scheduled = false;

  DelegatedScheduler(this.scheduleType, this.scheduler, this.quietHours);

  void cancel() async {
    logger.i("Cancelling notification schedule ${getCurrentIsolate()}");
    quietHours.cancelTimers();
    await AndroidAlarmManager.cancel(Scheduler.scheduleAlarmID);
  }

  void scheduleNext() {
    logger.d(
        "Scheduling next notification, type=$scheduleType ${getCurrentIsolate()}");
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
        // schedule next for top of the next hour
        DateTime startTimeRaw = now.add(Duration(hours: 1));
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        break;
      case 30:
        // schedule next for either top or bottom the hour (< 30m)
        DateTime startTimeRaw = now.add(Duration(minutes: 30));
        if (startTimeRaw.minute < 30) {
          // we can schedule it for the top of the next hour
          startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        } else {
          // schedule it for the bottom of the next
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
          // ++newHour;
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
        Scheduler.setInfoMessage(
            "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}");
        scheduled = true;
      }
      return;
    }
    DateTime startTime = getInitialStart();
    logger.d("Scheduling: now: ${DateTime.now()}, startTime: $startTime");
    var firstNotifDate = formatHHMM(startTime);
    //controller.setMessage("First notification scheduled for $firstNotifDate");
    Scheduler.setInfoMessage(
        "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}," +
            " beginning at $firstNotifDate");
    await AndroidAlarmManager.periodic(
        Duration(hours: durationHours, minutes: durationMinutes),
        Scheduler.scheduleAlarmID,
        Scheduler.scheduleCallback,
        startAt: startTime,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: rescheduleOnReboot);

    initialScheduleComplete();
  }
}

class RandomScheduler extends DelegatedScheduler {
  final int minMinutes;
  final int maxMinutes;
  static const bool rescheduleAfterQuietHours = true;

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
    if (rescheduleAfterQuietHours &&
        (quietHours.inQuietHours || quietHours.isInQuietHours(nextDate))) {
      nextDate =
          quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
      logger.i(
          "Scheduling next random notification, past quiet hours: $nextDate");
      Scheduler.setInfoMessage(
          "In quiet hours, next reminder at ${formatHHMMSS(nextDate)}");
    } else {
      logger.i("Scheduling next random notification at $nextDate");
      Scheduler.setInfoMessage(
          "Next notification at ${formatHHMMSS(nextDate)} (${nextMinutes}");
    }
    await AndroidAlarmManager.oneShotAt(
        nextDate, Scheduler.scheduleAlarmID, Scheduler.scheduleCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: rescheduleOnReboot);

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

  QuietHours(this.startTime, this.endTime);
  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));

  DateTime _convertTimeOfDayToToday(TimeOfDay tod, {DateTime now}) {
    // now can be overridden for testing
    now ??= DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToTomorrow(TimeOfDay tod, {DateTime now}) {
    // now can be overridden for testing
    now ??= DateTime.now();
    final tomorrow = now.add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToYesterday(TimeOfDay tod, {DateTime now}) {
    // now can be overridden for testing
    now ??= DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    return DateTime(
        yesterday.year, yesterday.month, yesterday.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart({DateTime now}) {
    now ??= DateTime.now();
    DateTime quietStart = _convertTimeOfDayToToday(startTime, now: now);
    if (quietStart.isBefore(now)) {
      quietStart = _convertTimeOfDayToTomorrow(startTime, now: now);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd({DateTime now}) {
    now ??= DateTime.now();
    DateTime quietEnd = _convertTimeOfDayToToday(endTime, now: now);
    // if (quietEnd.isAtSameMomentAs(now) || quietEnd.isBefore(now)) {
    if (quietEnd.isBefore(now)) {
      quietEnd = _convertTimeOfDayToTomorrow(endTime, now: now);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime date, {DateTime now}) {
    /* 
            ???   today   ???         ???     tomorrow  ???
        ---------------------------------------------------------------
              now1              now2                now3 (same as now1)
               V                 V                   V
        ----------------|---------------------|-------------
                    quiet start            quiet end
        
      Is now before today's quiet start AND before today's end?
          Y -> not in quiet
          N -> Is now after today's quiet start?
              Y -> Is now before today's quiet end or before tomorrow's end?
                  Y -> in quiet
              N -> Is now before yesterday's start AND before tomorrow's quiet end?
                  Y -> in quiet
     */
    now ??= DateTime.now();
    DateTime todayStart = _convertTimeOfDayToToday(startTime, now: now);
    DateTime todayEnd = _convertTimeOfDayToToday(endTime, now: now);
    if (now.isBefore(todayStart)) {
      if (now.isBefore(todayEnd)) {
        return true;
      } else {
        return false;
      }
    } else {
      // we are after today's start
      DateTime tomorrowEnd = _convertTimeOfDayToTomorrow(endTime, now: now);
      if (now.isBefore(todayEnd) || now.isBefore(tomorrowEnd)) {
        return true;
      }
    }
    // but what if it started yesterday?
    DateTime yesterdayStart = _convertTimeOfDayToYesterday(startTime, now: now);
    if (now.isAfter(yesterdayStart) && now.isBefore(todayEnd)) {
      return true;
    }
    return false;
  }

  void initializeTimers() async {
    if (isInQuietHours(DateTime.now())) {
      quietStart();
    }
    var nextQuietStart = getNextQuietStart();
    var nextQuietEnd = getNextQuietEnd();
    logger.i(
        "Initializing quiet hours timers, start=$nextQuietStart, end=$nextQuietEnd");
    assert(nextQuietStart.isAfter(DateTime.now()));
    if (!await AndroidAlarmManager.periodic(Duration(days: 1),
        quietHoursStartAlarmID, Scheduler.quietHoursStartCallback,
        startAt: nextQuietStart,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: rescheduleOnReboot)) {
      var message =
          "periodic schedule failed on quiet hours start timer: $quietHoursStartAlarmID";
      logger.e(message);
      throw AssertionError(message);
    }
    if (!await AndroidAlarmManager.periodic(Duration(days: 1),
        quietHoursEndAlarmID, Scheduler.quietHoursEndCallback,
        startAt: nextQuietEnd,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: rescheduleOnReboot)) {
      var message =
          "periodic schedule failed on quiet hours end timer: $quietHoursEndAlarmID";
      logger.e(message);
      throw AssertionError(message);
    }
    logger.i(
        "Initialized quiet hours timers, start=$nextQuietStart, end=$nextQuietEnd");
  }

  void cancelTimers() async {
    logger.i("Cancelling quiet hours timers");
    if (!await AndroidAlarmManager.cancel(quietHoursStartAlarmID)) {
      logger.e("cancel failed on quiet hours timers: $quietHoursStartAlarmID");
    }
    if (!await AndroidAlarmManager.cancel(quietHoursEndAlarmID)) {
      logger.e("cancel failed on quiet hours timers: $quietHoursEndAlarmID");
    }
  }

  void quietStart() {
    final DateTime now = DateTime.now();
    logger.i("[$now] Quiet hours start");
    inQuietHours = true;
    Scheduler.setMessage('In quiet hours');
  }

  void quietEnd() {
    final DateTime now = DateTime.now();
    logger.i("[$now] Quiet hours end");
    inQuietHours = false;
    Scheduler.setMessage('Quiet Hours have ended.');
  }
}
