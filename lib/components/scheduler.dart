import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info/package_info.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/quiethours.dart';
import 'package:mindfulnotifier/components/reminders.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('scheduler');

String getCurrentIsolate() {
  return "I:${Isolate.current.hashCode}";
}

enum ScheduleType { PERIODIC, RANDOM }

const bool useHeartbeat = true;
const Duration heartbeatInterval = Duration(minutes: 30);
const bool rescheduleOnReboot = useHeartbeat;
const bool rescheduleAfterQuietHours = true;
const int controlAlarmId = 5;
bool androidAlarmManagerInitialized = false;

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
Future<void> initializeScheduler() async {
  // check IsolateNameServer to see if our alarm isolate is already running
  if (IsolateNameServer.lookupPortByName(constants.toSchedulerSendPortName) !=
      null) {
    logger.i(
        "initializeScheduler: already initialized: ${constants.toSchedulerSendPortName} ${getCurrentIsolate()}");
    return;
  }
  // !!!
  // THIS IS ON THE 'MAIN' ISOLATE
  // Nothing else in this file should be on the main isolate.
  // !!!
  logger.i("initializeScheduler ${getCurrentIsolate()}");

  await initializeAlarmManager();

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

Future<void> initializeAlarmManager() async {
  if (!androidAlarmManagerInitialized) {
    try {
      logger.i("Initializing AndroidAlarmManager ${getCurrentIsolate()}");
      await AndroidAlarmManager.initialize();
      androidAlarmManagerInitialized = true;
    } catch (e) {
      logger.e('initializeAlarmManager failed',
          'AndroidAlarmManager.initialize() failed', e);
    }
  }
}

void controlCallback() async {
  logger.i("controlCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  // This is only available in the alarm manager isolate
  // Create and initialize the Scheduler singleton
  Scheduler scheduler = Scheduler();
  // Note: this call may end up reinitializing everything if our app has been killed:
  bool wasInit = await scheduler.checkInitialized(kickSchedule: true);
  scheduler.sendControlMessage(
      "${useHeartbeat ? 'HB' : 'CO'}:${formatHHMM(DateTime.now())}:${wasInit ? 'T' : 'F'}");
}

void scheduleCallback() async {
  logger.i("[${DateTime.now()}] scheduleCallback  ${getCurrentIsolate()}");
  Scheduler scheduler = Scheduler();
  // Note: this call may end up reinitializing everything if our app has been killed:
  await scheduler.checkInitialized(kickSchedule: false);
  scheduler.triggerNotification();
}

/// The main class for scheduling notifications
class Scheduler {
  static const int scheduleAlarmID = 10;

  bool running = false;
  bool initialized = false;

  Map<String, String> _lastUiMessage = {};
  ScheduleDataStoreRO _ds;
  Reminders _reminders;
  bool alarmManagerInitialized = false;
  Notifier notifier;
  DelegatedScheduler delegate;
  StreamSubscription fromAppIsolateStreamSubscription;
  ReceivePort fromAppIsolateReceivePort;

  // Singleton
  static Scheduler _instance;
  Scheduler._internal() {
    _instance = this;
  }
  factory Scheduler() => _instance ?? Scheduler._internal();

  Future<void> init([bool kickSchedule = true]) async {
    logger.i("Initializing scheduler, initialized=$initialized " +
        "kickSchedule=$kickSchedule ${getCurrentIsolate()}");

    await initializeAlarmManager();

    PackageInfo info = await PackageInfo.fromPlatform();
    Get.put(info, permanent: true);

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    AndroidBuildVersion buildVersion = androidInfo.version;
    Get.put(buildVersion, permanent: true);

    try {
      _initializeFromAppIsolateReceivePort();
    } catch (e) {
      logger.e("_initializeFromAppIsolateReceivePort failed with: $e", null, e);
    }

    notifier = Notifier();
    await notifier.start();

    _reminders = await Reminders.create();

    // this is the only time we read from SharedPreferences (to avoid race conditions I was hitting)
    if (_ds == null) {
      _update(dataStoreRO: await findScheduleDataStoreRO(false));
    }

    initialized = true;

    if (_ds.enabled) {
      logger.i("Re-enabling on init");
      _enable(kickSchedule: kickSchedule);
    }
  }

  void _shutdown() {
    logger.i("shutdown");
    _disable();
    _shutdownReceivePort();
    notifier.shutdown();
    initialized = false;
  }

  void _initializeFromAppIsolateReceivePort() async {
    logger.i("_initializeFromAppIsolateReceivePort ${getCurrentIsolate()}");

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
      switch (key) {
        case 'update':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          _update(dataStoreRO: dataStoreRO);
          break;
        case 'enable':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          _enable(kickSchedule: true, dataStoreRO: dataStoreRO);
          break;
        case 'disable':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          _update(dataStoreRO: dataStoreRO);
          _disable();
          break;
        case 'restart':
          ScheduleDataStoreRO dataStoreRO = map.values.first;
          _restart(dataStoreRO);
          break;
        case 'sync':
          _handleSync();
          break;
        case 'shutdown':
          _shutdown();
          break;
        case 'playSound':
          // the map value is either a File or a path to file
          dynamic fileOrPath = map.values.first;
          notifier.audioPlayer.play(fileOrPath);
          break;
      }
    }, onDone: () {
      logger.w("fromAppIsolateReceivePort is closed ${getCurrentIsolate()}");
    });
    // if (IsolateNameServer.lookupPortByName(constants.toSchedulerSendPortName) !=
    //     null) {
    IsolateNameServer.removePortNameMapping(constants.toSchedulerSendPortName);
    // }
    // Register our SendPort for the app to be able to send to our ReceivePort
    bool result = IsolateNameServer.registerPortWithName(
      fromAppIsolateReceivePort.sendPort,
      constants.toSchedulerSendPortName,
    );
    // if (!result) {
    //   IsolateNameServer.removePortNameMapping(
    //       constants.toSchedulerSendPortName);
    //   result = IsolateNameServer.registerPortWithName(
    //     fromAppIsolateReceivePort.sendPort,
    //     constants.toSchedulerSendPortName,
    //   );
    // }
    logger.d(
        "registerPortWithName: ${constants.toSchedulerSendPortName}, result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void _shutdownReceivePort() async {
    logger.i("_shutdownReceivePort");
    fromAppIsolateReceivePort.close();
    await fromAppIsolateStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(constants.toSchedulerSendPortName);
  }

  void _update({ScheduleDataStoreRO dataStoreRO}) {
    logger.d("_update, datastoreRO=$dataStoreRO");
    Get.delete<ScheduleDataStoreRO>(force: true);
    _ds = Get.put(dataStoreRO, permanent: true);
  }

  void _enable({bool kickSchedule = true, ScheduleDataStoreRO dataStoreRO}) {
    logger.i("_enable, kickSchedule=$kickSchedule");
    if (dataStoreRO != null) {
      _update(dataStoreRO: dataStoreRO);
    }
    if (running) {
      _disable();
    }
    _enableHeartbeat();
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
      notifier.showInfoNotification('${constants.appName} is enabled' +
          '\n\nNext reminder at ${formatHHMM(delegate.queryNext())}');
    }
  }

  void _disable() async {
    logger.i("_disable");
    delegate?.cancel();
    notifier.cancelAll();
    _disableHeartbeat();
    running = false;
  }

  void _restart(ScheduleDataStoreRO store) {
    _disable();
    sleep(Duration(seconds: 1));
    _enable(kickSchedule: true, dataStoreRO: store);
  }

  void _handleSync() async {
    Map<String, String> map = Map.from(_lastUiMessage);
    logger.d("_handleSync: $map");
    _sendValueToUI('syncResponse', map);
  }

  void _enableHeartbeat() async {
    // Heartbeat is a last-ditch alarm triggered at a regular interval.
    //  This is just in case we miss the scheduler alarm on a reboot.
    if (useHeartbeat) {
      await AndroidAlarmManager.cancel(controlAlarmId);
      logger.i("Enabling heartbeat");
      if (!await AndroidAlarmManager.periodic(
          heartbeatInterval, controlAlarmId, controlCallback,
          exact: true, wakeup: true, rescheduleOnReboot: true)) {
        var errmsg =
            "Scheduling periodic control alarm failed on timer id: $controlAlarmId";
        logger.e(errmsg);
        throw AssertionError(errmsg);
      }
    }
  }

  void _disableHeartbeat() async {
    if (useHeartbeat) {
      logger.i("Cancelling heartbeat");
      await AndroidAlarmManager.cancel(controlAlarmId);
    }
  }

  void initialScheduleComplete() {
    running = true;
  }

  void _sendValueToUI(String tag, dynamic value) async {
    try {
      // look this up every time, in case the UI goes away:
      var toAppSendPort =
          IsolateNameServer.lookupPortByName(constants.toAppSendPortName);
      toAppSendPort?.send({tag: value});
    } catch (e) {
      logger.w('Failed to send to UI', 'send failed', e);
    }
  }

  void sendReminderMessage(String msg) async {
    _lastUiMessage['reminderMessage'] = msg;
    _sendValueToUI('reminderMessage', msg);
  }

  void sendInfoMessage(String msg) async {
    _lastUiMessage['infoMessage'] = msg;
    _sendValueToUI('infoMessage', msg);
  }

  void sendControlMessage(String msg) async {
    _lastUiMessage['controlMessage'] = msg;
    _sendValueToUI('controlMessage', msg);
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
    bool isQuiet = delegate.quietHours.inQuietHours;
    bool isQuietCheckedVal = delegate.quietHours.isInQuietHours(now);
    logger.i(
        "triggerNotification quiet=$isQuiet, quietChecked=$isQuietCheckedVal ${getCurrentIsolate()}");

    try {
      if (isQuiet) {
        if (!isQuietCheckedVal) {
          logger.i("In quiet hours... ignoring notification");
          sendInfoMessage("In quiet hours ${formatHHMM(now)}");
          return;
        } else {
          logger.e(
              "Checked quiet hours disagrees with value. Cancelling quiet hours");
          sendInfoMessage("Cancelling quiet hours ${formatHHMM(now)}");
          delegate.quietHours.inQuietHours = false;
        }
      }
      if (isQuietCheckedVal) {
        // Note: this could happen if enabled in quiet hours:
        logger.i("In quiet hours (missed alarm)... ignoring notification");
        sendInfoMessage("In quiet hours ${formatHHMM(now)} NA");
        return;
      }
      var reminder = _reminders.randomReminder();
      notifier.showReminderNotification(reminder);
      sendReminderMessage(reminder);
    } finally {
      delegate.scheduleNext();
    }
  }

  Future<bool> checkInitialized({bool kickSchedule = false}) async {
    if (!initialized) {
      logger.w('checkInitialized: Scheduler is not initialized');
      await init(kickSchedule);
      return false; // was not initialized
    }
    return true;
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
    await AndroidAlarmManager.cancel(Scheduler.scheduleAlarmID);
  }

  DateTime queryNext() {
    return _nextDate;
  }

  DateTime getNextFireTime({DateTime fromTime, bool adjustFromQuiet});

  void scheduleNext() async {
    logger.d(
        "Scheduling next notification, type=$scheduleType ${getCurrentIsolate()}");

    _nextDate = getNextFireTime();

    if (rescheduleAfterQuietHours &&
        (quietHours.inQuietHours || quietHours.isInQuietHours(_nextDate))) {
      _nextDate = getNextFireTime(
          fromTime: quietHours.getNextQuietEnd(), adjustFromQuiet: true);
      logger.i("Scheduling next reminder, past quiet hours: $_nextDate");
      scheduler.sendInfoMessage(
          "In quiet hours, next reminder at ${formatHHMMSS(_nextDate)}");
    } else {
      logger.i("Scheduling next reminder at $_nextDate");
      scheduler.sendInfoMessage("Next reminder at ${formatHHMMSS(_nextDate)}");
    }

    await AndroidAlarmManager.oneShotAt(
        _nextDate, Scheduler.scheduleAlarmID, scheduleCallback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: rescheduleOnReboot);

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
