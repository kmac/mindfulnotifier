// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

import 'package:mindfulnotifier/components/alarmservice.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/quiethours.dart';
import 'package:mindfulnotifier/components/timerservice.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('scheduler');

enum ScheduleType { periodic, random }

const bool rescheduleAfterQuietHours = true;
const int scheduleAlarmID = 10;

// Design notes:
/// - scheduler owns the data
///   - is reinitialized upon every alarm
/// - reschedules next alarm upon every alarm
/// - always refreshes from the datastore
///   - no need to reinitialize when UI changes config

// - the UI only makes config changes and enable/disable
// - everything else is controlled by the scheduler

/// The Scheduler instance is only accessible via the alarm callback isolate.
/// It reads all data from shared preferences.
/// It creates the next alarm from that data on the fly.
/// - complete decoupling of the alarm/notification from the UI
/// - all data is shared via shared prefs
/// Alarms for:
/// - raising a notification
/// - quiet hours start/end (maybe end not required - just reschedule past next)
/// We also put the notification info in shared prefs and always read from that
/// on the UI side.

void scheduleCallback() async {
  logger.i("[${DateTime.now()}] scheduleCallback  ${getCurrentIsolate()}");
  Scheduler scheduler = await Scheduler.getScheduler();
  // await scheduler.checkInitialized();

  // change here is to just re-initialize the scheduler every time and just schedule next
  scheduler.triggerNotification();
}

/// The main class for scheduling notifications
class Scheduler {
  bool running = false;
  // bool initialized = false;

  ScheduleDataStore ds;
  bool alarmManagerInitialized = false;
  DelegatedScheduler delegate;
  ReceivePort fromAppIsolateReceivePort;

  // Singleton
  static Scheduler _instance;

  static Future<Scheduler> getScheduler() async {
    if (_instance == null) {
      _instance = Scheduler();
      await _instance.init();
    }
    return _instance;
  }

  Future<void> init() async {
    logger.i("Initializing scheduler ${getCurrentIsolate()}");

    // TEMPORARY: fix eof SharedPreferences and PathProvider
    // https://github.com/flutter/flutter/issues/99155#issuecomment-1052023743:
    // This will be replaced with 'DartPluginRegistrant.ensureInitialized()'
    SharedPreferencesAndroid.registerWith();
    PathProviderAndroid.registerWith();
    try {
      PackageInfo info = await PackageInfo.fromPlatform();
      Get.put(info);
    } catch (e) {
      // throws during testing
    }

    ds ??= await ScheduleDataStore.getInstance();
    Get.delete<ScheduleDataStore>();
    Get.put(ds, permanent: true);

    delegate = _buildSchedulerDelegate(this);
  }

  void shutdown() {
    logger.i("shutdown");
    disable();
    Notifier().shutdown();
  }

  void update(InMemoryScheduleDataStore mds) {
    logger.d("update, InMemoryScheduleDataStore=$mds");
    ds.mergeIntoPermanentDS(mds);
  }

  void updateDS(String key, var value, {bool sendUpdate = true}) async {
    logger.d("updateDS");
    await ds.setSync(key, value);
    if (sendUpdate) {
      await sendDataStoreUpdate();
    }
  }

  Future<void> enable({bool restart = false}) async {
    logger.i("enable");
    ds.enabled = true;

    delegate = _buildSchedulerDelegate(this);
    delegate.quietHours.initializeTimers();

    // This is the notification we only want to show on:
    // 1) reboot
    // 2) first enabled by user
    // 3) app is restarted after GUI is killed or exited
    // 4) re-enable after config changes by user
    delegate.scheduleNext(restart: restart);
    if (ds.reminderMessage == constants.reminderMessageDisabled ||
        ds.reminderMessage == constants.reminderMessageQuietHours ||
        ds.reminderMessage == constants.reminderMessageWaiting) {
      ds.reminderMessage = ds.randomReminder();
    }
    if (!await Notifier().isNotificationActive()) {
      Notifier().showInfoNotification(ds.reminderMessage);
    }
    await sendDataStoreUpdate();
  }

  Future<void> disable({bool sendUpdate = true, bool restart = false}) async {
    logger.i("disable");
    delegate?.cancel();
    running = false;
    ds.enabled = false;
    if (!restart) {
      Notifier().shutdown();
      ds.reminderMessage = ScheduleDataStoreBase.defaultReminderMessage;
      ds.nextAlarm = '';
    }
    if (sendUpdate) {
      await sendDataStoreUpdate();
    }
  }

  Future<void> restart() async {
    logger.i("restart");
    await disable(sendUpdate: false, restart: true);
    sleep(Duration(milliseconds: 250));
    await enable(restart: true);
  }

  void playSound(var fileOrPath) {
    Notifier().playSound(fileOrPath, ds);
  }

  void initialScheduleComplete() {
    running = true;
  }

  static void sendValueToUI(String tag, dynamic value) async {
    try {
      // look this up every time, in case the UI goes away:
      var toAppSendPort =
          IsolateNameServer.lookupPortByName(constants.toAppSendPortName);
      toAppSendPort?.send({tag: value});
    } catch (e) {
      logger.w('Failed to send to UI', 'send failed', e.stackTrace);
    }
  }

  void sendReminderMessage(String msg) async {
    ds.reminderMessage = msg;
    sendValueToUI('reminderMessage', msg);
  }

  void sendInfoMessage(String msg) async {
    ds.infoMessage = msg;
    sendValueToUI('infoMessage', msg);
  }

  void sendControlMessage(String msg) async {
    sendValueToUI('controlMessage', msg);
  }

  Future<void> sendDataStoreUpdate() async {
    ds ??= await ScheduleDataStore.getInstance();
    sendValueToUI('syncDataStore', ds.getInMemoryInstance());
  }

  DelegatedScheduler _buildSchedulerDelegate(Scheduler scheduler) {
    logger.i('Building scheduler delegate: ${ds.scheduleTypeStr}');
    ScheduleType scheduleType;
    if (ds.scheduleTypeStr == 'periodic') {
      scheduleType = ScheduleType.periodic;
    } else {
      scheduleType = ScheduleType.random;
    }
    QuietHours quietHours = QuietHours(
        TimeOfDay(
            hour: ds.quietHoursStartHour, minute: ds.quietHoursStartMinute),
        TimeOfDay(hour: ds.quietHoursEndHour, minute: ds.quietHoursEndMinute),
        ds.notifyQuietHours);
    DelegatedScheduler delegate;
    if (scheduleType == ScheduleType.periodic) {
      delegate = PeriodicScheduler(
          scheduler, quietHours, ds.periodicHours, ds.periodicMinutes);
    } else {
      delegate = RandomScheduler(
          scheduler, quietHours, ds.randomMinMinutes, ds.randomMaxMinutes);
    }
    return delegate;
  }

  void triggerNotification() {
    // if (!running)  {
    //   logger.i("triggerNotification: not running");
    //   return;
    // }

    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    bool isQuiet = delegate.quietHours.isInQuietHours(now);
    logger.i("triggerNotification isQuiet=$isQuiet ${getCurrentIsolate()}");

    try {
      if (isQuiet) {
        // Note: this could happen if enabled in quiet hours:
        logger.i(
            "${constants.reminderMessageQuietHours} (missed alarm)... ignoring notification");
        sendInfoMessage(
            "${constants.reminderMessageQuietHours} ${formatHHMM(now)} NA");
        return;
      }
      String reminder = ds.randomReminder();
      Notifier().showReminderNotification(reminder, ds.mute, ds.vibrate);
      sendReminderMessage(reminder);
    } finally {
      delegate.scheduleNext();
    }
  }
}

abstract class DelegatedScheduler {
  final ScheduleType scheduleType;
  final Scheduler scheduler;
  final QuietHours quietHours;
  bool scheduled = false;
  DateTime _nextDate;

  DelegatedScheduler(this.scheduleType, this.scheduler, this.quietHours);

  void cancel() async {
    logger.i("Cancelling notification schedule ${getCurrentIsolate()}");
    quietHours.cancelTimers();
    TimerService timerService = await getAlarmManagerTimerService();
    await timerService.cancel(scheduleAlarmID);
  }

  DateTime queryNext() {
    return _nextDate;
  }

  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet});

  void scheduleNext({bool restart = false}) async {
    logger.d(
        "Scheduling next notification, type=$scheduleType ${getCurrentIsolate()}");

    _nextDate = null;
    if (restart) {
      // use nextAlarm if possible; otherwise it gets left null
      String nextAlarmStr = scheduler.ds.nextAlarm;
      if (nextAlarmStr != null && nextAlarmStr != '') {
        DateTime nextAlarm = DateTime.parse(scheduler.ds.nextAlarm);
        if (nextAlarm.isAfter(DateTime.now().add(Duration(seconds: 10)))) {
          logger.i("Re-scheduling based on nextAlarm $nextAlarmStr");
          _nextDate = nextAlarm;
        }
      }
    }
    _nextDate ??= getNextFireTime();

    if (rescheduleAfterQuietHours && quietHours.isInQuietHours(_nextDate)) {
      _nextDate = getNextFireTime(
          fromTime: quietHours.getNextQuietEnd(), adjustFromQuiet: true);
      logger.i("Scheduling next reminder, past quiet hours: $_nextDate");
      scheduler.sendInfoMessage(
          "${constants.reminderMessageQuietHours}, next reminder at ${formatHHMMSS(_nextDate)}");
    } else {
      logger.i("Scheduling next reminder at $_nextDate");
      scheduler.sendInfoMessage("Next reminder at ${formatHHMMSS(_nextDate)}");
    }

    TimerService timerService = await getAlarmManagerTimerService();
    timerService.oneShotAt(_nextDate, scheduleAlarmID, scheduleCallback);
    scheduler.updateDS(
        ScheduleDataStoreBase.nextAlarmKey, _nextDate.toIso8601String(),
        sendUpdate: true);

    if (!scheduled) {
      initialScheduleComplete();
    }
  }

  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
  }
}

class PeriodicScheduler extends DelegatedScheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  // Add some padding for alarm scheduling. This is to ensure we will schedule into the future
  static Duration alarmPadding = Duration(minutes: 2);

  PeriodicScheduler(Scheduler scheduler, QuietHours quietHours,
      this.durationHours, this.durationMinutes)
      : super(ScheduleType.periodic, scheduler, quietHours);

  DateTime getNextFireTimeOrig(
      {DateTime fromTime, bool adjustFromQuiet = false}) {
    fromTime ??= DateTime.now();

    // Algorithm:
    // - add hours and minutes.
    // - align to either top of hour, 30m or 15m block

    // The raw next fire time. This then needs to be aligned to either the top of the hour, 30, or 15m
    DateTime nextDateRaw =
        fromTime.add(Duration(hours: durationHours, minutes: durationMinutes));
    if (!adjustFromQuiet) {
      // Add some padding for alarm scheduling. This is to ensure we will schedule into the future:
      nextDateRaw = nextDateRaw.add(alarmPadding);
    }

    DateTime nextDate;
    switch (durationMinutes) {
      case 0:
        // Interval is in 'hours' only (1, 2, 3, ...)
        // Truncate everything past the hour
        nextDate = DateTime(nextDateRaw.year, nextDateRaw.month,
            nextDateRaw.day, nextDateRaw.hour, 0, 0, 0, 0);
        break;
      case 30:
        // Interval is one of: 0h30m, 1h30m, 2h30m, ...
        // Schedule next for either top or bottom the hour (< 30m)
        if (nextDateRaw.minute < 30) {
          // Truncate to top of the hour
          nextDate = DateTime(nextDateRaw.year, nextDateRaw.month,
              nextDateRaw.day, nextDateRaw.hour, 0, 0, 0, 0);
        } else {
          // Truncate to bottom of the hour
          nextDate = DateTime(nextDateRaw.year, nextDateRaw.month,
              nextDateRaw.day, nextDateRaw.hour, 30, 0, 0, 0);
        }
        break;
      case 15:
        int newHour = nextDateRaw.hour;
        int newMinute = nextDateRaw.minute;
        if (newMinute < 15) {
          newMinute = 0;
        } else if (newMinute < 30) {
          newMinute = 15;
        } else if (newMinute < 45) {
          newMinute = 30;
        } else if (newMinute < 60) {
          newMinute = 45;
        } else {
          // should never hit this:
          logger.e("Unexpected value newMinute=$newMinute");
          newMinute = 0;
        }
        nextDate = DateTime(nextDateRaw.year, nextDateRaw.month,
            nextDateRaw.day, newHour, newMinute, 0, 0, 0);
        break;
    }
    return nextDate;
  }

  @override
  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet = false}) {
    fromTime ??= DateTime.now();
    if (!adjustFromQuiet) {
      // Add some padding for alarm scheduling.
      // This is to ensure we will schedule into the future:
      fromTime = fromTime.add(alarmPadding);
    }

    // Algorithm:
    // - add hours and minutes.
    // - align to next interval
    // Number of msec from now = intervalMsecs - (nextDateRawEpochMsec MOD intervalMsecs)

    // nextFireTimeMsec = (timenowMsec + intervalMsec) MOD intervalMsec
    // nextFireTimeMsec = timenowMsec+intervalMsec + timenowMsec ~/ intervalMsec - (timenowMsec % intervalMsec)

    //       now           interval             now+interval
    //        |  ----------------------------->  |
    //                                  |
    // -----------------------------------------------------------------------
    //                              alignment
    //
    /* 
    How to calculate 'alignment'?
    - subract out the hours component
    - how many 'interval minutes' fit in an hour?
        - is it even?  then align to top of hour
        - if it doesn't fit evenly, then just pick next interval (don't align)
    */

    // Add interval hours:
    DateTime nextDateRaw = fromTime.add(Duration(hours: durationHours));

    // Add interval minutes:
    Duration intervalMins = Duration(minutes: durationMinutes);
    nextDateRaw = nextDateRaw.add(intervalMins);

    // Now bring it back to the start of the interval:
    Duration minutesOver = Duration(
        milliseconds:
            nextDateRaw.millisecondsSinceEpoch % intervalMins.inMilliseconds);
    DateTime nextDate = nextDateRaw.subtract(minutesOver);

    // Now truncate to the minute:
    nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day,
        nextDate.hour, nextDate.minute, 0, 0, 0);

    return nextDate;
  }
}

class RandomScheduler extends DelegatedScheduler {
  final int _minMinutes;
  final int _maxMinutes;

  RandomScheduler(Scheduler scheduler, QuietHours quietHours, this._minMinutes,
      this._maxMinutes)
      : super(ScheduleType.random, scheduler, quietHours);

  @override
  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
    scheduled = true;
  }

  @override
  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet = false}) {
    fromTime ??= DateTime.now();
    int nextMinutes;
    if ((_maxMinutes == _minMinutes) || (_minMinutes > _maxMinutes)) {
      if (adjustFromQuiet) {
        // For after quiet hours: pick a random time from max
        nextMinutes = Random().nextInt(_maxMinutes);
      } else {
        nextMinutes = _maxMinutes;
      }
    } else {
      if (adjustFromQuiet) {
        // For after quiet hours: pick a random time
        nextMinutes = Random().nextInt(_maxMinutes - _minMinutes);
      } else {
        nextMinutes = _minMinutes + Random().nextInt(_maxMinutes - _minMinutes);
      }
    }
    if (nextMinutes <= 1) {
      nextMinutes = 2;
    }
    return fromTime.add(Duration(minutes: nextMinutes));
  }
}
