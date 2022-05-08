// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
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
    // onInit: is called immediately after the widget is allocated memory.
    _updateReminders();

    super.onInit();
  }

  @override
  void onReady() {
    // onReady: is called immediately after the widget is rendered on screen.
    ever(selectedIndex, handleSelectedIndex);
    ever(selectedTag, handleSelectedTag);
    // ever(filteredReminderList, handleReminderList);
    ever(filteredReminderListDirty, handleReminderListDirty);

    super.onReady();
  }

  void _updateReminders() {
    // TODO mds is not up to date here after import? Not sure - this may be fine now
    logger.d("_updateReminders");
    InMemoryScheduleDataStore mds = Get.find();
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
    _updateReminders();
    filteredReminderListDirty.value = false;

    // update alarm service with new memory store
    Get.find<MindfulNotifierWidgetController>().updatePermanentDataStore(mds);
  }
}

class ReminderWidget extends StatelessWidget {
  final ReminderWidgetController controller =
      Get.put(ReminderWidgetController());

  final formMaxLines = 10;
  final formMaxLength = Reminder.maxLength;

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
            children: <Widget>[
              Text(
                'Configure Reminders',
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
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
            BottomNavigationBarItem(
              icon: Icon(Icons.add),
              label: "Add",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.edit),
              label: "Edit",
            ),
            BottomNavigationBarItem(
              // icon: Icon(Icons.play_disabled),
              icon: Icon(Icons.timer_off),
              label: "Toggle",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.delete),
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
                                  showSelectedItems: true,
                                  items:
                                      controller.groupedReminders.keys.toList()
                                        ..sort(),
                                  dropdownSearchDecoration: InputDecoration(
                                    hintText: "Select tag:",
                                    labelText: "Filter by tag:",
                                    contentPadding:
                                        EdgeInsets.fromLTRB(12, 12, 0, 0),
                                    border: OutlineInputBorder(),
                                  ),
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
                                                          FontStyle.normal),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                ))
                                          ])
                                    : null,
                                selected:
                                    index == controller.selectedIndex.value,
                                title: Text(
                                  controller
                                      .filteredReminderList[index].truncated,
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
    List<String> sortedTags = controller.groupedReminders.keys.toList()..sort();
    return Column(
      children: <Widget>[
        Scrollbar(
            child: TextFormField(
          keyboardType: TextInputType.multiline,
          controller: editingControllerText,
          minLines: formMaxLines ~/ 2 + 1,
          maxLines: formMaxLines,
          maxLength: formMaxLength,
          // style: TextStyle(fontSize: 18),
        )),
        Row(children: <Widget>[
          Expanded(
              child: Text('Tag (Select / Edit / Create New):',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        ]),
        Row(children: <Widget>[
          DropdownButton<String>(
              items: [
                for (var tag in sortedTags)
                  DropdownMenuItem(
                    value: tag,
                    child: Text(
                      tag,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
              ],
              style: TextStyle(fontSize: 14),
              isDense: true,
              // isExpanded: true,
              onChanged: (String value) {
                editingControllerTag.text = value;
              },
              hint: Text("Select existing")),
          Expanded(
              // flex: 6,
              // TODO need to call dispose on TextFormField!!
              child: TextFormField(
            controller: editingControllerTag,
            maxLines: 1,
            maxLength: 32,
            // initialValue: null,
            autofillHints: sortedTags,
            // style: TextStyle(fontSize: 14),
            enableInteractiveSelection: true,
            textAlign: TextAlign.center,
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
    TextEditingController editingControllerText = TextEditingController();
    TextEditingController editingControllerTag = TextEditingController(
        text: controller.selectedTag.value != ''
            ? controller.selectedTag.value
            : Reminder.defaultCustomTagName);
    Alert(
        context: context,
        title: "Add Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode,
            alertPadding: EdgeInsets.all(4.0)),
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
        TextEditingController(text: editedText.value);
    TextEditingController editingControllerTag = TextEditingController(
        text: controller.filteredReminderList[filterIndex].tag);
    Alert(
        context: context,
        title: "Edit Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode,
            alertPadding: EdgeInsets.all(4.0)),
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
        style: getGlobalAlertStyle(Get.isDarkMode,
            alertPadding: EdgeInsets.all(4.0)),
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
