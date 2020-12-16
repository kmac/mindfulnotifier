import 'dart:ui';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:logger/logger.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';

var logger = Logger(printer: SimpleLogPrinter('schedulesview'));

enum ScheduleType { periodic, random }

class SchedulesWidgetController extends GetxController {
  ScheduleDataStore ds;
  final scheduleType = ScheduleType.periodic.obs;
  final periodicHours = 1.obs;
  final periodicMinutes = 0.obs;
  final randomMinDateTime = DateTime.parse("1970-01-01 00:45:00Z").obs;
  final randomMaxDateTime = DateTime.parse("1970-01-01 01:30:00Z").obs;
  final scheduleDirty = false.obs;
  final quietHoursStartPicked = TimeOfDay(hour: 1, minute: 0).obs;
  final quietHoursEndPicked = TimeOfDay(hour: 1, minute: 0).obs;

  TextEditingController quietHoursStartTimeController = TextEditingController();
  TextEditingController quietHoursEndTimeController = TextEditingController();

  // UI event handlers, init code, etc goes here
  SchedulesWidgetController();

  DateTime _getDateTime(int hours, int minutes) {
    return DateTime.parse(
        "1970-01-01 ${timeNumToString(hours)}:${timeNumToString(minutes)}:00Z");
  }

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
    randomMinDateTime.value =
        _getDateTime(ds.randomMinHours, ds.randomMinMinutes);
    randomMaxDateTime.value =
        _getDateTime(ds.randomMaxHours, ds.randomMaxMinutes);

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
    ever(randomMinDateTime, handleRandomMinDateTime);
    ever(randomMaxDateTime, handleRandomMaxDateTime);
    ever(quietHoursStartPicked, handleQuietHoursStartPicked);
    ever(quietHoursEndPicked, handleQuietHoursEndPicked);
  }

  void handleScheduleType(ScheduleType t) {
    if (t == ScheduleType.periodic) {
      ds.scheduleTypeStr = 'periodic';
    } else {
      ds.scheduleTypeStr = 'random';
    }
    scheduleDirty.value = true;
  }

  void handlePeriodicHours(int hours) {
    ds.periodicHours = hours;
    if (hours > 0) {
      periodicMinutes.value = 0;
    } else if (periodicMinutes.value < 15) {
      periodicMinutes.value = 15;
    }
    scheduleDirty.value = true;
  }

  void handlePeriodicMinutes(int minutes) {
    ds.periodicMinutes = minutes;
    scheduleDirty.value = true;
  }

  void handleRandomMinDateTime(DateTime time) {
    ds.randomMinHours = time.hour;
    ds.randomMinMinutes = time.minute;
    if (randomMaxDateTime.value.isBefore(time)) {
      randomMaxDateTime.value = time.add(Duration(minutes: 15));
    }
    scheduleDirty.value = true;
  }

  void handleRandomMaxDateTime(DateTime time) {
    ds.randomMaxHours = time.hour;
    ds.randomMaxMinutes = time.minute;
    if (randomMinDateTime.value.isAfter(time)) {
      randomMinDateTime.value = time.subtract(Duration(minutes: 15));
    }
    scheduleDirty.value = true;
  }

  void handleScheduleDirty() {
    logger.d("handleScheduleDirty");
    Get.find<MindfulNotifierWidgetController>().triggerSchedulerRestart();
  }

  void handleQuietHoursStartPicked(TimeOfDay time) {
    ds.quietHoursStartHour = time.hour;
    ds.quietHoursStartMinute = time.minute;
    quietHoursStartTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    scheduleDirty.value = true;
  }

  void handleQuietHoursEndPicked(TimeOfDay time) {
    quietHoursEndTimeController.text =
        formatHHMM(DateTime(2020, 01, 1, time.hour, time.minute));
    ds.quietHoursEndHour = time.hour;
    ds.quietHoursEndMinute = time.minute;
    scheduleDirty.value = true;
  }
}

class SchedulesWidget extends StatelessWidget {
  final SchedulesWidgetController controller =
      Get.put(SchedulesWidgetController());

  DropdownButton<int> _buildDropDown(
      int dropdownValue, List<int> allowedValues, Function onChangedFunc,
      [bool useTwoDigits = false]) {
    return DropdownButton<int>(
      value: dropdownValue,
      // icon: Icon(Icons.arrow_downward),
      // iconSize: 24,
      elevation: 16,
      // style: TextStyle(color: Colors.deepPurple, fontSize: 20),
      style: TextStyle(color: Colors.black54, fontSize: 30),
      underline: Container(height: 2, color: Colors.black54
          // color: Colors.deepPurpleAccent,
          ),
      onChanged: onChangedFunc,
      items: allowedValues.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(useTwoDigits ? timeNumToString(value) : value.toString()),
        );
      })?.toList(),
    );
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
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                width: 200,
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    new Column(
                      children: [
                        Text('Hours'),
                        _buildDropDown(
                            controller.periodicHours.value,
                            [0, 1, 2, 3, 4, 8, 12],
                            (value) => controller.periodicHours.value = value,
                            true),
                      ],
                    ),
                    Text(' : '),
                    new Column(
                      children: [
                        Text('Minutes'),
                        _buildDropDown(
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
      widgets.add(new Center(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                child: new Column(
                  children: <Widget>[
                    Text('Minimum Delay',
                        style: Theme.of(context).textTheme.bodyText1),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: controller.randomMinDateTime.value,
                      is24HourMode: true,
                      spacing: 20,
                      minutesInterval: 5,
                      onTimeChange: (value) =>
                          controller.randomMinDateTime.value = value,
                    ),
                  ],
                )),
            new Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                child: new Column(
                  children: <Widget>[
                    Text('Maximum Delay',
                        style: Theme.of(context).textTheme.bodyText1),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: controller.randomMaxDateTime.value,
                      // spacing: 10,
                      minutesInterval: 5,
                      onTimeChange: (value) =>
                          controller.randomMaxDateTime.value = value,
                    ),
                  ],
                )),
          ],
        ),
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
              child: Container(
                  width: 140,
                  margin: EdgeInsets.only(top: 30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: TextFormField(
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                    enabled: false,
                    keyboardType: TextInputType.text,
                    controller: controller.quietHoursStartTimeController,
                    decoration: InputDecoration(
                        disabledBorder:
                            UnderlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'Start Time',
                        contentPadding: EdgeInsets.all(5)),
                  ))),
          Text('to: '),
          InkWell(
              onTap: () {
                _selectQuietHoursEndTime(context);
              },
              child: Container(
                  width: 140,
                  // height: _height / 9,
                  margin: EdgeInsets.only(top: 30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: TextFormField(
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                    enabled: false,
                    keyboardType: TextInputType.text,
                    controller: controller.quietHoursEndTimeController,
                    decoration: InputDecoration(
                        disabledBorder:
                            UnderlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'End Time',
                        contentPadding: EdgeInsets.all(5)),
                  ))),
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
