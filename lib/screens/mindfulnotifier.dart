import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/screens/about.dart';

var logger = createLogger('mindfulnotifier');

const String appName = 'Mindful Notifier';

class MindfulNotifierWidgetController extends GetxController {
  static SendPort toAlarmServiceSendPort;
  // A port used to communicate from the app isolate to the alarm_manager isolate.
  static StreamSubscription fromAlarmServiceStreamSubscription;
  static ReceivePort fromAlarmServiceReceivePort;

  final String title = appName;
  final _reminderMessage = 'Not Running'.obs;
  final _infoMessage = 'Not Running'.obs;
  final _enabled = false.obs;
  final _mute = false.obs;
  final _vibrate = false.obs;
  final controlMessage = ''.obs;
  final showControlMessages = false.obs;
  ScheduleDataStore ds;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  @override
  void onInit() {
    init();
    // initializeFromBackgroundService();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    ever(_enabled, handleEnabled);
    ever(_mute, handleMute);
    ever(_vibrate, handleVibrate);
    ever(_reminderMessage, handleReminderMessage);
    ever(_infoMessage, handleInfoMessage);
    ever(controlMessage, handleControlMessage);
    triggerSchedulerSync();
  }

  @override
  void onClose() {
    shutdownReceivePort();
    super.onClose();
  }

  void init() async {
    logger.i("mindfulnotifier:init() ${getCurrentIsolate()}");
    ds = await ScheduleDataStore.getInstance();
    ds.dumpToLog();
    initializeFromAlarmServiceReceivePort();
    _enabled.value = ds.enabled;
    _mute.value = ds.mute;
    _vibrate.value = ds.vibrate;
    _reminderMessage.value = ds.reminderMessage;
    _infoMessage.value = ds.infoMessage;
    controlMessage.value = ds.controlMessage;
    showControlMessages.value = ds.includeDebugInfo;
    initializeNotifications();
  }

  void triggerSchedulerSync() async {
    sendToAlarmService({'sync': 1});
  }

  void initializeFromAlarmServiceReceivePort() {
    logger.i("initializeFromAlarmServiceReceivePort ${getCurrentIsolate()}");

    if (fromAlarmServiceReceivePort == null) {
      logger.d("new fromAlarmServiceReceivePort");
      fromAlarmServiceReceivePort = ReceivePort();
    }
    // Register for events from the alarm isolate. These messages will
    // always coincide with an alarm firing.
    fromAlarmServiceStreamSubscription =
        fromAlarmServiceReceivePort.listen((map) {
      //
      // WE ARE IN THE APP ISOLATE
      //
      logger.i(
          "fromAlarmServiceReceivePort received: $map ${getCurrentIsolate()}");

      String key = map.keys.first;
      dynamic value = map.values.first;
      switch (key) {
        case 'reminderMessage':
          _reminderMessage.value = value;
          break;
        case 'infoMessage':
          _infoMessage.value = value;
          break;
        case 'controlMessage':
          logger.i("Received control message: $value");
          controlMessage.value = value;
          break;
        case 'syncResponse':
          logger.i("Received sync response : $value");
          if (value.containsKey('reminderMessage')) {
            ds.reminderMessage = value['reminderMessage'];
            _reminderMessage.value = value['reminderMessage'];
          }
          if (value.containsKey('infoMessage')) {
            ds.infoMessage = value['infoMessage'];
            _infoMessage.value = value['infoMessage'];
          }
          if (value.containsKey('controlMessage')) {
            ds.controlMessage = value['controlMessage'];
            controlMessage.value = value['controlMessage'];
          }
          break;
        default:
          logger.e("Unexpected key: $key");
          break;
      }
    }, onDone: () {
      logger.w("fromAlarmServiceReceivePort is closed");
    });

    // Register our SendPort for the Scheduler to be able to send to our ReceivePort
    IsolateNameServer.removePortNameMapping(constants.toAppSendPortName);
    bool result = IsolateNameServer.registerPortWithName(
      fromAlarmServiceReceivePort.sendPort,
      constants.toAppSendPortName,
    );
    logger.d(
        "registerPortWithName: ${constants.toAppSendPortName}, result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void triggerSchedulerShutdown() {
    // Send to the alarm isolate
    sendToAlarmService({'shutdown': '1'});
  }

  void triggerSchedulerRestart() {
    if (_enabled.value) {
      logger.i("sending restart to scheduler");
      // Send to the alarm isolate
      sendToAlarmService({'restart': ds.getScheduleDataStoreRO()});
      // alert user
      Get.snackbar(
          "Restarting", "Configuration changed, restarting the notifier.",
          snackPosition: SnackPosition.BOTTOM, instantInit: false);
    }
  }

  void shutdownReceivePort() async {
    logger.i("shutdownReceivePort");
    fromAlarmServiceReceivePort.close();
    await fromAlarmServiceStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(constants.toAppSendPortName);
  }

  void handleReminderMessage(msg) {
    ds.reminderMessage = msg;
  }

  void handleInfoMessage(msg) {
    ds.infoMessage = msg;
  }

  void handleControlMessage(msg) {
    ds.controlMessage = msg;
    // Get.snackbar("Control Message", "Received control message: $msg");
  }

  void sendToAlarmService(Map<String, dynamic> msg) {
    logger.d("sendToAlarmService: $msg");
    toAlarmServiceSendPort ??= IsolateNameServer.lookupPortByName(
        constants.toAlarmServiceSendPortName);
    toAlarmServiceSendPort?.send(msg);
  }

  void handleEnabled(enabled) {
    ds.enabled = enabled;
    if (enabled) {
      if (_reminderMessage.value == 'Not Enabled' ||
          _reminderMessage.value == 'In quiet hours') {
        _reminderMessage.value = 'Enabled. Waiting for notification...';
      }
      _infoMessage.value = 'Enabled. Waiting for notification.';
      sendToAlarmService({'enable': ds.getScheduleDataStoreRO()});
    } else {
      // setMessage('Disabled');
      _infoMessage.value = 'Disabled';
      sendToAlarmService({'disable': ds.getScheduleDataStoreRO()});
    }
  }

  void handleMute(bool mute) {
    ds.mute = mute;
    forceSchedulerUpdate();
  }

  void handleVibrate(bool vibrate) {
    ds.vibrate = vibrate;
    forceSchedulerUpdate();
  }

  void forceSchedulerUpdate() {
    if (_enabled.value) {
      logger.i("Forcing scheduler update");
      sendToAlarmService({'update': ds.getScheduleDataStoreRO()});
    }
  }

  void setNextNotification(DateTime dateTime) {
    _infoMessage.value = "Next notification at ${formatHHMMSS(dateTime)}";
  }

  void handleScheduleOnTap() {
    Get.toNamed('/schedules');
  }

  void handleRemindersOnTap() {
    Get.toNamed('/reminders');
  }

  void handleBellOnTap() {
    Get.toNamed('/bell');
  }

  void handleGeneralOnTap() {
    Get.toNamed('/general');
  }
}

class MindfulNotifierWidget extends StatelessWidget {
  final MindfulNotifierWidgetController controller =
      Get.put(MindfulNotifierWidgetController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.title),
      ),
      body: Center(
        child: Column(
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              flex: 12,
              child: Obx(() =>
                  /*Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                      ),
                      color: Theme.of(context).cardColor,
                      margin: EdgeInsets.only(
                          top: 15, left: 15, right: 15, bottom: 0),
                      elevation: 5,
                      child: */
                  Container(
                    margin: EdgeInsets.only(
                        top: 30, left: 30, right: 30, bottom: 30),
                    alignment: Alignment.center,
                    // decoration: BoxDecoration(color: Colors.grey[100]),
                    child: Text(
                      '${controller._reminderMessage}',
                      // style: Theme.of(context).textTheme.headline4,
                      // style: Theme.of(context).textTheme.headline5,
                      style: TextStyle(
                          color: Get.isDarkMode
                              ? Colors.grey[400]
                              : Colors.grey[800],
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Open Sans',
                          fontSize: 30),
                      // textAlign: TextAlign.left,
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  )),
            ),
            Expanded(
              flex: 3,
              child: Obx(() => Card(
                  // shape: RoundedRectangleBorder(
                  //   borderRadius: BorderRadius.circular(15.0),
                  // ),
                  color: Theme.of(context).cardColor,
                  margin:
                      EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 15),
                  elevation: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                              controller._enabled.value ? 'Enabled' : 'Enable'),
                          Switch(
                            value: controller._enabled.value,
                            onChanged: (newvalue) =>
                                controller._enabled.value = newvalue,
                          ),
                        ],
                      ),
                      ToggleButtons(
                        isSelected: [
                          controller._mute.value,
                          controller._vibrate.value
                        ],
                        onPressed: (index) {
                          switch (index) {
                            case 0:
                              controller._mute.value = !controller._mute.value;
                              break;
                            case 1:
                              controller._vibrate.value =
                                  !controller._vibrate.value;
                              break;
                          }
                        },
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child:
                                Text(controller._mute.value ? 'Muted' : 'Mute'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('Vibrate'),
                          ),
                        ],
                      ),
                    ],
                  ))),
            ),
            Expanded(
                flex: 1,
                child: Obx(
                  () => Text(
                    controller.controlMessage.value != '' &&
                            controller.showControlMessages.value
                        ? '${controller._infoMessage.value} [${controller.controlMessage.value}]'
                        : '${controller._infoMessage.value}',
                    style: TextStyle(
                        color:
                            Get.isDarkMode ? Colors.grey[400] : Colors.black38),
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).appBarTheme.color,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  // color: Colors.white,
                  fontSize: 24,
                  // color: Theme.of(context).,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text('Schedule'),
              subtitle: Text('Configure reminder frequency'),
              onTap: controller.handleScheduleOnTap,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.list),
              title: Text('Reminders'),
              subtitle: Text('Configure reminder contents'),
              onTap: controller.handleRemindersOnTap,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Bell'),
              subtitle: Text('Configure bell'),
              onTap: controller.handleBellOnTap,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Preferences'),
              subtitle: Text('Configure application settings: theme, etc.'),
              onTap: controller.handleGeneralOnTap,
            ),
            Divider(),
            AppAboutListTile(),
          ],
        ),
      ),
      /* ) */
    );
  }
}
