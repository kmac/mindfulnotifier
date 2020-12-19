import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/theme/themes.dart';

var logger = Logger(printer: SimpleLogPrinter('reminderview'));

class AdvancedWidgetController extends GetxController {
  final _useBackgroundService = false.obs;
  final _theme = "Default".obs;

  // UI event handlers, init code, etc goes here
  AdvancedWidgetController() {
    // init();
  }

  @override
  void onInit() {
    super.onInit();
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
    // TODO persist, and inform user restart required
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

class AdvancedWidget extends StatelessWidget {
  final AdvancedWidgetController controller =
      Get.put(AdvancedWidgetController());

  @override
  Widget build(BuildContext context) {
    // if (_needToScroll.value) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    //   _needToScroll.value = false;
    // }
    return Scaffold(
        appBar: AppBar(
          centerTitle: true,
          // title: Text('Configure Reminders'),
          title: Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            // crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Advanced Configuration',
              ),
              Text('Subtitle',
                  style: TextStyle(
                    fontSize: 12.0,
                  )),
            ],
          ),
        ),
        body: Center(
            child: /*Obx(
          () => */
                ListView(children: <Widget>[
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.start,
          //   children: [
          //     Icon(Icons.miscellaneous_services),
          //     Text('Background Service'),
          //   ],
          // ),
          ListTile(
            leading: Icon(Icons.miscellaneous_services),
            title: Text('Use Background Service'),
            subtitle: Text('Use this if the app keeps getting killed.'),
            trailing: Checkbox(
              value: controller._useBackgroundService.value,
              onChanged: (value) =>
                  controller._useBackgroundService.value = value,
            ),
          ),
          ListTile(
              leading: Icon(Icons.looks),
              title: Text('Theme'),
              trailing: Container(
                  padding: EdgeInsets.all(20.0),
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
