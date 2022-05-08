import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';

var logger = createLogger('bell');

const String customBellUndefined = 'Not defined';

Map<String, Map<String, String>> bellDefinitions = {
  'bell1': {
    'name': 'Bell 1',
    'path': 'media/tibetan_bell_ding_b.mp3',
    'description': 'The default bell. A Tibetan bell sounding the note B.',
    'extendedInfo': 'From https://freesound.org/people/steaq/sounds/346328/',
  },
  'bell2': {
    'name': 'Bell 2',
    'path': 'media/bell_inside.mp3',
    'description': 'A deep bell',
    'extendedInfo':
        'From https://freesound.org/people/itsallhappening/sounds/48795/',
  },
  'bell3': {
    'name': 'Bell 3',
    'path': 'media/bowl_struck.mp3',
    'description': 'A medium bell',
    'extendedInfo':
        'From https://freesound.org/people/suburban%20grilla/sounds/2166/',
  },
  'bell4': {
    'name': 'Bell 4',
    'path': 'media/zenbell_1.mp3',
    'description': 'A light bell',
    'extendedInfo': 'From https://freesound.org/people/kerri/sounds/27421/',
  },
  'bell5': {
    'name': 'Bell 5',
    'path': 'media/ding_soft.mp3',
    'description': 'A softly hit tibetan bowl',
    'extendedInfo': 'From https://freesound.org/people/dobroide/sounds/436976/',
  },
  // Custom Bell is last
  'customBell': {
    'name': 'Custom Bell',
    'path': '', // also tracked in _customBell for UI update purposes
    'extendedInfo': 'Select a custom bell from your local file system.',
  },
};

class SoundWidgetController extends GetxController {
  final _bellId = 'bell1'.obs;
  final _customBellPath = ''.obs;
  final _audioChannel = 'notification'.obs;
  var _selectedBellId;

  // UI event handlers, init code, etc goes here
  SoundWidgetController();

  @override
  void onInit() {
    // onInit: is called immediately after the widget is allocated memory.
    InMemoryScheduleDataStore mds = Get.find();
    _bellId.value = mds.bellId;
    _selectedBellId = _bellId.value;
    _customBellPath.value = mds
        .customBellPath; // tracks the value of bellDefinitions['customBell']['path']
    bellDefinitions['customBell']['path'] = _customBellPath.value;
    _audioChannel.value = mds.audioOutputChannel;

    super.onInit();
  }

  @override
  void onReady() {
    // onReady: is called immediately after the widget is rendered on screen.
    ever(_bellId, handleBellId);
    ever(_customBellPath, handleCustomBellPath);
    ever(_audioChannel, handleAudioChannel);

    super.onReady();
  }

  void handleBellId(String value) {
    logger.d("Change bell: $value");
    _selectedBellId = value;
    InMemoryScheduleDataStore mds = Get.find();
    mds.bellId = _selectedBellId;
    _updateAlarmService(mds);
  }

  void handleCustomBellPath(String value) async {
    logger.d("Change custom bell: $value");
    InMemoryScheduleDataStore mds = Get.find();
    mds.customBellPath = value;
    _updateAlarmService(mds);
  }

  void handleAudioChannel(String value) async {
    InMemoryScheduleDataStore mds = Get.find();
    mds.audioOutputChannel = value;
    _updateAlarmService(mds);
  }

  void _updateAlarmService(InMemoryScheduleDataStore mds) {
    // update alarm service with new memory store
    Get.find<MindfulNotifierWidgetController>().updatePermanentDataStore(mds);
  }
}

class SoundWidget extends StatelessWidget {
  final SoundWidgetController controller = Get.put(SoundWidgetController());

  Future<void> _pickFile(var bellId) async {
    FilePickerResult result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    //allowedExtensions: ['wav','mp3','mp4', 'm4a', 'flac', '3gp']);
    if (result != null) {
      // The file_picker copies the picked file into a temp cache. We have
      // to copy it over to our application documents directory.
      Directory appDocDir =
          Get.find(tag: constants.tagApplicationDocumentsDirectory);
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

  List<Widget> _buildRadioListTiles(context) {
    List<Widget> tiles = [];
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
          secondary: OutlinedButton(
            child: Text("Play"),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              MindfulNotifierWidgetController mainUiController = Get.find();
              if (bellDefinitions[bellId]['path'] != '') {
                mainUiController.sendToAlarmService(
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
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text("Select"),
                  onPressed: () => _pickFile(bellId),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text("Play"),
                  onPressed: () {
                    MindfulNotifierWidgetController mainUiController =
                        Get.find();
                    if (bellDefinitions[bellId]['path'] != '') {
                      File customsoundfile =
                          File(bellDefinitions[bellId]['path']);
                      if (customsoundfile.existsSync()) {
                        mainUiController
                            .sendToAlarmService({'playSound': customsoundfile});
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
      body: Obx(() => ListView(
            children: _buildRadioListTiles(context) +
                <Widget>[
                  Divider(),
                  ListTile(
                      leading: Icon(Icons.notifications),
                      title: Text('Audio Channel'),
                      subtitle: Text(
                          'The audio channel to use for the notification sound (default: notification)'),
                      trailing: Container(
                          child: DropdownButton(
                              value: controller._audioChannel.value,
                              onChanged: (value) {
                                controller._audioChannel.value = value;
                              },
                              items: [
                            DropdownMenuItem(
                                value: 'notification',
                                child: Text('notification')),
                            DropdownMenuItem(
                                value: 'media', child: Text('media')),
                            DropdownMenuItem(
                                value: 'alarm', child: Text('alarm')),
                          ]))),
                ],
          )),
    );
  }
}
