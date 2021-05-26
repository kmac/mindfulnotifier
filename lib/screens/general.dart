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
  final _hideNextReminder = false.obs;
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
    _hideNextReminder.value = mds.hideNextReminder;
  }

  @override
  void onReady() {
    ever(_useBackgroundService, handleUseBackgroundService);
    ever(_useStickyNotification, handleUseStickyNotification);
    ever(_includeDebugInfo, handleIncludeDebugInfo);
    ever(_hideNextReminder, handleHideNextReminder);
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

  void handleHideNextReminder(bool value) {
    // todo; persist, and inform user restart required
    InMemoryScheduleDataStore mds = Get.find();
    mds.hideNextReminder = value;
    Get.find<MindfulNotifierWidgetController>().hideNextReminder.value = value;
    scheduleDirty.value = true;
  }

  void handleIncludeDebugInfo(bool value) {
    // todo; persist, and inform user restart required
    InMemoryScheduleDataStore mds = Get.find();
    mds.includeDebugInfo = value;
    Get.find<MindfulNotifierWidgetController>().showControlMessages?.value =
        value;
    scheduleDirty.value = true;
  }

  void handleTheme(String value) {
    logger.d("Change theme: $value");
    Get.changeTheme(allThemes[value] ?? defaultTheme);
    InMemoryScheduleDataStore mds = Get.find();
    mds.theme = value;
    scheduleDirty.value = true;
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    InMemoryScheduleDataStore mds = Get.find();
    Get.find<MindfulNotifierWidgetController>()
        .sendToAlarmService({'update': mds});
    scheduleDirty.value = false;
  }
}

class GeneralWidget extends StatelessWidget {
  final GeneralWidgetController controller = Get.put(GeneralWidgetController());

  void _exportReminders() async {
    String exportFileName =
        "${constants.appName}-reminders-${utils.formatYYYYMMDDHHMM(DateTime.now())}.json";
    Directory extStoreDir =
        Get.find(tag: constants.tagExternalStorageDirectory);
    File exportFile = File("${extStoreDir.path}/$exportFileName");
    try {
      InMemoryScheduleDataStore mds = Get.find();
      String jsonData = mds.jsonReminders;
      logger.d('export, tofile:${exportFile.path}: $jsonData');
      exportFile.writeAsStringSync(jsonData, flush: true);

      if (await utils.showYesNoAlert(
          Get.context,
          'Export success',
          "The exported reminders are saved at ${exportFile.path} but will be removed when the app is uninstalled.\n\n" +
              "You should copy it to another place either via 'Share' or by using a file manager.",
          yesButtonText: 'Share',
          noButtonText: 'Close')) {
        await Share.shareFiles([exportFile.path], text: exportFileName);
      }
      // Finally, delete the backup from our internal directory
      // backupFile.delete();
    } catch (e) {
      logger.e('Backup failed, file=${exportFile.path}, exception: $e');
      utils.showErrorAlert(Get.context, 'Export failed',
          'The export operation failed with an exception: $e');
    }
  }

  Future<Map<String, bool>> showImportAlert(
      BuildContext context, String title, String alertText) async {
    bool answer = false;
    bool merge = false;
    await Alert(
        context: context,
        title: title,
        desc:
            'Replace: replace existing reminders. Merge: merge with existing reminders',
        type: AlertType.warning,
        style: utils.getGlobalAlertStyle(Get.isDarkMode),
        content: Column(
          children: <Widget>[
            Text(alertText,
                style: TextStyle(
                  fontSize: 16.0,
                )),
          ],
        ),
        buttons: [
          DialogButton(
            onPressed: () {
              answer = false;
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: utils.getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          ),
          DialogButton(
            onPressed: () {
              answer = true;
              Navigator.pop(context);
            },
            child: Text(
              'Replace',
              style: utils.getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          ),
          DialogButton(
            onPressed: () {
              answer = true;
              merge = true;
              Navigator.pop(context);
            },
            child: Text(
              'Merge',
              style: utils.getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          )
        ]).show();
    return {'answer': answer, 'merge': merge};
  }

  void _importReminders() async {
    FilePickerResult result =
        await FilePicker.platform.pickFiles(allowedExtensions: [
      'json',
    ], type: FileType.custom, allowMultiple: false, withData: true);
    if (result != null) {
      String importFileName = result.files.first.name;
      Map<String, bool> alertResult = await showImportAlert(
          Get.context,
          "Proceed with import?",
          "WARNING: this will overwrite any existing reminders.\n\n" +
              "Do you want to import using file $importFileName?");
      if (alertResult['answer']) {
        try {
          // Do the restore
          Uint8List uint8list = result.files.first.bytes;
          if ((uint8list ?? []).isEmpty) {
            // https://github.com/miguelpruivo/flutter_file_picker/issues/616
            final file = File.fromUri(Uri.parse(result.files.single.path));
            uint8list = file.readAsBytesSync();
          }
          InMemoryScheduleDataStore mds = Get.find();
          String importedString = Utf8Decoder().convert(uint8list);
          if (importedString.contains("scheduleType")) {
            // this is an old 'backup' file, not an exported reminder list
            Map<String, dynamic> importedJson = json.decode(importedString);
            List<String> remindersList = [];
            for (String reminder in importedJson['reminders']) {
              if (alertResult['merge'] && mds.reminderExists(reminder)) {
                continue;
              }
              remindersList.add(reminder);
            }
            mds.jsonReminders = Reminders.migrateToJson(remindersList);
          } else {
            if (alertResult['merge']) {
              // TODO use new Reminders classes
              List newJsonReminders = json.decode(importedString);
              List existingJsonReminders = json.decode(mds.jsonReminders);
              for (Map newReminder in newJsonReminders) {
                if (newReminder.containsKey('text') &&
                    !mds.reminderExists(newReminder['text'],
                        jsonReminderList: existingJsonReminders)) {
                  existingJsonReminders.add(newReminder);
                }
              }
              mds.jsonReminders = json.encode(existingJsonReminders);
            } else {
              mds.jsonReminders = importedString;
            }
          }

          Get.find<MindfulNotifierWidgetController>()
              .triggerSchedulerRestore(mds);
          controller.theme.value = mds.theme;
          utils.showInfoAlert(Get.context, 'Successful Import',
              'The reminders import operation was successful.',
              alertStyle: utils.getGlobalAlertStyle(mds.theme == 'Dark'),
              dialogTextStyle:
                  utils.getGlobalDialogTextStyle(mds.theme == 'Dark'));
        } catch (e) {
          logger.e(
              'Reminder import failed, file=${result.files.first.path}, exception: $e');
          utils.showErrorAlert(Get.context, 'Restore Failed',
              'The reminder import operation failed with an exception: $e');
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
                          title: Text('Export Reminders'),
                          subtitle: Text('Export reminders to file'),
                          trailing: Container(
                            // padding: EdgeInsets.all(2.0),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text("Export..."),
                              onPressed: () {
                                _exportReminders();
                              },
                            ),
                          )),
                      Divider(),
                      ListTile(
                          leading: Icon(Icons.restore_page),
                          title: Text('Import Reminders'),
                          subtitle: Text(
                              'Import reminders from file, with option to either ' +
                                  ' replace or merge existing reminder list.'),
                          trailing: Container(
                            // padding: EdgeInsets.all(2.0),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text("Import..."),
                              onPressed: () {
                                _importReminders();
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
                      ListTile(
                          leading: Icon(Icons.wysiwyg),
                          title: Text('Hide next reminder'),
                          subtitle: Text(
                              "Don't show next reminder information at bottom of main screen"),
                          trailing: Checkbox(
                            value: controller._hideNextReminder.value,
                            onChanged: (value) =>
                                controller._hideNextReminder.value = value,
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
                      // ListTile(
                      //     leading: Icon(Icons.wysiwyg),
                      //     title: Text('Include debug information'),
                      //     subtitle: Text(
                      //         'Includes extra runtime information in the bottom status panel (for debug only).'),
                      //     trailing: Checkbox(
                      //       value: controller._includeDebugInfo.value,
                      //       onChanged: (value) =>
                      //           controller._includeDebugInfo.value = value,
                      //     )),
                      // Divider(),
                    ])))));
  }
}
