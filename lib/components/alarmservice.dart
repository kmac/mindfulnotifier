import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/scheduler.dart';
import 'package:mindfulnotifier/components/timerservice.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('alarmservice');

const bool useHeartbeat = false;
const Duration heartbeatInterval = Duration(minutes: 30);
const int controlAlarmId = 5;

bool alarmServiceAlreadyRunning = false;

ReceivePort fromAppIsolateReceivePort;
StreamSubscription fromAppIsolateStreamSubscription;

Future<bool> initializeAlarmService({bool bootstrap: false}) async {
  // check IsolateNameServer to see if our alarm isolate is already running
  if (IsolateNameServer.lookupPortByName(
          constants.toAlarmServiceSendPortName) !=
      null) {
    logger.d("initializeAlarmService bootstrap:$bootstrap, "
        "already initialized: ${constants.toAlarmServiceSendPortName} "
        "${getCurrentIsolate()}");
    alarmServiceAlreadyRunning = true;
    return alarmServiceAlreadyRunning;
  }

  // We can't query android alarm manager to see if we have outstanding alarms.
  // We store the next alarm time in hive db and compare with current time to
  // see if we should have an alarm scheduled

  try {
    logger.i("initializeAlarmService initializing alarm manager, "
        "bootstrap:$bootstrap ${getCurrentIsolate()}");
    logger.i("Initializing AndroidAlarmManager ${getCurrentIsolate()}");
    bool initResult = await AndroidAlarmManager.initialize();
    if (!initResult) {
      logger.e('AndroidAlarmManager.initialize() failed');
    }
    logger.i(
        "Successfully initialized AndroidAlarmManager ${getCurrentIsolate()}");
  } catch (e) {
    logger.e('initializeAlarmManager failed',
        'AndroidAlarmManager.initialize() failed', e);
  }

  if (bootstrap) {
    // !!!
    // CALLER IS ON THE 'MAIN' ISOLATE
    // Nothing else in this file should be running on the main isolate.
    // !!!

    // Send ourselves a bootstrap message. The 'bootstrapCallback' will be
    // invoked on the alarm manager isolate.
    if (!await AndroidAlarmManager.oneShot(
        Duration(seconds: 1), controlAlarmId, bootstrapCallback,
        exact: true, wakeup: true, rescheduleOnReboot: false)) {
      var errmsg =
          "Scheduling oneShot control alarm failed on timer id: $controlAlarmId";
      logger.e(errmsg);
      throw AssertionError(errmsg);
    }
  }
  return alarmServiceAlreadyRunning;
}

Future<void> initializeFromAppIsolateReceivePort() async {
  logger.i("initializeFromAppIsolateReceivePort ${getCurrentIsolate()}");

  fromAppIsolateReceivePort = ReceivePort();

  // Register for events from the UI isolate. These messages will
  // be triggered from the UI side
  fromAppIsolateStreamSubscription =
      fromAppIsolateReceivePort.listen(handleAppMessage, onDone: () {
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
  logger.d("registerPortWithName: ${constants.toAlarmServiceSendPortName}, "
      "result=$result ${getCurrentIsolate()}");
  assert(result);
}

void handleAppMessage(dynamic map) async {
    //
    // WE ARE IN THE ALARM ISOLATE
    //
    logger.i("fromAppIsolateReceivePort received: $map ${getCurrentIsolate()}");
    String key = map.keys.first;
    // String value = map.values.first;
    Scheduler scheduler = await Scheduler.getScheduler();
    switch (key) {
      case 'update':
        InMemoryScheduleDataStore mds = map.values.first;
        scheduler.update(mds);
        break;
      case 'enable':
        String infoMessage = map.values.first;
        scheduler.updateDS('infoMessage', infoMessage, sendUpdate: false);
        enable();
        break;
      case 'disable':
        String infoMessage = map.values.first;
        scheduler.updateDS('infoMessage', infoMessage, sendUpdate: false);
        disable();
        break;
      case 'restart':
        InMemoryScheduleDataStore mds = map.values.first;
        if (mds != null) {
          scheduler.update(mds);
        }
        scheduler.restart();
        break;
      case 'restore':
        InMemoryScheduleDataStore mds = map.values.first;
        scheduler.update(mds);
        scheduler.updateDS('infoMessage', "Restored", sendUpdate: true);
        break;
      case 'syncDataStore':
        scheduler.sendDataStoreUpdate();
        break;
      case 'mute':
        bool mute = map.values.first;
        scheduler.updateDS('mute', mute);
        break;
      case 'vibrate':
        bool vibrate = map.values.first;
        scheduler.updateDS('vibrate', vibrate);
        break;
      case 'shutdown':
        shutdown();
        break;
      case 'playSound':
        // the map value is either a File or a path to file
        dynamic fileOrPath = map.values.first;
        scheduler.playSound(fileOrPath);
        break;
      default:
        logger.e("Unknown key: $key");
        break;
    }
}

void shutdownReceivePort() async {
  logger.i("shutdownReceivePort");
  fromAppIsolateReceivePort.close();
  await fromAppIsolateStreamSubscription.cancel();
  IsolateNameServer.removePortNameMapping(constants.toAlarmServiceSendPortName);
}

void bootstrapCallback() async {
  logger.i("bootstrapCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  // This is only available in the alarm manager isolate

  getAlarmManagerTimerService();

  try {
    await initializeFromAppIsolateReceivePort();
  } catch (e) {
    logger.e("initializeFromAppIsolateReceivePort failed with: $e", null, e);
  }

  // Create and initialize the Scheduler singleton
  Scheduler scheduler = await Scheduler.getScheduler();
  // this shouldn't be needed since we should have the alarm scheduled:
  // bool enabled = scheduler.enableIfNecessary();
  // scheduler.sendControlMessage(
  //     "${useHeartbeat ? 'HB' : 'CO'}:${formatHHMM(DateTime.now())}:${enabled ? 'T' : 'F'}");
  scheduler.sendControlMessage(
      "${useHeartbeat ? 'HB' : 'CO'}:${formatHHMM(DateTime.now())}:"
      "${scheduler.running ? 'T' : 'F'}");
}

void heartbeatCallback() async {
  logger.i("heartbeatCallback ${getCurrentIsolate()}");
  // WE ARE IN THE ALARM MANAGER ISOLATE
  getAlarmManagerTimerService();

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

void enable() async {
  logger.i("enable");
  Scheduler scheduler = await Scheduler.getScheduler();
  scheduler.enable();
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

/// This is only available in the alarm manager isolate
Future<AlarmManagerTimerService> getAlarmManagerTimerService() async {
  if (!alarmServiceAlreadyRunning) {
    await initializeAlarmService();
  }
  return AlarmManagerTimerService();
}

class AlarmManagerTimerService extends TimerService {
  Future<void> oneShotAt(DateTime time, int id, Function callback,
      {bool rescheduleOnReboot = true}) async {
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
