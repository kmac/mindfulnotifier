import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/scheduler.dart';
import 'package:mindfulnotifier/components/timerservice.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('alarmservice');

/// This service could actually be abstracted into the timerservice
/// - i.e. the listen port stuff

const bool useHeartbeat = true;
const Duration heartbeatInterval = Duration(minutes: 30);
const bool rescheduleOnReboot = useHeartbeat;
const int controlAlarmId = 5;

bool androidAlarmManagerInitialized = false;

ReceivePort fromAppIsolateReceivePort;
StreamSubscription fromAppIsolateStreamSubscription;

Future<void> initializeAlarmService() async {
  // check IsolateNameServer to see if our alarm isolate is already running
  if (IsolateNameServer.lookupPortByName(
          constants.toAlarmServiceSendPortName) !=
      null) {
    logger.i(
        "initializeAlarmService: already initialized: ${constants.toAlarmServiceSendPortName} ${getCurrentIsolate()}");
    return;
  }
  // !!!
  // THIS IS ON THE 'MAIN' ISOLATE
  // Nothing else in this file should be on the main isolate.
  // !!!
  logger.i("initialize ${getCurrentIsolate()}");

  await initializeAlarmManager();

  // Send ourselves a bootstrap message. The 'bootstrapCallback' will be
  // invoked on the alarm manager isolate
  if (!await AndroidAlarmManager.oneShot(
      Duration(seconds: 1), controlAlarmId, bootstrapCallback,
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
      bool initResult = await AndroidAlarmManager.initialize();
      if (!initResult) {
        logger.e('AndroidAlarmManager.initialize() failed');
      }
      androidAlarmManagerInitialized = true;
    } catch (e) {
      logger.e('initializeAlarmManager failed',
          'AndroidAlarmManager.initialize() failed', e);
    }
  }
}

Future<void> initializeFromAppIsolateReceivePort() async {
  logger.i("initializeFromAppIsolateReceivePort ${getCurrentIsolate()}");

  fromAppIsolateReceivePort = ReceivePort();

  // Register for events from the UI isolate. These messages will
  // be triggered from the UI side
  fromAppIsolateStreamSubscription =
      fromAppIsolateReceivePort.listen((map) async {
    //
    // WE ARE IN THE ALARM ISOLATE
    //
    logger.i("fromAppIsolateReceivePort received: $map ${getCurrentIsolate()}");
    String key = map.keys.first;
    // String value = map.values.first;
    Scheduler scheduler = await Scheduler.getScheduler();
    switch (key) {
      case 'update':
        ScheduleDataStoreRO dataStoreRO = map.values.first;
        scheduler.update(dataStoreRO: dataStoreRO);
        break;
      case 'enable':
        ScheduleDataStoreRO dataStoreRO = map.values.first;
        enable(kickSchedule: true, dataStoreRO: dataStoreRO);
        break;
      case 'disable':
        ScheduleDataStoreRO dataStoreRO = map.values.first;
        scheduler.update(dataStoreRO: dataStoreRO);
        disable();
        break;
      case 'restart':
        ScheduleDataStoreRO dataStoreRO = map.values.first;
        scheduler.restart(dataStoreRO);
        break;
      case 'sync':
        scheduler.handleSync();
        break;
      case 'shutdown':
        shutdown();
        break;
      case 'playSound':
        // the map value is either a File or a path to file
        dynamic fileOrPath = map.values.first;
        scheduler.playSound(fileOrPath);
        break;
    }
  }, onDone: () {
    logger.w("fromAppIsolateReceivePort is closed ${getCurrentIsolate()}");
  });

  // Register our SendPort for the app to be able to send to our ReceivePort
  IsolateNameServer.removePortNameMapping(constants.toAlarmServiceSendPortName);
  bool result = IsolateNameServer.registerPortWithName(
    fromAppIsolateReceivePort.sendPort,
    constants.toAlarmServiceSendPortName,
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
      "registerPortWithName: ${constants.toAlarmServiceSendPortName}, result=$result ${getCurrentIsolate()}");
  assert(result);
}

void shutdownReceivePort() async {
  logger.i("shutdownReceivePort");
  fromAppIsolateReceivePort.close();
  await fromAppIsolateStreamSubscription.cancel();
  IsolateNameServer.removePortNameMapping(constants.toAlarmServiceSendPortName);
}

void initializeGet() {
  Get.delete<TimerService>();
  TimerService timerService = AlarmManagerTimerService();
  Get.put<TimerService>(timerService, permanent: true);
}

void bootstrapCallback() async {
  logger.i("bootstrapCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  // This is only available in the alarm manager isolate

  initializeGet();

  try {
    await initializeFromAppIsolateReceivePort();
  } catch (e) {
    logger.e("initializeFromAppIsolateReceivePort failed with: $e", null, e);
  }

  // Create and initialize the Scheduler singleton
  Scheduler scheduler = await Scheduler.getScheduler();
  bool enabled = scheduler.enableIfNecessary();
  scheduler.sendControlMessage(
      "${useHeartbeat ? 'HB' : 'CO'}:${formatHHMM(DateTime.now())}:${enabled ? 'T' : 'F'}");
}

void heartbeatCallback() async {
  logger.i("heartbeatCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  // This is only available in the alarm manager isolate

  initializeGet();

  // Create and initialize the Scheduler singleton
  Scheduler scheduler = await Scheduler.getScheduler();
  scheduler.sendControlMessage(
      "${useHeartbeat ? 'HB' : 'CO'}:${formatHHMM(DateTime.now())}");
}

void enableHeartbeat() async {
  // Heartbeat is a last-ditch alarm triggered at a regular interval.
  //  This is just in case we miss the scheduler alarm on a reboot.
  if (useHeartbeat) {
    await AndroidAlarmManager.cancel(controlAlarmId);
    logger.i("Enabling heartbeat");
    if (!await AndroidAlarmManager.periodic(
        Duration(minutes: 30), controlAlarmId, heartbeatCallback,
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

void enable({bool kickSchedule = true, ScheduleDataStoreRO dataStoreRO}) async {
  logger.i("enable");
  Scheduler scheduler = await Scheduler.getScheduler();
  scheduler.enable(kickSchedule: kickSchedule, dataStoreRO: dataStoreRO);
  enableHeartbeat();
}

void disable() async {
  logger.i("disable");
  Scheduler scheduler = await Scheduler.getScheduler();
  scheduler.disable();
  disableHeartbeat();
}

void shutdown() {
  logger.i("shutdown");
  disable();
  shutdownReceivePort();
}

class AlarmManagerTimerService extends TimerService {
  Future<void> oneShotAt(DateTime time, int id, Function callback) async {
    await AndroidAlarmManager.oneShotAt(time, id, callback,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: rescheduleOnReboot);
  }

  Future<void> cancel(int id) async {
    await AndroidAlarmManager.cancel(id);
  }
}
