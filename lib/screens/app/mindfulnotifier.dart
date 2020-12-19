import 'dart:async';
import 'dart:ui';
import 'dart:isolate';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'package:mindfulnotifier/components/backgroundservice.dart' as bg;
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = Logger(printer: SimpleLogPrinter('mindfulnotifier'));

const String appName = 'Mindful Notifier';

const bool testing = false;

String getCurrentIsolate() {
  return "I:${Isolate.current.hashCode}";
}

class MindfulNotifierWidgetController extends GetxController {
  static const String toAppSendPortName = 'toAppIsolate';
  static const String toSchedulerSendPortName = 'toSchedulerIsolate';
  static SendPort toSchedulerSendPort;
  // A port used to communicate from the app isolate to the alarm_manager isolate.
  static StreamSubscription fromSchedulerStreamSubscription;
  static ReceivePort fromSchedulerReceivePort;

  final String title = appName;
  final _message = 'Not Running'.obs;
  final _infoMessage = 'Not Running'.obs;
  final _controlMessage = ''.obs;
  final _enabled = false.obs;
  final _mute = false.obs;
  final _vibrate = false.obs;
  ScheduleDataStore ds;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  @override
  void onInit() {
    ever(_enabled, handleEnabled);
    ever(_mute, handleMute);
    ever(_vibrate, handleVibrate);
    ever(_message, handleMessage);
    ever(_infoMessage, handleInfoMessage);
    ever(_controlMessage, handleControlMessage);
    init();
    initializeFromBackgroundService();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    // if (constants.useForegroundService) {
    //   Future.delayed(Duration(seconds: 10), initializeFromBackgroundService);
    // }
  }

  @override
  void onClose() {
    shutdownReceivePort();
    super.onClose();
  }

  void init() async {
    ds = await ScheduleDataStore.getInstance();
    initializeFromSchedulerReceivePort();
    _enabled.value = ds.enabled;
    _mute.value = ds.mute;
    _vibrate.value = ds.vibrate;
    _message.value = ds.message;
    _infoMessage.value = ds.infoMessage;
    _controlMessage.value = ds.controlMessage;
    initializeNotifications();
  }

  void initializeFromSchedulerReceivePort() {
    logger.i("initializeFromSchedulerReceivePort ${getCurrentIsolate()}");

    if (fromSchedulerReceivePort == null) {
      logger.d("new fromSchedulerReceivePort");
      fromSchedulerReceivePort = ReceivePort();
    }
    // Register for events from the alarm isolate. These messages will
    // always coincide with an alarm firing.
    fromSchedulerStreamSubscription = fromSchedulerReceivePort.listen((map) {
      //
      // WE ARE IN THE APP ISOLATE
      //
      logger
          .i("fromSchedulerReceivePort received: $map ${getCurrentIsolate()}");

      String key = map.keys.first;
      String value = map.values.first;
      switch (key) {
        case 'message':
          _message.value = value;
          break;
        case 'infoMessage':
          _infoMessage.value = value;
          break;
        case 'controlMessage':
          logger.i("Received control message: $value");
          _controlMessage.value = value;
          break;
        default:
          logger.e("Unexpected key: $key");
          break;
      }
    }, onDone: () {
      logger.w("fromSchedulerReceivePort is closed");
    });

    // Register our SendPort for the Scheduler to be able to send to our ReceivePort
    IsolateNameServer.removePortNameMapping(toAppSendPortName);
    bool result = IsolateNameServer.registerPortWithName(
      fromSchedulerReceivePort.sendPort,
      toAppSendPortName,
    );
    logger.d(
        "registerPortWithName: $toAppSendPortName, result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void initializeFromBackgroundService() {
    bg.getServiceInstance().onDataReceived.listen((event) {
      String key = event.keys.first;
      String value = event.values.first;
      switch (key) {
        case 'current_date':
          logger.i("Received current_date=$value from background service");
          break;
      }
    }, onDone: () {
      logger.w("background service is closed");
    });
  }

  void triggerSchedulerShutdown() {
    // Send to the alarm isolate
    toSchedulerSendPort ??=
        IsolateNameServer.lookupPortByName(toSchedulerSendPortName);
    toSchedulerSendPort?.send({'shutdown': '1'});
  }

  void triggerSchedulerRestart() {
    if (_enabled.value) {
      logger.i("sending restart to scheduler");
      // Send to the alarm isolate
      toSchedulerSendPort ??=
          IsolateNameServer.lookupPortByName(toSchedulerSendPortName);
      toSchedulerSendPort?.send({'restart': ds.getScheduleDataStoreRO()});
      // alert user
      Get.snackbar(
          "Restarting", "Configuration changed, restarting the notifier.",
          snackPosition: SnackPosition.BOTTOM, instantInit: false);
    }
  }

  void shutdownReceivePort() async {
    logger.i("shutdownReceivePort");
    fromSchedulerReceivePort.close();
    await fromSchedulerStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(toAppSendPortName);
  }

  void handleMessage(msg) {
    ds.message = msg;
  }

  void handleInfoMessage(msg) {
    ds.infoMessage = msg;
  }

  void handleControlMessage(msg) {
    ds.controlMessage = msg;
    // Get.snackbar("Control Message", "Received control message: $msg");
  }

  void _sendToScheduler(var msg) {
    logger.d("_sendToScheduler: $msg");
    toSchedulerSendPort ??=
        IsolateNameServer.lookupPortByName(toSchedulerSendPortName);
    toSchedulerSendPort?.send(msg);
  }

  void handleEnabled(enabled) {
    ds.enabled = enabled;
    if (enabled) {
      // if (_message.value == 'Disabled') {
      //   setMessage('Enabled. Waiting for notification...');
      // }
      // setInfoMessage('Enabled');
      if (_message.value == 'Not Enabled' ||
          _message.value == 'In quiet hours') {
        _message.value = 'Enabled. Waiting for notification...';
      }
      _infoMessage.value = 'Enabled. Waiting for notification.';
      _sendToScheduler({'enable': ds.getScheduleDataStoreRO()});
    } else {
      // setMessage('Disabled');
      _infoMessage.value = 'Disabled';
      _sendToScheduler({'disable': '1'});
    }
  }

  void handleMute(bool mute) {
    ds.mute = mute;
    _sendToScheduler({'update': ds.getScheduleDataStoreRO()});
  }

  void handleVibrate(bool vibrate) {
    ds.vibrate = vibrate;
    _sendToScheduler({'update': ds.getScheduleDataStoreRO()});
  }

  // Future<void> _handlePermissions() async {
  //   // TODO change this to take the user to the settings in UI
  //   Map<Permission, PermissionStatus> statuses = await [
  //     // Permission.ignoreBatteryOptimizations,
  //     Permission.notification,
  //   ].request();
  //   print(statuses[Permission.location]);
  // }

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

  void handleAdvancedOnTap() {
    Get.toNamed('/advanced');
  }
}

class MindfulNotifierWidget extends StatelessWidget {
  final MindfulNotifierWidgetController controller =
      Get.put(MindfulNotifierWidgetController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    // TODO PROBABLY DON'T NEED THIS - the UI CAN SHUT DOWN NOW! ??????
    return WillPopScope(
        onWillPop: () => showDialog<bool>(
            context: context,
            builder: (ctxt) => AlertDialog(
                  title: Text('Warning'),
                  content: Text(
                    "If you use the back button here the app will exit, " +
                        "and you won't receive any further notifications. Do you really want to exit?",
                    softWrap: true,
                  ),
                  actions: [
                    FlatButton(
                      child: Text('Yes'),
                      onPressed: () {
                        controller.triggerSchedulerShutdown();
                        sleep(Duration(seconds: 2));
                        controller.shutdownReceivePort();
                        Navigator.pop(ctxt, true);
                      },
                    ),
                    FlatButton(
                      child: Text('No'),
                      onPressed: () => Navigator.pop(ctxt, false),
                    ),
                  ],
                )),
        // Widget tree
        child: Scaffold(
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
                          '${controller._message}',
                          // style: Theme.of(context).textTheme.headline4,
                          // style: Theme.of(context).textTheme.headline5,
                          style: TextStyle(
                              // color: Colors.grey[800],
                              // color: isDark(context)
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
                      )) /*)*/,
                ),
                Expanded(
                  flex: 3,
                  child: Obx(() => Card(
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(15.0),
                      // ),
                      color: Theme.of(context).cardColor,
                      margin: EdgeInsets.only(
                          top: 15, left: 15, right: 15, bottom: 15),
                      elevation: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text(controller._enabled.value
                                  ? 'Enabled'
                                  : 'Enable'),
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
                                  controller._mute.value =
                                      !controller._mute.value;
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
                                child: Text(
                                    controller._mute.value ? 'Muted' : 'Mute'),
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
                        controller._controlMessage.value == ''
                            ? '${controller._infoMessage.value}'
                            : '${controller._infoMessage.value} [${controller._controlMessage.value}]',
                        style: TextStyle(
                            color: Get.isDarkMode
                                ? Colors.grey[400]
                                : Colors.black38),
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
                    //color: Colors.blue,
                    color: Theme.of(context).appBarTheme.color,
                    // style: Theme.of(context).textTheme.headline5,
                  ),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      // color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.schedule),
                  title: Text('Schedule'),
                  subtitle: Text('Configure reminder frequency'),
                  onTap: controller.handleScheduleOnTap,
                ),
                ListTile(
                  leading: Icon(Icons.list),
                  title: Text('Reminders'),
                  subtitle: Text('Configure reminder contents'),
                  onTap: controller.handleRemindersOnTap,
                ),
                ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Bell'),
                  subtitle: Text('Configure bell'),
                  onTap: controller.handleBellOnTap,
                ),
                ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Advanced'),
                  onTap: controller.handleAdvancedOnTap,
                ),
              ],
            ),
          ),
        ));
  }
}
