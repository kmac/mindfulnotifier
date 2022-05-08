// ignore_for_file: prefer_const_constructors

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';

var logger = createLogger('schedulesview');

enum ScheduleType { periodic, random }

class SchedulesWidgetController extends GetxController {
  final scheduleType = ScheduleType.periodic.obs;
  final periodicHours = 1.obs;
  final periodicMinutes = 0.obs;
  final randomMinMinutes = 60.obs;
  final randomMaxMinutes = 90.obs;
  final scheduleDirty = false.obs;
  final quietHoursStartPicked = TimeOfDay(hour: 1, minute: 0).obs;
  final quietHoursEndPicked = TimeOfDay(hour: 1, minute: 0).obs;

  int trackRandomMinMinutes;
  int trackRandomMaxMinutes;

  TextEditingController randomMinMinutesController = TextEditingController();
  TextEditingController randomMaxMinutesController = TextEditingController();
  TextEditingController quietHoursStartTimeController = TextEditingController();
  TextEditingController quietHoursEndTimeController = TextEditingController();

  // UI event handlers, init code, etc goes here
  SchedulesWidgetController();

  @override
  void onInit() {
    // onInit: is called immediately after the widget is allocated memory.
    logger.d("onInit");

    InMemoryScheduleDataStore mds = Get.find();

    if (mds.scheduleTypeStr == 'periodic') {
      scheduleType.value = ScheduleType.periodic;
    } else {
      scheduleType.value = ScheduleType.random;
    }

    periodicHours.value = mds.periodicHours;
    periodicMinutes.value = mds.periodicMinutes;

    randomMaxMinutes.value = mds.randomMaxMinutes;
    trackRandomMaxMinutes = mds.randomMaxMinutes;
    randomMinMinutes.value = mds.randomMaxMinutes;
    trackRandomMinMinutes = mds.randomMinMinutes;
    randomMinMinutesController.text = "${mds.randomMinMinutes}";
    randomMaxMinutesController.text = "${mds.randomMaxMinutes}";

    quietHoursStartPicked.value = TimeOfDay(
        hour: mds.quietHoursStartHour, minute: mds.quietHoursStartMinute);
    quietHoursEndPicked.value =
        TimeOfDay(hour: mds.quietHoursEndHour, minute: mds.quietHoursEndMinute);
    quietHoursStartTimeController.text = formatHHMM(DateTime(
        2020, 01, 1, mds.quietHoursStartHour, mds.quietHoursStartMinute));
    quietHoursEndTimeController.text = formatHHMM(
        DateTime(2020, 01, 1, mds.quietHoursEndHour, mds.quietHoursEndMinute));

    super.onInit();
  }

  @override
  void onReady() {
    // onReady: is called immediately after the widget is rendered on screen.
    ever(scheduleType, handleScheduleType);
    ever(periodicHours, handlePeriodicHours);
    ever(periodicMinutes, handlePeriodicMinutes);
    ever(quietHoursStartPicked, handleQuietHoursStartPicked);
    ever(quietHoursEndPicked, handleQuietHoursEndPicked);

    super.onReady();
  }

  void handleScheduleType(ScheduleType t) {
    InMemoryScheduleDataStore mds = Get.find();
    if (t == ScheduleType.periodic) {
      if (mds.scheduleTypeStr != 'periodic') {
        mds.scheduleTypeStr = 'periodic';
        scheduleDirty.value = true;
      }
    } else {
      if (mds.scheduleTypeStr != 'random') {
        mds.scheduleTypeStr = 'random';
        scheduleDirty.value = true;
      }
    }
  }

  void handlePeriodicHours(int hours) {
    InMemoryScheduleDataStore mds = Get.find();
    if (mds.periodicHours != hours) {
      mds.periodicHours = hours;
      scheduleDirty.value = true;
    }
  }

  void handlePeriodicMinutes(int minutes) {
    InMemoryScheduleDataStore mds = Get.find();
    if (mds.periodicMinutes != minutes) {
      mds.periodicMinutes = minutes;
      scheduleDirty.value = true;
    }
  }

  void trackRandomValChange(String textval, String labelText) {
    int newval = int.tryParse(textval);
    if (newval != null) {
      logger.d("trackRandomValChange $labelText minutes: $textval");
      if (labelText == 'Maximum') {
        trackRandomMaxMinutes = newval;
      } else {
        trackRandomMinMinutes = newval;
      }
    }
  }

  void handleRandomValSubmit() {
    logger.d("handleRandomValSubmit min: $trackRandomMinMinutes "
        "max: $trackRandomMaxMinutes");
    InMemoryScheduleDataStore mds = Get.find();
    if (trackRandomMinMinutes > trackRandomMaxMinutes) {
      trackRandomMaxMinutes = trackRandomMinMinutes;
    }
    if (trackRandomMaxMinutes < trackRandomMinMinutes) {
      trackRandomMaxMinutes = trackRandomMinMinutes;
    }
    if (trackRandomMinMinutes != mds.randomMinMinutes) {
      randomMinMinutes.value = trackRandomMinMinutes;
      randomMinMinutesController.text = "${randomMinMinutes.value}";
      mds.randomMinMinutes = trackRandomMinMinutes;
      scheduleDirty.value = true;
    }
    if (trackRandomMaxMinutes != mds.randomMaxMinutes) {
      randomMaxMinutes.value = trackRandomMaxMinutes;
      randomMaxMinutesController.text = "${randomMaxMinutes.value}";
      mds.randomMaxMinutes = trackRandomMaxMinutes;
      scheduleDirty.value = true;
    }
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    InMemoryScheduleDataStore mds = Get.find();

    // Set nextAlarm to '' in order to reset the scheduler on restart
    mds.nextAlarm = '';

    Get.find<MindfulNotifierWidgetController>().triggerSchedulerRestart(
        mds: mds, reason: "Configuration changed, restarting the notifier.");
    scheduleDirty.value = false;
  }

  void handleQuietHoursStartPicked(TimeOfDay time) {
    InMemoryScheduleDataStore mds = Get.find();
    quietHoursStartTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    if (mds.quietHoursStartHour != time.hour ||
        mds.quietHoursStartMinute != time.minute) {
      mds.quietHoursStartHour = time.hour;
      mds.quietHoursStartMinute = time.minute;
      scheduleDirty.value = true;
    }
  }

  void handleQuietHoursEndPicked(TimeOfDay time) {
    InMemoryScheduleDataStore mds = Get.find();
    quietHoursEndTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    if (mds.quietHoursEndHour != time.hour ||
        mds.quietHoursEndMinute != time.minute) {
      mds.quietHoursEndHour = time.hour;
      mds.quietHoursEndMinute = time.minute;
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
      var context, String labelText, var textController) {
    return SizedBox(
        // height: 80,
        width: 120,
        child: Container(
            decoration: Get.isDarkMode
                ? BoxDecoration(color: Theme.of(context).backgroundColor)
                : BoxDecoration(color: Colors.grey[200]),
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
              onChanged: (textval) {
                logger.d("onChanged $labelText minutes, value=$textval");
                controller.trackRandomValChange(textval, labelText);
              },
              onSubmitted: (textval) {
                logger.d("onSubmitted $labelText minutes, value=$textval");
                controller.handleRandomValSubmit();
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
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
                // padding: EdgeInsets.all(24.0),
                padding: EdgeInsets.fromLTRB(30, 0, 30, 20),
                child: Text(
                    'Choose the reminder period. '
                    'Reminders are aligned to the top of hour, '
                    'unless the period is shorter than one hour, in which'
                    ' case the granularity is 15 minutes.',
                    style: TextStyle(
                      fontWeight: FontWeight.w300, /*fontSize: 12*/
                    ),
                    softWrap: true)),
            Container(
                decoration: Get.isDarkMode
                    ? BoxDecoration(color: Theme.of(context).backgroundColor)
                    : BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                width: 200,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
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
                    Column(
                      children: [
                        Text(
                          'Minutes',
                          style: Theme.of(context).textTheme.subtitle1,
                        ),
                        _buildDropDown(
                            context,
                            controller.periodicMinutes.value,
                            List<int>.generate(60, (i) => i),
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
        Column(children: <Widget>[
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
                    context, 'Minimum', controller.randomMinMinutesController),
                // Text('to'),
                _buildRandomMinutesWidget(
                    context, 'Maximum', controller.randomMaxMinutesController),
              ]),
        ]),
      );
    }
    return widgets;
  }

  Future<void> _selectQuietHoursStartTime(BuildContext context) async {
    InMemoryScheduleDataStore mds = Get.find();
    var selectedTime = TimeOfDay(
        hour: mds.quietHoursStartHour, minute: mds.quietHoursStartMinute);
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      selectedTime = picked;
      controller.quietHoursStartPicked.value = picked;
    }
  }

  Future<void> _selectQuietHoursEndTime(BuildContext context) async {
    InMemoryScheduleDataStore mds = Get.find();
    var selectedTime =
        TimeOfDay(hour: mds.quietHoursEndHour, minute: mds.quietHoursEndMinute);
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
        decoration: Get.isDarkMode
            ? BoxDecoration(color: Theme.of(context).backgroundColor)
            : BoxDecoration(color: Colors.grey[200]),
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
      Row(
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
