import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/schedule.dart';
import 'package:date_format/date_format.dart';

const String appName = 'Mindful Notifier';
const bool testing = false;

// class MindfulNotifierApp extends StatefulWidget {
//   MindfulNotifierApp({Key key}) : super(key: key);
//
//   @override
//   MindfulNotifierWidgetController createState() =>
//       MindfulNotifierWidgetController();
// }

class MindfulNotifierWidgetController extends GetxController {
  final String title = appName;
  final message = 'Not Running'.obs;
  final infoMessage = 'Not Running'.obs;
  final _enabled = false.obs;
  final _mute = false.obs;
  final _vibrate = false.obs;
  Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  @override
  void onInit() {
    initializeNotifications();
    initializeReceivePort();
    ever(_enabled, handleEnabled);
    ever(_mute, handleMute);
    ever(_vibrate, handleVibrate);
    super.onInit();
  }

  @override
  void onReady() {
    scheduler = Scheduler();
    scheduler.appName = title;
    scheduler.init();
    super.onReady();
  }

  @override
  void onClose() {
    scheduler?.shutdown();
    shutdownReceivePort();
    super.onClose();
  }

  handleEnabled(enabled) {
    if (enabled) {
      message.value = 'Enabled. Awaiting first notification...';
      infoMessage.value = 'Enabled';
      scheduler.enable();
    } else {
      scheduler.disable();
      message.value = 'Disabled';
      infoMessage.value = 'Disabled';
    }
  }

  void handleMute(bool mute) {
    Notifier.mute = mute;
  }

  void handleVibrate(bool vibrate) {
    Notifier.vibrate = vibrate;
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
    infoMessage.value = "Next notification at $timestr";
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
      Get.put(MindfulNotifierWidgetController());

  @override
  Widget build(BuildContext context) {
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
                        controller.scheduler.shutdown();
                        shutdownReceivePort();
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
                  child: Obx(() => Container(
                        margin: EdgeInsets.only(
                            top: 30, left: 30, right: 30, bottom: 30),
                        alignment: Alignment.center,
                        // decoration: BoxDecoration(color: Colors.grey[100]),
                        child: Text(
                          '${controller.message}',
                          style: Theme.of(context).textTheme.headline4,
                          // style: Theme.of(context).textTheme.headline5,
                          textAlign: TextAlign.left,
                          softWrap: true,
                        ),
                      )),
                ),
                Expanded(
                  flex: 4,
                  child: Obx(() => Row(
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
                      )),
                ),
                Expanded(
                    flex: 1,
                    child: Obx(
                      () => Text(
                        '${controller.infoMessage.value}',
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
