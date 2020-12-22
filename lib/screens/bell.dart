import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';

var logger = Logger(printer: SimpleLogPrinter('bell'));

const String customBellUndefined = 'Not defined';

// TODO move into constants and rename constants to globals
Map<String, Map<String, String>> bellDefinitions = {
  'defaultBell': {
    'name': 'Default Bell',
    'path': 'media/tibetan_bell_ding_b.mp3',
    'description': 'The default bell.',
    'extendedInfo': 'A Tibetan bell sounding the note B. ' +
        'From https://freesound.org/people/steaq/sounds/346328/',
  },
  'bell1': {
    'name': 'Singing bowl gong',
    'path': 'media/singing_bowl_gong.mp3',
    'description': 'A singing bowl gong',
    'extendedInfo':
        'From https://freesound.org/people/zambolino/sounds/439233/',
  },
  // Custom Bell is last
  'customBell': {
    'name': 'Custom Bell',
    'path': '', // also tracked in _customBell for UI update purposes
    'extendedInfo': 'Select a custom bell from your local file system.',
  },
};

class BellWidgetController extends GetxController {
  final _bellId = 'defaultBell'.obs;
  final _customBellPath = ''.obs;
  ScheduleDataStore ds = Get.find();
  var _selectedBellId;

  // UI event handlers, init code, etc goes here
  BellWidgetController();

  @override
  void onInit() {
    super.onInit();
    ScheduleDataStore ds = Get.find();
    _bellId.value = ds.bellId;
    _selectedBellId = _bellId.value;
    _customBellPath.value = ds
        .customBellPath; // tracks the value of bellDefinitions['customBell']['path']
    bellDefinitions['customBell']['path'] = _customBellPath.value;
    ever(_bellId, handleBellId);
    ever(_customBellPath, handleCustomBellPath);
  }

  @override
  void onReady() {
    super.onReady();
  }

  void handleBellId(String value) {
    logger.d("Change bell: $value");
    ScheduleDataStore ds = Get.find();
    ds.bellId = value;
    _selectedBellId = value;
    // update the alarm isolate:
    MindfulNotifierWidgetController mainUiController = Get.find();
    mainUiController.forceSchedulerUpdate();
  }
}

void handleCustomBellPath(String value) async {
  logger.d("Change custom bell: $value");
  ScheduleDataStore ds = Get.find();
  ds.customBellPath = value;
}

class BellWidget extends StatelessWidget {
  final BellWidgetController controller = Get.put(BellWidgetController());

  Future<void> _pickFile(var bellId) async {
    FilePickerResult result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    //allowedExtensions: ['wav','mp3','mp4', 'm4a', 'flac', '3gp']);
    if (result != null) {
      // The file_picker copies the picked file into a temp cache. We have
      // to copy it over to our application documents directory.
      Directory appDocDir = await getApplicationDocumentsDirectory();
      File cachedBellPath = File(result.files.single.path);
      String newCustomBellFileName =
          result.names.single; // the file name only - no path
      String newCustomBellPath =
          appDocDir.path + Platform.pathSeparator + newCustomBellFileName;
      logger.i("Copying $cachedBellPath to $newCustomBellPath");
      cachedBellPath.copySync(newCustomBellPath);

      // remove the old custom bell from our app directory
      if (controller._customBellPath.value != newCustomBellPath) {
        File previousCustomBell = File(controller._customBellPath.value);
        logger.i(
            "Removing previous custom bell ${controller._customBellPath.value}");
        previousCustomBell.delete();
      }
      // and finally, update our two paths:
      bellDefinitions[bellId]['path'] = newCustomBellPath;
      controller._customBellPath.value = newCustomBellPath;
    }
  }

  void _showNoCustomSoundAlert(BuildContext context, String alertText) {
    Alert(
        context: context,
        title: "Cannot Play Sound",
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
              Navigator.pop(context);
            },
            child: Text(
              "Close",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ]).show();
  }

  void _showInfoAlert(BuildContext context, String alertText) {
    Alert(
        context: context,
        title: "Additional Information",
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
              Navigator.pop(context);
            },
            child: Text(
              "Close",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ]).show();
  }

  List<RadioListTile> _buildRadioListTiles(context) {
    List<RadioListTile> tiles = [];
    for (String bellId in bellDefinitions.keys) {
      if (bellId != 'customBell') {
        tiles.add(RadioListTile(
          value: bellId,
          groupValue: controller._selectedBellId,
          title: Text(bellDefinitions[bellId]['name']),
          subtitle: Text(bellDefinitions[bellId]['description']),
          onChanged: (val) {
            controller._bellId.value = val;
          },
          activeColor: Theme.of(context).colorScheme.onSurface,
          secondary: OutlineButton(
            child: Text("Play"),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              MindfulNotifierWidgetController mainUiController = Get.find();
              if (bellDefinitions[bellId]['path'] != '') {
                mainUiController.sendToScheduler(
                    {'playSound': bellDefinitions[bellId]['path']});
              }
            },
            // onLongPress: () => _showInfoAlert(
            //     context, bellDefinitions[bellId]['extendedInfo'])
          ),
          selected: controller._bellId.value == controller._selectedBellId,
        ));
      } else {
        // Custom Bell
        tiles.add(RadioListTile(
          value: bellId,
          groupValue: controller._selectedBellId,
          title: Text(bellDefinitions[bellId]['name']),
          subtitle: Text(controller._customBellPath.value.split('/').last),
          onChanged: (val) {
            controller._bellId.value = val;
          },
          activeColor: Theme.of(context).colorScheme.onSurface,
          secondary: SizedBox(
              width: 180,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlineButton(
                  visualDensity: VisualDensity.compact,
                  child: Text("Select"),
                  onPressed: () => _pickFile(bellId),
                ),
                OutlineButton(
                  visualDensity: VisualDensity.compact,
                  child: Text("Play"),
                  onPressed: () {
                    MindfulNotifierWidgetController mainUiController =
                        Get.find();
                    if (bellDefinitions[bellId]['path'] != '') {
                      File customsoundfile =
                          File(bellDefinitions[bellId]['path']);
                      if (customsoundfile.existsSync()) {
                        mainUiController
                            .sendToScheduler({'playSound': customsoundfile});
                      } else {
                        _showNoCustomSoundAlert(context,
                            "The custom sound path '${bellDefinitions[bellId]['path']}' is not found.");
                      }
                    } else {
                      _showNoCustomSoundAlert(
                          context, "The custom sound path is not defined.");
                    }
                  },
                ),
              ])),
          selected: controller._bellId.value == controller._selectedBellId,
        ));
      }
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          // mainAxisAlignment: MainAxisAlignment.center,
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Bell Configuration',
            ),
            // Text('Long-press for details',
            //     style: TextStyle(
            //       fontSize: 12.0,
            //     )),
          ],
        ),
      ),
      body: Obx(() => Column(
            children: _buildRadioListTiles(context),
          )),
    );
  }
}
