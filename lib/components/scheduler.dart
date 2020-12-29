import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';
import 'dart:io';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info/package_info.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/reminders.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('scheduler');

String getCurrentIsolate() {
  return "I:${Isolate.current.hashCode}";
}

enum ScheduleType { PERIODIC, RANDOM }

const bool useHeartbeat = true;
const bool rescheduleOnReboot = useHeartbeat;
const int controlAlarmId = 5;
bool androidAlarmManagerInitialized = false;

/// The Scheduler instance is only accessible
/// via the alarm callback isolate. It reads all data from shared preferences.
/// It creates the next alarm from that data on the fly.
/// - complete decoupling of the alarm/notification from the UI
/// - all data is shared via shared prefs
/// Alarms for:
/// - raising a notification
/// - quiet hours start/end (maybe end not required - just reschedule past next)
/// We also put the notification info in shared prefs and always read from that
/// on the UI side.
Future<void> initializeScheduler() async {
  // !!!
  // THIS IS ON THE 'MAIN' ISOLATE
  // Nothing else in this file should be on the main isolate.
  // !!!
  if (!androidAlarmManagerInitialized) {
    logger.i("Initializing AndroidAlarmManager ${getCurrentIsolate()}");
    await AndroidAlarmManager.initialize();
    androidAlarmManagerInitialized = true;
  }
  // Send ourselves a bootstrap message. The 'controlCallback' will be
  // invoked on the alarm manager isolate (also called the scheduler isolate)
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
  // Heartbeat is a last-ditch alarm triggered at a regular interval.
  //  This is just in case we miss the scheduler alarm on a reboot.
  if (useHeartbeat) {
    await AndroidAlarmManager.cancel(controlAlarmId);
    logger.i("Enabling heartbeat");
    if (!await AndroidAlarmManager.periodic(
        Duration(minutes: 30), controlAlarmId, controlCallback,
        exact: true, wakeup: true, rescheduleOnReboot: true)) {
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
  // This is only available in the alarm manager isolate
  // Create and initialize the Scheduler singleton
  bool wasInit = await Scheduler.checkInitialized();
  if (useHeartbeat) {
    Scheduler.sendControlMessage(
        "HB:${formatHHMM(DateTime.now())}:${wasInit ? 'T' : 'F'}");
  } else {
    Scheduler.sendControlMessage(
        "CO:${formatHHMM(DateTime.now())}:${wasInit ? 'T' : 'F'}");
  }
  // if (!wasInit) {
  //   final ds = await findScheduleDataStoreRO();
  //   if (ds.enabled) {
  //     Scheduler()
  //         .notifier
  //         .showInfoNotification('${constants.appName} is running');
  //   }
  // }
}

/// The main class for scheduling notifications
class Scheduler {
  static const int scheduleAlarmID = 10;

  static bool running = false;
  static bool initialized = false;

  static ScheduleDataStoreRO _ds;
  bool alarmManagerInitialized = false;
  Notifier notifier;
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
    PackageInfo info = await PackageInfo.fromPlatform();
    Get.put(info);
    initializeFromAppIsolateReceivePort();
    notifier = Notifier();
    notifier.start();
    _reminders = await Reminders.create();
    initialized = true;
    // this is the only time we read from SharedPreferences (to avoid race conditions I was hitting)
    if (_ds == null) {
      update(await findScheduleDataStoreRO(false));
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
    notifier.shutdown();
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
          break;
        case 'enable':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          scheduler.enable(dataStoreRO);
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
        case 'playSound':
          // the map value is either a File or a path to file
          dynamic fileOrPath = map.values.first;
          scheduler.notifier.audioPlayer.play(fileOrPath);
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
    if (!result) {
      IsolateNameServer.removePortNameMapping(
          constants.toSchedulerSendPortName);
      result = IsolateNameServer.registerPortWithName(
        fromAppIsolateReceivePort.sendPort,
        constants.toSchedulerSendPortName,
      );
    }
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
    notifier.showInfoNotification('${constants.appName} is enabled' +
        '\n\nNext notification at ${formatHHMM(delegate.queryNext())}');
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
          scheduler, quietHours, _ds.randomMinMinutes, _ds.randomMaxMinutes);
    }
    return delegate;
  }

  void triggerNotification() {
    if (!running) {
      logger.i("triggerNotification: not running");
      return;
    }
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    bool isQuiet = delegate.quietHours.inQuietHours;
    bool isQuietChecked = delegate.quietHours.isInQuietHours(now);
    logger.i(
        "triggerNotification quiet=$isQuiet, quietChecked=$isQuietChecked ${getCurrentIsolate()}");

    try {
      if (isQuiet) {
        if (!isQuietChecked) {
          logger.i("In quiet hours... ignoring notification");
          setInfoMessage("In quiet hours ${formatHHMM(now)}");
          return;
        } else {
          logger.e(
              "Checked quiet hours disagrees with value. Cancelling quiet hours");
          setInfoMessage("Cancelling quiet hours ${formatHHMM(now)}");
          delegate.quietHours.inQuietHours = false;
        }
      }
      if (isQuietChecked) {
        // Note: this could happen if enabled in quiet hours:
        logger.i("In quiet hours (missed alarm)... ignoring notification");
        setInfoMessage("In quiet hours ${formatHHMM(now)} NA");
        return;
      }
      var reminder = _reminders.randomReminder();
      notifier.showReminderNotification(reminder);
      setMessage(reminder);
    } finally {
      delegate.scheduleNext();
    }
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

  DateTime queryNext();

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

  @override
  DateTime queryNext() {
    return getInitialStart();
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
    Scheduler.setInfoMessage(
        "Notifications scheduled every $durationHours:${timeNumToString(durationMinutes)}," +
            " beginning: $firstNotifDate");
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
  final int _minMinutes;
  final int _maxMinutes;
  DateTime _nextDate;
  static const bool rescheduleAfterQuietHours = false;

  RandomScheduler(Scheduler scheduler, QuietHours quietHours, this._minMinutes,
      this._maxMinutes)
      : super(ScheduleType.RANDOM, scheduler, quietHours);

  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
    scheduled = true;
  }

  @override
  DateTime queryNext() {
    return _nextDate;
  }

  void scheduleNext() async {
    super.scheduleNext();
    int nextMinutes;
    if ((_maxMinutes == _minMinutes) || (_minMinutes > _maxMinutes)) {
      nextMinutes = _maxMinutes;
    } else {
      nextMinutes = _minMinutes + Random().nextInt(_maxMinutes - _minMinutes);
    }
    if (nextMinutes <= 1) {
      nextMinutes = 2;
    }
    _nextDate = DateTime.now().add(Duration(minutes: nextMinutes));
    if (rescheduleAfterQuietHours &&
        (quietHours.inQuietHours || quietHours.isInQuietHours(_nextDate))) {
      _nextDate =
          quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
      logger.i("Scheduling next reminder, past quiet hours: $_nextDate");
      Scheduler.setInfoMessage(
          "In quiet hours, next reminder at ${formatHHMMSS(_nextDate)}");
    } else {
      logger.i("Scheduling next reminder at $_nextDate");
      Scheduler.setInfoMessage("Next reminder at ${formatHHMMSS(_nextDate)}");
    }
    await AndroidAlarmManager.oneShotAt(
        _nextDate, Scheduler.scheduleAlarmID, Scheduler.scheduleCallback,
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
  static const int quietHoursStartAlarmID = 5521;
  static const int quietHoursEndAlarmID = 5522;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  bool inQuietHours = false;

  QuietHours(this.startTime, this.endTime);
  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));

  DateTime _convertTimeOfDayToToday(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    return DateTime(
        current.year, current.month, current.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToTomorrow(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    final tomorrow = current.add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToYesterday(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    final yesterday = current.subtract(Duration(days: 1));
    return DateTime(
        yesterday.year, yesterday.month, yesterday.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart({DateTime current}) {
    current ??= DateTime.now();
    DateTime quietStart = _convertTimeOfDayToToday(startTime, current: current);
    if (quietStart.isBefore(current)) {
      quietStart = _convertTimeOfDayToTomorrow(startTime, current: current);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd({DateTime current}) {
    current ??= DateTime.now();
    DateTime quietEnd = _convertTimeOfDayToToday(endTime, current: current);
    // if (quietEnd.isAtSameMomentAs(now) || quietEnd.isBefore(now)) {
    if (quietEnd.isBefore(current)) {
      quietEnd = _convertTimeOfDayToTomorrow(endTime, current: current);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime givenDate) {
    /*
         yesterday ???   today     ???     tomorrow  ???
        ---------------------------------------------------------------
              now1              now2                now3 (same as now1)
               V                 V                   V
        ----------------|---------------------|-------------
                    quiet start            quiet end
                  (past or future)      (ALWAYS IN THE FUTURE)

      Quiet end is always in the future.
      Quiet start may be in the past (only when in quiet hours) or future.
      Therefore, we can start from the end and work our way back.
    */
    // Note: 'today' and 'tomorrow' are all relative to the date we're given.
    DateTime todayEnd = _convertTimeOfDayToToday(endTime, current: givenDate);
    DateTime tomorrowEnd =
        _convertTimeOfDayToTomorrow(endTime, current: givenDate);
    DateTime todayStart =
        _convertTimeOfDayToToday(startTime, current: givenDate);

    // Is quiet end today or tomorrow? It is always in the future.
    DateTime end;
    if (givenDate.isBefore(todayEnd)) {
      end = todayEnd;
    } else {
      end = tomorrowEnd;
    }
    assert(givenDate.isBefore(end)); // always in the future

    // Now we can base quiet start on what we know to be the end
    // Adjust today's start if necessary (for instance, if it is just after midnight)
    if (todayStart.add(Duration(days: 1)).isBefore(end)) {
      todayStart = todayStart.add(Duration(days: 1));
    }

    if (todayStart.isAfter(end)) {
      // Today's start is after today's end, but we haven't reached
      // today's end yet (see above end calculation), which must mean that:
      // 1) quiet hours started _yesterday_, and
      // 2) we must be in quiet hours, since we haven't reached today's end yet.
      DateTime yesterdayStart =
          _convertTimeOfDayToYesterday(startTime, current: givenDate);
      assert(givenDate.isAfter(yesterdayStart));
      assert(givenDate.isBefore(end));
      assert(givenDate.isBefore(todayStart));
      return true;
    }

    // Now we know that we are before 'end' (which is either today or
    // tomorrow - we don't care, because it is somewhere in the future).
    // So, if we are before today's start then we're before quiet hours;
    // otherwise we are in quiet hours.
    if (givenDate.isBefore(todayStart)) {
      return false;
    }
    return true;
  }

  void initializeTimers() async {
    if (isInQuietHours(DateTime.now())) {
      quietStart();
    }
    var nextQuietStart = getNextQuietStart();
    var nextQuietEnd = getNextQuietEnd();
    await AndroidAlarmManager.cancel(quietHoursStartAlarmID);
    await AndroidAlarmManager.cancel(quietHoursEndAlarmID);
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
    logger.i("Quiet hours start");
    inQuietHours = true;
    Scheduler.setMessage('In quiet hours');
    Scheduler().notifier.showQuietHoursNotification(true);
  }

  void quietEnd() {
    logger.i("Quiet hours end");
    inQuietHours = false;
    Scheduler.setMessage('Quiet Hours have ended.');
    Scheduler().notifier.showQuietHoursNotification(false);
  }
}
