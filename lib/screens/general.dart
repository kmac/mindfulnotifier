import 'dart:io';

import 'package:battery_optimization/battery_optimization.dart';
import 'package:device_info/device_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/utils.dart' as utils;
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';
import 'package:mindfulnotifier/theme/themes.dart';

var logger = createLogger('reminderview');

bool includeBackgroundService = false;

Future<bool> _handlePermissions() async {
  Map<Permission, PermissionStatus> statuses = await [
    Permission.storage,
  ].request();
  if (!statuses[Permission.storage].isGranted) {
    // May want to show a dialog here...
    return false;
  }
  return true;
}

class GeneralWidgetController extends GetxController {
  final _useBackgroundService = false.obs;
  final _includeDebugInfo = false.obs;
  final _useStickyNotification = true.obs;
  final _theme = 'Default'.obs;
  final scheduleDirty = false.obs;
  bool includeBatteryOptimizationCheck = true;

  GeneralWidgetController();

  @override
  void onInit() {
    super.onInit();
    AndroidBuildVersion buildVersion = Get.find();
    if (buildVersion.sdkInt < 23) {
      includeBatteryOptimizationCheck = false;
    }
    ScheduleDataStore ds = Get.find();
    _theme.value = ds.theme;
    _includeDebugInfo.value = ds.includeDebugInfo;
    _useStickyNotification.value = ds.useStickyNotification;
    _useBackgroundService.value = ds.useBackgroundService;
    ever(_useBackgroundService, handleUseBackgroundService);
    ever(_useStickyNotification, handleUseStickyNotification);
    ever(_includeDebugInfo, handleIncludeDebugInfo);
    ever(_theme, handleTheme);
  }

  @override
  void onReady() {
    super.onReady();
  }

  void handleUseBackgroundService(bool value) {
    // todo; persist, and inform user restart required
    ScheduleDataStore ds = Get.find();
    ds.useBackgroundService = value;
  }

  void handleUseStickyNotification(bool value) {
    ScheduleDataStore ds = Get.find();
    ds.useStickyNotification = value;
    scheduleDirty.value = true;
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    Get.find<MindfulNotifierWidgetController>().forceSchedulerUpdate();
    scheduleDirty.value = false;
  }

  void handleIncludeDebugInfo(bool value) {
    // todo; persist, and inform user restart required
    ScheduleDataStore ds = Get.find();
    ds?.includeDebugInfo = value;
    MindfulNotifierWidgetController mainUiController = Get.find();
    mainUiController?.showControlMessages?.value = value;
  }

  void handleTheme(String value) {
    logger.d("Change theme: $value");
    Get.changeTheme(allThemes[value] ?? defaultTheme);
    ScheduleDataStore ds = Get.find();
    ds.theme = value;
  }
}

class GeneralWidget extends StatelessWidget {
  final GeneralWidgetController controller = Get.put(GeneralWidgetController());

  void _doBackup() async {
    if (!await _handlePermissions()) {
      return;
    }
    String saveToDir = await FilePicker.platform.getDirectoryPath();
    if (saveToDir != null) {
      File backupFile = File(
          "$saveToDir/${constants.appName}-backup-${utils.formatYYYYMMDDHHMM(DateTime.now())}.json");
      ScheduleDataStore ds = Get.find();
      try {
        ds.backup(backupFile);
        utils.showInfoAlert(Get.context, 'Backup success',
            'The backup is saved at ${backupFile.path}');
      } catch (e) {
        logger.e('Backup failed, file=${backupFile.path}, exception: $e');
        utils.showErrorAlert(Get.context, 'Backup failed',
            'The backup operation failed with an exception: $e');
      }
    }
  }

  void _doRestore() async {
    if (!await _handlePermissions()) {
      return;
    }
    FilePickerResult result =
        await FilePicker.platform.pickFiles(allowedExtensions: [
      'json',
    ], type: FileType.custom, allowMultiple: false);
    if (result != null) {
      File backupFile = File(result.files.first.path);
      ScheduleDataStore ds = Get.find();
      if (await utils.showYesNoAlert(
          Get.context,
          "Proceed with restore?",
          "WARNING: this will overwrite any existing settings.\n\n" +
              "Do you want to restore using file ${backupFile.path}?")) {
        try {
          ds.restore(backupFile);
          utils.showInfoAlert(Get.context, 'Successful Restore',
              'The restore operation was successful.');
          Get.find<MindfulNotifierWidgetController>().triggerSchedulerRestart();
        } catch (e) {
          logger.e(
              'Restore failed, file=${result.files.first.path}, exception: $e');
          utils.showErrorAlert(Get.context, 'Restore Failed',
              'The restore operation failed with an exception: $e');
        }
      }
    }
  }

  void _checkBatteryOptimization(var context) {
    BatteryOptimization.isIgnoringBatteryOptimizations().then((onValue) {
      if (onValue) {
        // Ignoring Battery Optimization
        utils.showInfoAlert(
            context,
            '✔ Ignoring Battery Optimization',
            'Battery optimization is already ignored. ' +
                'The app should run properly in the background.');
      } else {
        Alert(
            context: context,
            title: '⊘ Issue: Battery Optimization',
            desc: "Battery optimization is active, therefore " +
                "the app may be killed in the background. " +
                "The next screen will take you to the " +
                "battery optimization settings.\nFind the '${constants.appName}' " +
                "app and turn off battery optimizations.",
            type: AlertType.warning,
            buttons: [
              DialogButton(
                onPressed: () {
                  BatteryOptimization.openBatteryOptimizationSettings();
                  Navigator.pop(context);
                },
                child: Text(
                  "Close",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ]).show();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (controller.scheduleDirty.value) {
            logger.d("schedule is dirty");
            controller.handleScheduleDirty();
          }
          return true;
        },
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Column(
                children: <Widget>[
                  Text(
                    'Preferences',
                  ),
                  // Text('Subtitle',
                  //     style: TextStyle(
                  //       fontSize: 12.0,
                  //     )),
                ],
              ),
            ),
            body: Center(
                child: Obx(() => ListView(children: <Widget>[
                      ListTile(
                          leading: Icon(Icons.app_settings_alt),
                          title: Text('Theme'),
                          trailing: Container(
                              // padding: EdgeInsets.all(2.0),
                              child: DropdownButton(
                            value: controller._theme.value,
                            onChanged: (value) {
                              controller._theme.value = value;
                            },
                            items: allThemes.keys
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ))),
                      Divider(),
                      ListTile(
                          leading: Icon(Icons.backup),
                          title: Text('Backup'),
                          subtitle: Text('Backup settings to file'),
                          trailing: Container(
                            // padding: EdgeInsets.all(2.0),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text("Save..."),
                              onPressed: () {
                                _doBackup();
                              },
                            ),
                          )),
                      Divider(),
                      ListTile(
                          leading: Icon(Icons.restore_page),
                          title: Text('Restore'),
                          subtitle: Text('Restore settings from file'),
                          trailing: Container(
                            // padding: EdgeInsets.all(2.0),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text("Load..."),
                              onPressed: () {
                                _doRestore();
                              },
                            ),
                          )),
                      if (controller.includeBatteryOptimizationCheck) Divider(),
                      if (controller.includeBatteryOptimizationCheck)
                        ListTile(
                          leading: Icon(Icons.wysiwyg),
                          title: Text('Check battery optimization settings'),
                          subtitle: Text('If battery optimization is enabled for this app it ' +
                              'can be shutdown when running in the background. ' +
                              'This button checks the battery optimization setting, ' +
                              'and leads you to the proper settings to disable if required.'),
                          trailing: OutlinedButton(
                            child: Text('Check'),
                            onPressed: () => _checkBatteryOptimization(context),
                          ),
                        ),
                      Divider(),
                      ListTile(
                          leading: Icon(Icons.notifications),
                          title: Text('Use sticky notification'),
                          subtitle: Text(controller._useStickyNotification.value
                              ? 'The reminder notification must be swiped to dismiss.'
                              : 'The notification is dismissed when selected.'),
                          trailing: Checkbox(
                            value: controller._useStickyNotification.value,
                            onChanged: (value) =>
                                controller._useStickyNotification.value = value,
                          )),
                      Divider(),
                      if (includeBackgroundService)
                        ListTile(
                          leading: Icon(Icons.miscellaneous_services),
                          title: Text('Use Background Service'),
                          subtitle:
                              Text('Use this if the app keeps getting killed.'),
                          trailing: Checkbox(
                            value: controller._useBackgroundService.value,
                            onChanged: (value) =>
                                controller._useBackgroundService.value = value,
                          ),
                        ),
                      if (includeBackgroundService) Divider(),
                      ListTile(
                          leading: Icon(Icons.wysiwyg),
                          title: Text('Include debug information'),
                          subtitle: Text(
                              'Includes extra runtime information in the bottom status panel (for debug only).'),
                          trailing: Checkbox(
                            value: controller._includeDebugInfo.value,
                            onChanged: (value) =>
                                controller._includeDebugInfo.value = value,
                          )),
                      Divider(),
                    ])))));
  }
}
