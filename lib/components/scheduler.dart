import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info/package_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindfulnotifier/components/alarmservice.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/quiethours.dart';
import 'package:mindfulnotifier/components/timerservice.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('scheduler');

enum ScheduleType { PERIODIC, RANDOM }

const bool rescheduleAfterQuietHours = true;
const int scheduleAlarmID = 10;
bool initialNotificationTriggered = false;

/// Newest changes:
/// scheduler owns the data
/// is reinitialized upon every alarm
/// reschedules next alarm upon every alarm
/// always refreshes from the datastore
///  - no need to reinitialize when UI changes config

// Design notes:
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

  ScheduleDataStore _ds;
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

    PackageInfo info = await PackageInfo.fromPlatform();
    Get.put(info, permanent: true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    Get.delete<SharedPreferences>();
    Get.put(prefs, permanent: true);

    _ds = await ScheduleDataStore.getInstance();
    Get.delete<ScheduleDataStore>();
    Get.put(_ds, permanent: true);

    delegate = _buildSchedulerDelegate(this);
  }

  void shutdown() {
    logger.i("shutdown");
    disable();
    Notifier().shutdown();
  }

  void update(InMemoryScheduleDataStore mds) {
    logger.d("update, InMemoryScheduleDataStore=$mds");
    _ds.merge(mds);
  }

  void updateDS(String key, var value) async {
    logger.d("updateDS");
    await ScheduleDataStore.setSync(key, value);
  }

  void enable({bool kickSchedule = true}) {
    logger.i("enable");
    _ds.enabled = true;

    delegate = _buildSchedulerDelegate(this);
    delegate.quietHours.initializeTimers();

    // This is the notification we only want to show on:
    // 1) reboot
    // 2) first enabled by user
    // 3) re-enable after config changes by user
    if (kickSchedule) {
      delegate.scheduleNext();
      // sendInfoMessage(
      //     'Next reminder at ${formatHHMM(delegate.queryNext())}');
      Notifier().showInfoNotification('${constants.appName} is enabled' +
          '\n\nNext reminder at ${formatHHMM(delegate.queryNext())}');
    }
    sendDataStoreUpdate();
  }

  // bool enableIfNecessary() {
  //   if (_ds.enabled) {
  //     if (initialNotificationTriggered) {
  //       logger.i("initialNotificationTriggered: not re-enabling on init");
  //     } else {
  //       logger.i("re-enabling on init");
  //       enable(kickSchedule: true);
  //     }
  //     return true;
  //   }
  //   return false;
  // }

  void disable() async {
    logger.i("disable");
    delegate?.cancel();
    Notifier().shutdown();
    _ds.enabled = false;
    running = false;
    sendDataStoreUpdate();
  }

  void restart() {
    logger.i("restart");
    disable();
    sleep(Duration(seconds: 1));
    enable(kickSchedule: true);
  }

  void playSound(var fileOrPath) {
    Notifier().playSound(fileOrPath);
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
    // _lastUiMessage['reminderMessage'] = msg;
    _ds.reminderMessage = msg;
    sendValueToUI('reminderMessage', msg);
  }

  void sendInfoMessage(String msg) async {
    // _lastUiMessage['infoMessage'] = msg;
    _ds.infoMessage = msg;
    sendValueToUI('infoMessage', msg);
  }

  void sendControlMessage(String msg) async {
    // _lastUiMessage['controlMessage'] = msg;
    sendValueToUI('controlMessage', msg);
  }

  void sendDataStoreUpdate() async {
    sendValueToUI(
        'syncDataStore', await ScheduleDataStore.getInMemoryInstance());
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
            hour: _ds.quietHoursEndHour, minute: _ds.quietHoursEndMinute),
        _ds.notifyQuietHours);
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
        logger.i("In quiet hours (missed alarm)... ignoring notification");
        sendInfoMessage("In quiet hours ${formatHHMM(now)} NA");
        return;
      }
      String reminder = _ds.randomReminder();
      Notifier().showReminderNotification(reminder);
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

  void scheduleNext() async {
    logger.d(
        "Scheduling next notification, type=$scheduleType ${getCurrentIsolate()}");

    _nextDate = getNextFireTime();

    if (rescheduleAfterQuietHours && quietHours.isInQuietHours(_nextDate)) {
      _nextDate = getNextFireTime(
          fromTime: quietHours.getNextQuietEnd(), adjustFromQuiet: true);
      logger.i("Scheduling next reminder, past quiet hours: $_nextDate");
      scheduler.sendInfoMessage(
          "In quiet hours, next reminder at ${formatHHMMSS(_nextDate)}");
    } else {
      logger.i("Scheduling next reminder at $_nextDate");
      scheduler.sendInfoMessage("Next reminder at ${formatHHMMSS(_nextDate)}");
    }

    TimerService timerService = await getAlarmManagerTimerService();
    timerService.oneShotAt(_nextDate, scheduleAlarmID, scheduleCallback);

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

  PeriodicScheduler(Scheduler scheduler, QuietHours quietHours,
      this.durationHours, this.durationMinutes)
      : super(ScheduleType.PERIODIC, scheduler, quietHours);

  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet}) {
    fromTime ??= DateTime.now();
    // int periodInMins = 60 * durationHours + durationMinutes;
    DateTime nextDate;
    switch (durationMinutes) {
      case 0:
        // case 45:
        // schedule next for top of the next hour
        DateTime startTimeRaw = fromTime.add(Duration(hours: 1));
        nextDate = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        break;
      case 30:
        // schedule next for either top or bottom the hour (< 30m)
        DateTime startTimeRaw = fromTime.add(Duration(minutes: 30));
        if (startTimeRaw.minute < 30) {
          // we can schedule it for the top of the next hour
          nextDate = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        } else {
          // schedule it for the bottom of the next
          nextDate = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 30, 0, 0, 0);
        }
        break;
      case 15:
        // schedule next for < 15m
        DateTime startTimeRaw = fromTime.add(Duration(minutes: 15));
        int newMinute = fromTime.minute + 15;
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
        nextDate = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, newHour, newMinute, 0, 0, 0);
        break;
    }
    return nextDate;
  }
}

class RandomScheduler extends DelegatedScheduler {
  final int _minMinutes;
  final int _maxMinutes;

  RandomScheduler(Scheduler scheduler, QuietHours quietHours, this._minMinutes,
      this._maxMinutes)
      : super(ScheduleType.RANDOM, scheduler, quietHours);

  void initialScheduleComplete() {
    scheduler.initialScheduleComplete();
    scheduled = true;
  }

  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet}) {
    fromTime ??= DateTime.now();
    adjustFromQuiet ??= false;
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
