import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:date_format/date_format.dart';
import 'package:mindfulnotifier/components/logging.dart';
// import 'package:mindfulnotifier/components/schedule.dart' as schedule;

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
    init();
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    shutdownReceivePort();
    super.onClose();
  }

  void init() async {
    ds = await ScheduleDataStore.getInstance();
    initializeFromSchedulerReceivePort();
    _enabled.value = ds.getEnable();
    _mute.value = ds.getMute();
    _vibrate.value = ds.getVibrate();
    _message.value = ds.getMessage();
    _infoMessage.value = ds.getInfoMessage();
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
        default:
          logger.e("Unexpected key: $key");
          break;
      }
    }, onDone: () {
      logger.w("fromSchedulerReceivePort is closed");
    });

    // Register our SendPort for the Scheduler to be able to send to our ReceivePort
    bool result = IsolateNameServer.registerPortWithName(
      fromSchedulerReceivePort.sendPort,
      toAppSendPortName,
    );
    logger.d(
        "registerPortWithName: $toAppSendPortName, result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void triggerSchedulerShutdown() {
    // Send to the alarm isolate
    toSchedulerSendPort ??=
        IsolateNameServer.lookupPortByName(toAppSendPortName);
    toSchedulerSendPort?.send({'shutdown': '1'});
  }

  void shutdownReceivePort() async {
    logger.i("shutdownReceivePort");
    fromSchedulerReceivePort.close();
    await fromSchedulerStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(toAppSendPortName);
  }

  void setMessage(msg) {
    _message.value = msg;
    ds.setMessage(_message.value);
  }

  void setInfoMessage(msg) {
    _infoMessage.value = msg;
    ds.setInfoMessage(_infoMessage.value);
  }

  handleEnabled(enabled) {
    ds.setEnable(enabled);
    if (enabled) {
      if (_message.value == 'Disabled') {
        setMessage('Enabled. Waiting for notification...');
      }
      setInfoMessage('Enabled');

      toSchedulerSendPort ??=
          IsolateNameServer.lookupPortByName(toSchedulerSendPortName);
      toSchedulerSendPort?.send({'enable': '1'});
    } else {
      setMessage('Disabled');
      setInfoMessage('Disabled');
      toSchedulerSendPort ??=
          IsolateNameServer.lookupPortByName(toSchedulerSendPortName);
      toSchedulerSendPort?.send({'disable': '1'});
    }
    // // Send to the alarm_manager isolate
    // appCallbackSendPort ??=
    //     IsolateNameServer.lookupPortByName(sendToAppPortName);
    // appCallbackSendPort?.send({'enable': enabled ? 'true' : 'false'});
  }

  void handleMute(bool mute) {
    ds.setMute(mute);
  }

  void handleVibrate(bool vibrate) {
    ds.setVibrate(vibrate);
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
    var timestr =
        formatDate(dateTime, [hh, ':', nn, ':', ss, " ", am]).toString();
    setInfoMessage("Next notification at $timestr");
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
                  flex: 15,
                  child: Obx(() => Card(
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(15.0),
                      // ),
                      color: Theme.of(context).cardColor,
                      margin: EdgeInsets.only(
                          top: 15, left: 15, right: 15, bottom: 0),
                      elevation: 3,
                      child: Container(
                        margin: EdgeInsets.only(
                            top: 30, left: 30, right: 30, bottom: 30),
                        alignment: Alignment.center,
                        // decoration: BoxDecoration(color: Colors.grey[100]),
                        child: Text(
                          '${controller._message}',
                          style: Theme.of(context).textTheme.headline4,
                          // style: Theme.of(context).textTheme.headline5,
                          textAlign: TextAlign.left,
                          softWrap: true,
                        ),
                      ))),
                ),
                Expanded(
                  flex: 4,
                  child: Obx(() => Card(
                      // shape: RoundedRectangleBorder(
                      //   borderRadius: BorderRadius.circular(15.0),
                      // ),
                      color: Theme.of(context).cardColor,
                      margin: EdgeInsets.only(
                          top: 5, left: 15, right: 15, bottom: 15),
                      elevation: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Switch(
                                value: controller._enabled.value,
                                onChanged: (newvalue) =>
                                    controller._enabled.value = newvalue,
                              ),
                              Text(controller._enabled.value
                                  ? 'Enabled'
                                  : 'Enable'),
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
                        '${controller._infoMessage.value}',
                        style: TextStyle(color: Colors.black38),
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
                      color: Colors.white,
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
