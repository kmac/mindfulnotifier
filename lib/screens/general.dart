import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:battery_optimization/battery_optimization.dart';
import 'package:device_info/device_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:share/share.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/utils.dart' as utils;
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';
import 'package:mindfulnotifier/theme/themes.dart';

var logger = createLogger('reminderview');

bool includeBackgroundService = false;

class GeneralWidgetController extends GetxController {
  final _useBackgroundService = false.obs;
  final _includeDebugInfo = false.obs;
  final _useStickyNotification = true.obs;
  final theme = 'Default'.obs;
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
    InMemoryScheduleDataStore mds = Get.find();
    theme.value = mds.theme;
    _includeDebugInfo.value = mds.includeDebugInfo;
    _useStickyNotification.value = mds.useStickyNotification;
    _useBackgroundService.value = mds.useBackgroundService;
  }

  @override
  void onReady() {
    ever(_useBackgroundService, handleUseBackgroundService);
    ever(_useStickyNotification, handleUseStickyNotification);
    ever(_includeDebugInfo, handleIncludeDebugInfo);
    ever(theme, handleTheme);
    super.onReady();
  }

  void handleUseBackgroundService(bool value) {
    // todo; persist, and inform user restart required
    InMemoryScheduleDataStore mds = Get.find();
    mds.useBackgroundService = value;
    scheduleDirty.value = true;
  }

  void handleUseStickyNotification(bool value) {
    InMemoryScheduleDataStore mds = Get.find();
    mds.useStickyNotification = value;
    scheduleDirty.value = true;
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    InMemoryScheduleDataStore mds = Get.find();
    Get.find<MindfulNotifierWidgetController>()
        .sendToAlarmService({'update': mds});
    scheduleDirty.value = false;
  }

  void handleIncludeDebugInfo(bool value) {
    // todo; persist, and inform user restart required
    InMemoryScheduleDataStore mds = Get.find();
    mds?.includeDebugInfo = value;
    MindfulNotifierWidgetController mainUiController = Get.find();
    mainUiController?.showControlMessages?.value = value;
  }

  void handleTheme(String value) {
    logger.d("Change theme: $value");
    Get.changeTheme(allThemes[value] ?? defaultTheme);
    InMemoryScheduleDataStore mds = Get.find();
    mds.theme = value;
    scheduleDirty.value = true;
  }
}

class GeneralWidget extends StatelessWidget {
  final GeneralWidgetController controller = Get.put(GeneralWidgetController());

  void _doBackup() async {
    Directory extStoreDir =
        Get.find(tag: constants.tagExternalStorageDirectory);
    if (extStoreDir != null) {
      String backupFileName =
          "${constants.appName}-backup-${utils.formatYYYYMMDDHHMM(DateTime.now())}.json";
      File backupFile = File("${extStoreDir.path}/$backupFileName");
      try {
        // ISSUE here: this backs up from the current shared prefs, not from the InMemoryScheduleDataStore
        // so shared prefs may not be exactly in sync
        ScheduleDataStore.backup(backupFile);

        if (await utils.showYesNoAlert(Get.context, 'Backup success',
            'The backup is saved at ${backupFile.path}. Do you want to share it?')) {
          await Share.shareFiles([backupFile.path], text: backupFileName);
        }

        // Finally, delete the backup from our internal directory
        // backupFile.delete();
      } catch (e) {
        logger.e('Backup failed, file=${backupFile.path}, exception: $e');
        utils.showErrorAlert(Get.context, 'Backup failed',
            'The backup operation failed with an exception: $e');
      }
    }
  }

  void _doRestore() async {
    FilePickerResult result =
        await FilePicker.platform.pickFiles(allowedExtensions: [
      'json',
    ], type: FileType.custom, allowMultiple: false, withData: true);
    if (result != null) {
      String backupFileName = result.files.first.name;
      if (await utils.showYesNoAlert(
          Get.context,
          "Proceed with restore?",
          "WARNING: this will overwrite any existing settings.\n\n" +
              "Do you want to restore using file $backupFileName?")) {
        try {
          // Do the restore
          Uint8List uint8list = result.files.first.bytes;
          if ((uint8list ?? []).isEmpty) {
            // https://github.com/miguelpruivo/flutter_file_picker/issues/616
            final file = File.fromUri(Uri.parse(result.files.single.path));
            uint8list = file.readAsBytesSync();
          }
          InMemoryScheduleDataStore mds =
              await ScheduleDataStore.restoreFromJson(
                  Utf8Decoder().convert(uint8list));
          Get.find<MindfulNotifierWidgetController>()
              .triggerSchedulerRestore(mds);
          controller.theme.value = mds.theme;
          utils.showInfoAlert(
              Get.context,
              'Successful Restore',
              'The restore operation was successful. ' +
                  'The scheduler needs to be manually re-enabled.',
              alertStyle: utils.getGlobalAlertStyle(mds.theme == 'Dark'),
              dialogTextStyle:
                  utils.getGlobalDialogTextStyle(mds.theme == 'Dark'));
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
            style: utils.getGlobalAlertStyle(Get.isDarkMode),
            buttons: [
              DialogButton(
                onPressed: () {
                  BatteryOptimization.openBatteryOptimizationSettings();
                  Navigator.pop(context);
                },
                child: Text(
                  "Close",
                  style: utils.getGlobalDialogTextStyle(Get.isDarkMode),
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
                            value: controller.theme.value,
                            onChanged: (value) {
                              controller.theme.value = value;
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
