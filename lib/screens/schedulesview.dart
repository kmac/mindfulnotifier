import 'dart:ui';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';

var logger = Logger(printer: SimpleLogPrinter('schedulesview'));

enum ScheduleType { periodic, random }

class SchedulesWidgetController extends GetxController {
  ScheduleDataStore ds;
  final scheduleType = ScheduleType.periodic.obs;
  final periodicHours = 1.obs;
  final periodicMinutes = 0.obs;
  final randomMinMinutes = 60.obs;
  final randomMaxMinutes = 90.obs;
  final scheduleDirty = false.obs;
  final quietHoursStartPicked = TimeOfDay(hour: 1, minute: 0).obs;
  final quietHoursEndPicked = TimeOfDay(hour: 1, minute: 0).obs;

  TextEditingController randomMinMinutesController = TextEditingController();
  TextEditingController randomMaxMinutesController = TextEditingController();
  TextEditingController quietHoursStartTimeController = TextEditingController();
  TextEditingController quietHoursEndTimeController = TextEditingController();

  // UI event handlers, init code, etc goes here
  SchedulesWidgetController();

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    init();
    super.onReady();
  }

  void init() async {
    logger.d("init");

    // ds = Get.find();
    ds = await ScheduleDataStore.getInstance();

    if (ds.scheduleTypeStr == 'periodic') {
      scheduleType.value = ScheduleType.periodic;
    } else {
      scheduleType.value = ScheduleType.random;
    }

    periodicHours.value = ds.periodicHours;
    periodicMinutes.value = ds.periodicMinutes;
    randomMinMinutesController.text = "${ds.randomMinMinutes}";
    randomMaxMinutesController.text = "${ds.randomMaxMinutes}";

    quietHoursStartPicked.value = TimeOfDay(
        hour: ds.quietHoursStartHour, minute: ds.quietHoursStartMinute);
    quietHoursEndPicked.value =
        TimeOfDay(hour: ds.quietHoursEndHour, minute: ds.quietHoursEndMinute);
    quietHoursStartTimeController.text = formatHHMM(DateTime(
        2020, 01, 1, ds.quietHoursStartHour, ds.quietHoursStartMinute));
    quietHoursEndTimeController.text = formatHHMM(
        DateTime(2020, 01, 1, ds.quietHoursEndHour, ds.quietHoursEndMinute));

    ever(scheduleType, handleScheduleType);
    ever(periodicHours, handlePeriodicHours);
    ever(periodicMinutes, handlePeriodicMinutes);
    ever(randomMinMinutes, handleRandomMinMinutes);
    ever(randomMaxMinutes, handleRandomMaxMinutes);
    ever(quietHoursStartPicked, handleQuietHoursStartPicked);
    ever(quietHoursEndPicked, handleQuietHoursEndPicked);
  }

  void handleScheduleType(ScheduleType t) {
    if (t == ScheduleType.periodic) {
      if (ds.scheduleTypeStr != 'periodic') {
        ds.scheduleTypeStr = 'periodic';
        scheduleDirty.value = true;
      }
    } else {
      if (ds.scheduleTypeStr != 'random') {
        ds.scheduleTypeStr = 'random';
        scheduleDirty.value = true;
      }
    }
  }

  void handlePeriodicHours(int hours) {
    if (ds.periodicHours != hours) {
      ds.periodicHours = hours;
      if (hours > 0) {
        periodicMinutes.value = 0;
      } else if (periodicMinutes.value < 15) {
        periodicMinutes.value = 15;
      }
      scheduleDirty.value = true;
    }
  }

  void handlePeriodicMinutes(int minutes) {
    if (ds.periodicMinutes != minutes) {
      ds.periodicMinutes = minutes;
      scheduleDirty.value = true;
    }
  }

  void handleRandomMinMinutes(int minutes) {
    if (ds.randomMinMinutes != minutes) {
      ds.randomMinMinutes = minutes;
      // check for consistency with max value
      if (randomMaxMinutes.value < minutes) {
        randomMaxMinutes.value = minutes + 15;
        randomMaxMinutesController.text = "${randomMaxMinutes.value}";
      }
      scheduleDirty.value = true;
    }
  }

  void handleRandomMaxMinutes(int minutes) {
    if (ds.randomMaxMinutes != minutes) {
      ds.randomMaxMinutes = minutes;
      // check for consistency with min value
      if (randomMinMinutes.value > minutes) {
        randomMinMinutes.value = minutes;
        randomMinMinutesController.text = "${randomMinMinutes.value}";
      }
      scheduleDirty.value = true;
    }
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    Get.find<MindfulNotifierWidgetController>().triggerSchedulerRestart();
    scheduleDirty.value = false;
  }

  void handleQuietHoursStartPicked(TimeOfDay time) {
    quietHoursStartTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    if (ds.quietHoursStartHour != time.hour ||
        ds.quietHoursStartMinute != time.minute) {
      ds.quietHoursStartHour = time.hour;
      ds.quietHoursStartMinute = time.minute;
      scheduleDirty.value = true;
    }
  }

  void handleQuietHoursEndPicked(TimeOfDay time) {
    quietHoursEndTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    if (ds.quietHoursEndHour != time.hour ||
        ds.quietHoursEndMinute != time.minute) {
      ds.quietHoursEndHour = time.hour;
      ds.quietHoursEndMinute = time.minute;
      scheduleDirty.value = true;
    }
  }
}

class SchedulesWidget extends StatelessWidget {
  final SchedulesWidgetController controller =
      Get.put(SchedulesWidgetController());

  DropdownButton<int> _buildDropDown(var context, int dropdownValue,
      List<int> allowedValues, Function onChangedFunc,
      [bool useTwoDigits = false]) {
    return DropdownButton<int>(
      value: dropdownValue,
      elevation: 16,
      style: Theme.of(context).textTheme.headline5,
      // underline: Container(height: 2, color: Colors.black54),
      onChanged: onChangedFunc,
      items: allowedValues.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(useTwoDigits ? timeNumToString(value) : value.toString()),
        );
      })?.toList(),
    );
  }

  Widget _buildRandomMinutesWidget(
      var context, String labelText, var textController, var obxVal) {
    return SizedBox(
        // height: 80,
        width: 120,
        child: Container(
            // decoration: BoxDecoration(color: Colors.grey[200]),
            decoration: BoxDecoration(color: Theme.of(context).backgroundColor),
            padding: EdgeInsets.all(8),
            // margin: EdgeInsets.only(
            //     top: 2, left: 2, right: 2, bottom: 2),
            alignment: Alignment.center,
            child:
                // Text('Minimum Delay',
                //     style: Theme.of(context).textTheme.bodyText1),
                TextField(
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                  disabledBorder:
                      UnderlineInputBorder(borderSide: BorderSide.none),
                  labelText: labelText,
                  contentPadding: EdgeInsets.all(5)),
              maxLines: 1,
              style: Theme.of(context).textTheme.headline5,
              controller: textController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (textval) {
                int newval = int.tryParse(textval);
                if (newval != null) {
                  obxVal.value = newval;
                } else {
                  // revert it back to the old value
                  textController.text = "${controller.randomMinMinutes.value}";
                }
              },
            )));
  }

  List<Widget> _buildScheduleView(BuildContext context) {
    List<Widget> widgets = [
      Text('Schedule Type', style: Theme.of(context).textTheme.headline5),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Text('Periodic'),
        Radio(
          value: ScheduleType.periodic,
          groupValue: controller.scheduleType.value,
          onChanged: (value) => controller.scheduleType.value = value,
        ),
        const Text('Random'),
        Radio(
          value: ScheduleType.random,
          groupValue: controller.scheduleType.value,
          onChanged: (value) => controller.scheduleType.value = value,
        ),
      ])
    ];
    if (controller.scheduleType.value == ScheduleType.periodic) {
      widgets.add(
        new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
                // padding: EdgeInsets.all(24.0),
                padding: EdgeInsets.fromLTRB(30, 0, 30, 20),
                child: Text(
                    'Choose the reminder period. ' +
                        'Reminders are aligned to the top of hour, ' +
                        'unless the period is shorter than one hour, in which' +
                        ' case the granularity is 15 minutes.',
                    style: TextStyle(
                      fontWeight: FontWeight.w300, /*fontSize: 12*/
                    ),
                    softWrap: true)),
            new Container(
                // decoration: BoxDecoration(color: Colors.grey[200]),
                decoration:
                    BoxDecoration(color: Theme.of(context).backgroundColor),
                padding: EdgeInsets.all(8),
                width: 200,
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    new Column(
                      children: [
                        Text(
                          'Hours',
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                        _buildDropDown(
                            context,
                            controller.periodicHours.value,
                            [0, 1, 2, 3, 4, 8, 12],
                            (value) => controller.periodicHours.value = value,
                            true),
                      ],
                    ),
                    Text(' : '),
                    new Column(
                      children: [
                        Text(
                          'Minutes',
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                        _buildDropDown(
                            context,
                            controller.periodicMinutes.value,
                            // controller.periodicMinutes.value == 0 &&
                            controller.periodicHours.value > 0
                                ? [0]
                                : [0, 15, 30],
                            (value) => controller.periodicMinutes.value = value,
                            true),
                      ],
                    )
                  ],
                )),
          ],
        ),
      );
    } else {
      // Random
      widgets.add(
          // child: new Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //     children: <Widget>[
          new Container(
        // decoration: BoxDecoration(color: Colors.grey[200]),
        // padding: EdgeInsets.all(8),
        child: Column(children: <Widget>[
          Padding(
              // padding: EdgeInsets.all(24.0),
              padding: EdgeInsets.fromLTRB(30, 0, 30, 20),
              child: Text(
                  'Enter the minimum and maximum delay between notifications. Values is in minutes.',
                  style: TextStyle(
                    fontWeight: FontWeight.w300, /*fontSize: 12*/
                  ),
                  softWrap: true)),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _buildRandomMinutesWidget(
                    context,
                    'Minimum',
                    controller.randomMinMinutesController,
                    controller.randomMinMinutes),
                // Text('to'),
                _buildRandomMinutesWidget(
                    context,
                    'Maximum',
                    controller.randomMaxMinutesController,
                    controller.randomMaxMinutes),
              ]),
        ]),
      ));
    }
    return widgets;
  }

  Future<Null> _selectQuietHoursStartTime(BuildContext context) async {
    var selectedTime = TimeOfDay(
        hour: controller.ds.quietHoursStartHour,
        minute: controller.ds.quietHoursStartMinute);
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      selectedTime = picked;
      controller.quietHoursStartPicked.value = picked;
    }
  }

  Future<Null> _selectQuietHoursEndTime(BuildContext context) async {
    var selectedTime = TimeOfDay(
        hour: controller.ds.quietHoursEndHour,
        minute: controller.ds.quietHoursEndMinute);
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      selectedTime = picked;
      controller.quietHoursEndPicked.value = picked;
    }
  }

  Widget _buildQuietHoursWidget(
      var context, String labelText, var textController /*, var obxVal*/) {
    return Container(
        width: 150,
        // height: _height / 9,
        margin: EdgeInsets.only(top: 30),
        alignment: Alignment.center,
        decoration: // BoxDecoration(color: Colors.grey[200]),
            BoxDecoration(color: Theme.of(context).backgroundColor),
        child: TextFormField(
          // style: TextStyle(fontSize: 20),
          style: Theme.of(context).textTheme.headline5,
          textAlign: TextAlign.center,
          enabled: false,
          keyboardType: TextInputType.text,
          controller: textController,
          decoration: InputDecoration(
              disabledBorder: UnderlineInputBorder(borderSide: BorderSide.none),
              labelText: labelText,
              labelStyle: Theme.of(context).textTheme.headline6,
              contentPadding: EdgeInsets.all(15)),
        ));
  }

  List<Widget> _buildQuietHoursView(BuildContext context) {
    List<Widget> widgets = [
      Text('Quiet Hours', style: Theme.of(context).textTheme.headline5),
      new Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          InkWell(
              onTap: () {
                _selectQuietHoursStartTime(context);
              },
              child: _buildQuietHoursWidget(context, 'Start Time',
                  controller.quietHoursStartTimeController)),
          Text('to: '),
          InkWell(
              onTap: () {
                _selectQuietHoursEndTime(context);
              },
              child: _buildQuietHoursWidget(
                  context, 'End Time', controller.quietHoursEndTimeController)),
        ],
      ),
    ];
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (controller.scheduleDirty.value) {
            logger.d("schedule is dirty");
            controller.handleScheduleDirty();
            controller.scheduleDirty.value = false;
          }
          return true;
        },
        child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Text('Configure schedule'),
            ),
            body: Center(
              child: Obx(() => Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Container(
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildScheduleView(context),
                          ),
                        ),
                        Container(
                            alignment: Alignment.topCenter,
                            child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: _buildQuietHoursView(context))),
                      ])),
            )));
  }
}
