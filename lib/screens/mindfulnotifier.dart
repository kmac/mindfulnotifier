import 'dart:async';
import 'dart:ui';
import 'dart:isolate';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

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

  bool initFinished = false;
  bool alarmServiceAlreadyRunning = false;
  final String title = appName;
  final _reminderMessage = '. . .'.obs;
  final _infoMessage = '. . .'.obs;
  final _enabled = false.obs;
  final _mute = false.obs;
  final _vibrate = false.obs;
  final controlMessage = ''.obs;
  final showControlMessages = false.obs;
  final hideNextReminder = false.obs;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  // onInit(): It is called immediately after the widget is allocated memory.
  // onReady(): It is called immediately after the widget is rendered on screen.

  @override
  void onInit() async {
    // onInit: is called immediately after the widget is allocated memory.
    alarmServiceAlreadyRunning =
        Get.find(tag: constants.tagAlarmServiceAlreadyRunning);
    logger.i("mindfulnotifier UI onInit() alarmServiceAlreadyRunning: "
        "$alarmServiceAlreadyRunning, ${getCurrentIsolate()}");

    initializeFromAlarmServiceReceivePort();

    // Issue #35: maybe the below is a race condition... if the alarm service responds
    // after the above onInit finishes, we could see odd things?

    initFinished = false;
    // Now send a sync message which will reinit the data store
    // from the alarm/scheduler isolate
    sendToAlarmService({'syncDataStore': 1});

    super.onInit();
  }

  @override
  void onReady() {
    // onReady: is called immediately after the widget is rendered on screen.
    initializeNotifications();
    // initializeFromBackgroundService();
    super.onReady();
  }

  void initFinish(InMemoryScheduleDataStore mds) {
    logger.i("initFinish");
    ever(_enabled, handleEnabled);
    ever(_mute, handleMute);
    ever(_vibrate, handleVibrate);
    initFinished = true;
    if (!alarmServiceAlreadyRunning && mds.enabled) {
      logger.i("initFinish: re-enabling");
      triggerSchedulerRestart();
    }
  }

  @override
  void onClose() {
    shutdownReceivePort();
    super.onClose();
  }

  void initFromDS(InMemoryScheduleDataStore mds) {
    logger.d("initFromDS: enabled: ${mds.enabled}");

    // Replace the main/app InMemoryScheduleDataStore instance with the
    // newer one from alarm service
    Get.delete<InMemoryScheduleDataStore>();
    Get.put(mds);

    // set all the local UI-visible values
    _enabled.value = mds.enabled;
    _mute.value = mds.mute;
    _vibrate.value = mds.vibrate;
    _reminderMessage.value = mds.reminderMessage;
    _infoMessage.value = mds.infoMessage;
    controlMessage.value = mds.controlMessage;
    showControlMessages.value = mds.includeDebugInfo;
    hideNextReminder.value = mds.hideNextReminder;
  }

  void initializeFromAlarmServiceReceivePort() {
    logger.i("initializeFromAlarmServiceReceivePort ${getCurrentIsolate()}");

    if (fromAlarmServiceReceivePort == null) {
      logger.d("new fromAlarmServiceReceivePort");
      fromAlarmServiceReceivePort = ReceivePort();
    }
    // Register for events from the alarm isolate
    fromAlarmServiceStreamSubscription = fromAlarmServiceReceivePort
        .listen(handleAlarmServiceMessage, onDone: () {
      logger.w("fromAlarmServiceReceivePort is closed");
    });

    // Register our SendPort for the Scheduler to be able to send to our ReceivePort
    IsolateNameServer.removePortNameMapping(constants.toAppSendPortName);
    bool result = IsolateNameServer.registerPortWithName(
      fromAlarmServiceReceivePort.sendPort,
      constants.toAppSendPortName,
    );
    logger.d("registerPortWithName: ${constants.toAppSendPortName}, "
        "result=$result ${getCurrentIsolate()}");
    assert(result);
  }

  void handleAlarmServiceMessage(var msg) {
    //
    // WE ARE IN THE MAIN APP ISOLATE, receiving from alarm service
    //
    logger
        .i("fromAlarmServiceReceivePort received: $msg ${getCurrentIsolate()}");

    String key = msg.keys.first;
    dynamic value = msg.values.first;
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
        if (!initFinished) {
          sendToAlarmService({'syncDataStore': 1});
          // Note: response comes in and handled in next case
        }
        break;
      case 'syncDataStore':
        logger.i("Received syncDataStore from alarm service");
        // Receives a complete InMemoryScheduleDataStore update
        InMemoryScheduleDataStore mds = value;
        initFromDS(mds);
        if (!initFinished) {
          initFinish(mds);
        }
        break;
      default:
        logger.e("Unexpected key: $key");
        break;
    }
  }

  void triggerSchedulerShutdown() {
    // Send to the alarm isolate
    sendToAlarmService({'shutdown': '1'});
  }

  void triggerSchedulerRestore(InMemoryScheduleDataStore mds) {
    // we need to update the datastore
    logger.i("sending update to scheduler");
    sendToAlarmService({'restore': mds});
  }

  void triggerSchedulerRestart({InMemoryScheduleDataStore mds, String reason}) {
    if (_enabled.value) {
      //
      logger.i("sending restart to scheduler");
      // Send to the alarm isolate
      sendToAlarmService({'restart': mds});
      // alert user
      if (reason != null) {
        Get.snackbar("Restarting", reason,
            snackPosition: SnackPosition.BOTTOM, instantInit: false);
      }
    } else {
      if (mds != null) {
        // we need to update the datastore
        logger.i("sending update to scheduler");
        sendToAlarmService({'update': mds});
      }
    }
  }

  void shutdownReceivePort() async {
    logger.i("shutdownReceivePort");
    fromAlarmServiceReceivePort.close();
    await fromAlarmServiceStreamSubscription.cancel();
    IsolateNameServer.removePortNameMapping(constants.toAppSendPortName);
  }

  /// Updates the permanent data store via the alarm service
  void updatePermanentDataStore(InMemoryScheduleDataStore mds) {
    logger.d("updatePermanentDataStore");
    toAlarmServiceSendPort ??= IsolateNameServer.lookupPortByName(
        constants.toAlarmServiceSendPortName);
    toAlarmServiceSendPort?.send({'update': mds});
  }

  void sendToAlarmService(Map<String, dynamic> msg) {
    logger.d("sendToAlarmService: $msg");
    toAlarmServiceSendPort ??= IsolateNameServer.lookupPortByName(
        constants.toAlarmServiceSendPortName);
    toAlarmServiceSendPort?.send(msg);
  }

  void handleEnabled(enabled) {
    logger.d("handleEnabled: enabled=$enabled, initFinished: $initFinished, "
        "alarmServiceAlreadyRunning: $alarmServiceAlreadyRunning");
    if (!initFinished) {
      return;
    }
    if (enabled) {
      if (_reminderMessage.value ==
              ScheduleDataStoreBase.defaultReminderMessage ||
          _reminderMessage.value == 'In quiet hours') {
        _reminderMessage.value = 'Enabled. Waiting for notification...';
      }
      _infoMessage.value = 'Enabled. Waiting for notification.';
      sendToAlarmService({'enable': _infoMessage.value});
    } else {
      _infoMessage.value = 'Disabled';
      sendToAlarmService({'disable': _infoMessage.value});
    }
  }

  void handleMute(bool mute) {
    logger.d("handleMute: mute=$mute, initFinished: $initFinished");
    if (initFinished) {
      sendToAlarmService({'mute': mute});
    }
  }

  void handleVibrate(bool vibrate) {
    logger.d("handleVibrate: vibrate=$vibrate, initFinished: $initFinished");
    if (initFinished) {
      sendToAlarmService({'vibrate': vibrate});
    }
  }

  void handleScheduleOnTap() {
    Get.toNamed('/schedules');
  }

  void handleRemindersOnTap() {
    Get.toNamed('/reminders');
  }

  void handleSoundOnTap() {
    Get.toNamed('/sound');
  }

  void handleGeneralOnTap() {
    Get.toNamed('/general');
  }
}

class MindfulNotifierWidget extends StatelessWidget {
  final MindfulNotifierWidgetController controller =
      Get.put(MindfulNotifierWidgetController(), permanent: true);

  Color getMainTextColor() {
    return Get.isDarkMode ? Colors.grey[400] : Colors.grey[800];
  }

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
              flex: 15,
              child: Obx(() => Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  color: Theme.of(context).canvasColor,
                  margin:
                      EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 0),
                  elevation: 1,
                  child: Container(
                      // margin: EdgeInsets.only(
                      //     top: 15, left: 15, right: 15, bottom: 15),
                      alignment: Alignment.center,
                      child: InkWell(
                          onLongPress: () async {
                            await Share.share(controller._reminderMessage.value,
                                subject: appName);
                          },
                          // decoration: BoxDecoration(color: Colors.grey[100]),
                          child: Scrollbar(
                            isAlwaysShown: false,
                            child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                    top: 15, left: 15, right: 15, bottom: 15),
                                child: Text(
                                  '${controller._reminderMessage}',
                                  style: TextStyle(
                                      color: getMainTextColor(),
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'Open Sans',
                                      fontSize: controller._reminderMessage
                                                  .value.length <
                                              Reminder.truncLength
                                          ? 30
                                          : 22),
                                  textAlign:
                                      controller._reminderMessage.value.length <
                                              Reminder.truncLength
                                          ? TextAlign.center
                                          : TextAlign.left,
                                  softWrap: true,
                                )),
                          ))))),
            ),
            Expanded(
              flex: 3,
              child: Obx(() => Card(
                  // shape: RoundedRectangleBorder(
                  //   borderRadius: BorderRadius.circular(15.0),
                  // ),
                  color: Theme.of(context).cardColor,
                  margin: // EdgeInsets.only(top: 5, left: 5, right: 5, bottom: 5),
                      EdgeInsets.only(top: 10, left: 15, right: 15, bottom: 15),
                  elevation: 5,
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
                    controller.hideNextReminder.value
                        ? ''
                        : controller.controlMessage.value != '' &&
                                controller.showControlMessages.value
                            ? '${controller._infoMessage.value} [${controller.controlMessage.value}]'
                            : '${controller._infoMessage.value}',
                    // style: TextStyle(
                    //     color: Get.isDarkMode ? mainTextColor : Colors.black38),
                    style: TextStyle(color: getMainTextColor()),
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
                color: Theme.of(context).appBarTheme.backgroundColor,
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
              title: Text('Sound'),
              subtitle: Text('Configure bell and sound options'),
              onTap: controller.handleSoundOnTap,
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Preferences'),
              subtitle: Text('Configure application settings: theme, etc.'),
              onTap: controller.handleGeneralOnTap,
            ),
            Divider(),
            AppAboutListTile(context),
          ],
        ),
      ),
      /* ) */
    );
  }
}
