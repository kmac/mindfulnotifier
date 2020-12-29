import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/utils.dart' as utils;
import 'package:mindfulnotifier/theme/themes.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';

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
  final _theme = 'Default'.obs;

  GeneralWidgetController();

  @override
  void onInit() {
    super.onInit();
    ScheduleDataStore ds = Get.find();
    _theme.value = ds.theme;
    _includeDebugInfo.value = ds.includeDebugInfo;
    _useBackgroundService.value = ds.useBackgroundService;
    ever(_useBackgroundService, handleUseBackgroundService);
    ever(_includeDebugInfo, handleIncludeDebugInfo);
    ever(_theme, handleTheme);
  }

  @override
  void onReady() {
    init();
    super.onReady();
  }

  void init() async {
    logger.d("init");
  }

  void handleUseBackgroundService(bool value) {
    // todo; persist, and inform user restart required
    ScheduleDataStore ds = Get.find();
    ds.useBackgroundService = value;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          // title: Text('Configure Reminders'),
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
                  includeBackgroundService
                      ? ListTile(
                          leading: Icon(Icons.miscellaneous_services),
                          title: Text('Use Background Service'),
                          subtitle:
                              Text('Use this if the app keeps getting killed.'),
                          trailing: Checkbox(
                            value: controller._useBackgroundService.value,
                            onChanged: (value) =>
                                controller._useBackgroundService.value = value,
                          ),
                        )
                      : Divider(),
                  ListTile(
                      leading: Icon(Icons.wysiwyg),
                      title: Text('Include debug information'),
                      subtitle: Text(
                          'Includes some extra runtime information in the bottom status panel. Usually not needed.'),
                      trailing: Checkbox(
                        value: controller._includeDebugInfo.value,
                        onChanged: (value) =>
                            controller._includeDebugInfo.value = value,
                      )),
                  Divider(),
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
                        child: OutlineButton(
                          visualDensity: VisualDensity.compact,
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
                        child: OutlineButton(
                          visualDensity: VisualDensity.compact,
                          child: Text("Load..."),
                          onPressed: () {
                            _doRestore();
                          },
                        ),
                      )),
                ]))));
  }
}
