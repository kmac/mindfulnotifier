import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'package:rflutter_alert/rflutter_alert.dart';

import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/screens/mindfulnotifier.dart';

var logger = createLogger('reminderview');

class ReminderWidgetController extends GetxController {
  final reminders = Reminders.empty().obs;
  final filteredReminderList = <Reminder>[].obs;
  final filteredReminderListDirty = false.obs;
  final selectedIndex = 0.obs;
  final selectedTag = ''.obs;
  final ScrollController scrollController = ScrollController();
  final Map<String, List<Reminder>> groupedReminders =
      <String, List<Reminder>>{}.obs;

  // UI event handlers, init code, etc goes here
  ReminderWidgetController();

  @override
  void onInit() {
    super.onInit();
    _updateReminders();
  }

  @override
  void onReady() {
    ever(selectedIndex, handleSelectedIndex);
    ever(selectedTag, handleSelectedTag);
    // ever(filteredReminderList, handleReminderList);
    ever(filteredReminderListDirty, handleReminderListDirty);
    super.onReady();
  }

  void _updateReminders({InMemoryScheduleDataStore mds}) {
    // TODO mds is not up to date here after import? Not sure - this may be fine now
    mds ??= Get.find();
    logger.d("_updateReminders");
    reminders.value = Reminders.fromJson(mds.jsonReminders);

    // NOTE: the index for filteredReminderList.value is different from the allReminders index!
    filteredReminderList.value = reminders.value
        .getFilteredReminderList(tag: selectedTag.value, sorted: true);
    groupedReminders.clear();
    groupedReminders.addAll(reminders.value.buildGroupedReminders());
  }

  void handleSelectedIndex(int index) async {
    logger.d("handleSelectedIndex: $index");
  }

  void handleSelectedTag(String tag) async {
    logger.d("handleSelectedTag: $tag");
    _updateReminders();
  }

  void handleReminderListDirty(dirty) async {
    // write to memory store
    InMemoryScheduleDataStore mds = Get.find();
    mds.jsonReminders = reminders.value.toJson();
    _updateReminders(mds: mds);
    filteredReminderListDirty.value = false;

    // update alarm service with new memory store:
    Get.find<MindfulNotifierWidgetController>()
        .sendToAlarmService({'update': mds});
  }
}

class ReminderWidget extends StatelessWidget {
  final ReminderWidgetController controller =
      Get.put(ReminderWidgetController());

  final formMaxLines = 7;
  final formMaxLength = 256;

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
                'Configure Reminders',
              ),
            ],
          ),
        ),
        bottomNavigationBar: new BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            switch (index) {
              case 0:
                // handle add
                _showAddDialog(context);
                break;
              case 1:
                // handle edit
                _showEditDialog(context, controller.selectedIndex.value);
                break;
              case 2:
                // handle toggle
                _toggleEnabled(context, controller.selectedIndex.value);
                break;
              case 3:
                // handle delete
                _showDeleteDialog(context, controller.selectedIndex.value);
                break;
            }
          },
          items: [
            new BottomNavigationBarItem(
              icon: new Icon(Icons.add),
              label: "Add",
            ),
            new BottomNavigationBarItem(
              icon: new Icon(Icons.edit),
              label: "Edit",
            ),
            new BottomNavigationBarItem(
              // icon: new Icon(Icons.play_disabled),
              icon: new Icon(Icons.timer_off),
              label: "Toggle",
            ),
            new BottomNavigationBarItem(
              icon: new Icon(Icons.delete),
              label: "Delete",
            ),
          ],
        ),
        body: Center(
            child: Obx(() => Column(
                  children: <Widget>[
                    Row(
                      children: [
                        /*controller.groupedReminders.length <= 1
                            ? Container()
                            :*/
                        Expanded(
                            child: Container(
                                padding: EdgeInsets.all(8),
                                margin: EdgeInsets.only(top: 8, bottom: 8),
                                child: DropdownSearch<String>(
                                  mode: Mode.MENU,
                                  showSelectedItem: true,
                                  items:
                                      controller.groupedReminders.keys.toList()
                                        ..sort(),
                                  label: "Filter by tag: ",
                                  hint: "Select tag:",
                                  showClearButton: true,
                                  onChanged: (value) {
                                    controller.selectedTag.value =
                                        value == null ? '' : value;
                                    // reset the selectedIndex
                                    controller.selectedIndex.value = 0;
                                  },
                                ))),
                        // Text('Hide Disabled: ', style: TextStyle(fontSize: 12)),
                        // Obx(
                        //   () => Checkbox(
                        //       value: controller.hideDisabled.value,
                        //       onChanged: (value) {
                        //         // logger.d("Enabled onChanged value: $value");
                        //         controller.hideDisabled.value = value;
                        //       }),
                        // )
                      ],
                    ),
                    //Divider(),
                    Expanded(
                        child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: controller.filteredReminderList.length,
                      controller: controller.scrollController,
                      itemBuilder: (context, index) {
                        return Card(
                            child: Obx(() => ListTile(
                                // isThreeLine: controller.selectedTag.value == '',
                                isThreeLine: false,
                                subtitle: controller.groupedReminders.length >
                                            1 &&
                                        (controller.selectedTag.value == '' ||
                                            controller.selectedTag.value ==
                                                null)
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                            OutlinedButton(
                                                child: Text(controller
                                                    .filteredReminderList[index]
                                                    .tag),
                                                onPressed: () => {
                                                      controller.selectedIndex
                                                          .value = index
                                                    },
                                                style: OutlinedButton.styleFrom(
                                                  textStyle: TextStyle(
                                                      fontStyle:
                                                          FontStyle.italic),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ))
                                          ])
                                    : null,
                                selected:
                                    index == controller.selectedIndex.value,
                                title: Text(
                                  '${controller.filteredReminderList[index].text}',
                                  style: controller
                                          .filteredReminderList[index].enabled
                                      ? TextStyle(
                                          // fontSize: 16,
                                          fontWeight: FontWeight.normal)
                                      : TextStyle(
                                          // fontSize: 16,
                                          // fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w300),
                                ),
                                leading: index == controller.selectedIndex.value
                                    //? Icon(Icons.keyboard_arrow_right)
                                    ? Icon(Icons.arrow_right)
                                    : null,
                                trailing: controller
                                        .filteredReminderList[index].enabled
                                    ? null
                                    : Icon(Icons.alarm_off /*, size: 14*/),
                                // : Icon(Icons.no_accounts /*, size: 14*/),
                                // : Icon(Icons.voice_over_off /*, size: 14*/),
                                onTap: () {
                                  controller.selectedIndex.value = index;
                                },
                                onLongPress: () {
                                  controller.selectedIndex.value = index;
                                  _showEditDialog(context, index);
                                  // _toggleEnabled(context, index);
                                })));
                      },
                    ))
                  ],
                ))));
  }

  Column _buildAddEditColumn(
      BuildContext context,
      TextEditingController editingControllerText,
      TextEditingController editingControllerTag,
      final editedEnabled) {
    return Column(
      children: <Widget>[
        TextFormField(
          controller: editingControllerText,
          maxLines: formMaxLines,
          maxLength: formMaxLength,
          // style: TextStyle(fontSize: 18),
        ),
        Row(children: <Widget>[
          Expanded(
              flex: 1, child: Text('Tag:', style: TextStyle(fontSize: 14))),
          Expanded(
              flex: 3,
              child: TextFormField(
                controller: editingControllerTag,
                maxLines: 1,
                maxLength: 32,
                // style: TextStyle(fontSize: 18),
              )),
        ]),
        Row(children: <Widget>[
          Text('Enabled: ', style: TextStyle(fontSize: 14)),
          Obx(
            () => Checkbox(
                value: editedEnabled.value,
                onChanged: (value) {
                  // logger.d("Enabled onChanged value: $value");
                  editedEnabled.value = value;
                }),
          )
        ]),
      ],
    );
  }

  void _showAddDialog(BuildContext context) {
    final editedEnabled = true.obs;
    TextEditingController editingControllerText = new TextEditingController();
    TextEditingController editingControllerTag = new TextEditingController(
        text: controller.selectedTag.value != ''
            ? controller.selectedTag.value
            : customTag);
    Alert(
        context: context,
        title: "Add Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: _buildAddEditColumn(context, editingControllerText,
            editingControllerTag, editedEnabled),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Cancel",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          ),
          DialogButton(
            onPressed: () {
              Reminder reminder = Reminder(editingControllerText.text,
                  editingControllerTag.text, editedEnabled.value);
              controller.reminders.value.addReminder(reminder);
              controller.filteredReminderListDirty.value = true;
              Navigator.pop(context);
            },
            child: Text(
              "Add",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          )
        ]).show();
  }

  void _showEditDialog(BuildContext context, int filterIndex) {
    final editedText = controller.filteredReminderList[filterIndex].text.obs;
    final editedEnabled =
        controller.filteredReminderList[filterIndex].enabled.obs;
    final reminderIndex = controller.reminders.value.findReminderIndexByText(
        controller.filteredReminderList[filterIndex].text);

    TextEditingController editingControllerText =
        new TextEditingController(text: editedText.value);
    TextEditingController editingControllerTag = new TextEditingController(
        text: controller.filteredReminderList[filterIndex].tag);
    Alert(
        context: context,
        title: "Edit Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: _buildAddEditColumn(context, editingControllerText,
            editingControllerTag, editedEnabled),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Cancel",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          ),
          DialogButton(
            onPressed: () {
              Reminder reminder = Reminder(editingControllerText.text,
                  editingControllerTag.text, editedEnabled.value);
              controller.reminders.value
                  .updateReminder(reminderIndex, reminder);
              controller.filteredReminderListDirty.value = true;
              Navigator.pop(context);
            },
            child: Text(
              "Save",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          )
        ]).show();
  }

  void _toggleEnabled(BuildContext context, int filterIndex) {
    Reminder currentReminder = controller.filteredReminderList[filterIndex];
    int currentReminderIndex =
        controller.reminders.value.findReminderIndex(currentReminder);
    Reminder reminder = Reminder(currentReminder.text, currentReminder.tag,
        currentReminder.enabled ? false : true);
    controller.reminders.value.updateReminder(currentReminderIndex, reminder);
    controller.filteredReminderListDirty.value = true;
  }

  void _showDeleteDialog(BuildContext context, int filterIndex) {
    Reminder reminder = controller.filteredReminderList[filterIndex];
    Alert(
        context: context,
        title: "Delete Reminder?",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: Column(
          children: <Widget>[
            Text(reminder.text,
                maxLines: 10,
                style: TextStyle(
                    fontSize: 12.0,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal)),
          ],
        ),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Cancel",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          ),
          DialogButton(
            onPressed: () {
              controller.reminders.value.deleteReminder(reminder);
              controller.filteredReminderListDirty.value = true;
              Navigator.pop(context);
            },
            child: Text(
              "Delete",
              style: getGlobalDialogTextStyle(Get.isDarkMode),
            ),
          )
        ]).show();
  }
}
