import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';

var logger = Logger(printer: SimpleLogPrinter('bell'));

const String customBellUndefined = 'Not defined';

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
    'path': '',
    'extendedInfo': 'Select a custom bell from your local file system.',
  },
};

class BellWidgetController extends GetxController {
  final _bellId = "defaultBell".obs;
  final _customBellPath = "".obs;
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
    _customBellPath.value = ds.customBellPath;
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
  }
}

void handleCustomBellPath(String value) {
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
      bellDefinitions[bellId]['path'] = result.files.single.path;
      controller._customBellPath.value = result.files.single.path;
    }
    // TODO HOW TO FORCE A UI REBUILD HERE? Test - do I need to?
    // controller.update()
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
          subtitle: Text(bellDefinitions[bellId]['path']),
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
                      if (File(bellDefinitions[bellId]['path']).existsSync()) {
                        mainUiController.sendToScheduler(
                            {'playSound': bellDefinitions[bellId]['path']});
                      } else {
                        _showNoCustomSoundAlert(context,
                            "The custom sound path '${bellDefinitions[bellId]['path']}' is no longer valid.");
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
