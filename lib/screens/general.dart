import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/theme/themes.dart';

var logger = Logger(printer: SimpleLogPrinter('reminderview'));

class GeneralWidgetController extends GetxController {
  final _useBackgroundService = false.obs;
  final _theme = "Default".obs;

  GeneralWidgetController();

  @override
  void onInit() {
    super.onInit();
    ScheduleDataStore ds = Get.find();
    _theme.value = ds.theme;
    ever(_useBackgroundService, handleUseBackgroundService);
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
    ds.useBackgroundService = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          // title: Text('Configure Reminders'),
          title: Column(
            children: <Widget>[
              Text(
                'General Configuration',
              ),
              // Text('Subtitle',
              //     style: TextStyle(
              //       fontSize: 12.0,
              //     )),
            ],
          ),
        ),
        body: Center(
            child: /*Obx(
          () => */
                ListView(children: <Widget>[
          // ListTile(
          //   leading: Icon(Icons.miscellaneous_services),
          //   title: Text('Use Background Service'),
          //   subtitle: Text('Use this if the app keeps getting killed.'),
          //   trailing: Checkbox(
          //     value: controller._useBackgroundService.value,
          //     onChanged: (value) =>
          //         controller._useBackgroundService.value = value,
          //   ),
          // ),
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
              )))
        ])));
  }
}
