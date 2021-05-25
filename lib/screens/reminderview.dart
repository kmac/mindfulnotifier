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
  // final reminderStringList = <String>[].obs;
  final reminders = Reminders([]).obs;
  final filteredReminderList = <Reminder>[].obs;
  final filteredReminderListDirty = false.obs;
  final selectedIndex = 0.obs;
  final selectedTag = ''.obs;
  final scrollToBottom = false.obs;
  final submitButtonEnabled = true.obs;
  final ScrollController scrollController = ScrollController();
  final Map<String, List<Reminder>> groupedReminders =
      <String, List<Reminder>>{}.obs;

  // UI event handlers, init code, etc goes here
  ReminderWidgetController();

  @override
  void onInit() {
    super.onInit();
    init();
  }

  @override
  void onReady() {
    //ever(reminderStringList, handleReminderList);
    ever(selectedIndex, handleSelectedIndex);
    ever(selectedTag, handleSelectedTag);
    ever(filteredReminderList, handleReminderList);
    ever(filteredReminderListDirty, handleReminderListDirty);
    ever(scrollToBottom, handleScrollToBottom);
    super.onReady();
  }

  Future<void> init() async {
    logger.d("init");

    // TODO mds is not up to date here after restore
    // TODO this is just temporary to display the reminders. The rest of this file needs to deal with the json formatted stuff.
    // InMemoryScheduleDataStore mds = Get.find();
    //List decodedReminderList = jsonDecode(mds.jsonReminders);
    //List<String> reminders = [];
    //for (Map mapEntry in decodedReminderList) {
    //  reminders.add(mapEntry['text']);
    //}
    // reminderStringList.assignAll(reminders);

    // TODO mds is not up to date here after restore
    InMemoryScheduleDataStore mds = Get.find();
    reminders.value = Reminders.fromJsonString(mds.jsonReminders);
    filteredReminderList.value =
        reminders.value.getFilteredReminderList(tag: selectedTag.value);
    groupedReminders.clear();
    groupedReminders.addAll(reminders.value.buildGroupedReminders());
  }

  void handleSelectedIndex(int index) async {
    logger.d("handleSelectedIndex: $index");
    // refresh();
  }

  void handleSelectedTag(String tag) async {
    logger.d("handleSelectedTag: $tag");
    init();
    // refresh();
  }

  void handleScrollToBottom(bool scroll) async {
    if (scrollToBottom.value) {
      logger.i("scrollToBottom");
      // WidgetsBinding.instance.addPostFrameCallback((_) =>
      //     scrollController.animateTo(scrollController.position.maxScrollExtent,
      //         duration: Duration(milliseconds: 200), curve: Curves.easeInOut));
      scrollController.animateTo(scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
      scrollToBottom.value = false;
    }
  }

  void handleReminderListDirty(dirty) async {
    InMemoryScheduleDataStore mds = Get.find();
    mds.jsonReminders = reminders.value.toJson();
    await init();
    filteredReminderListDirty.value = false;
    Get.find<MindfulNotifierWidgetController>()
        .sendToAlarmService({'update': mds});

    //   if (selectedTag.value == '') {
    //     // using allReminders
    //   } else {
    //     // rebuild using filtered

    //     for (Reminder reminder in reminders.value.allReminders) {}
    //   }

    //   InMemoryScheduleDataStore mds = Get.find();
    //   mds.jsonReminders = reminders.toJson();
  }

  void handleReminderList(changedReminderList) {
    if (false) {
      InMemoryScheduleDataStore mds = Get.find();

      // TODO THIS IS WRONG NOW
      mds.reminders = changedReminderList;

      Get.find<MindfulNotifierWidgetController>()
          .sendToAlarmService({'update': mds});
    }
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
                        Expanded(
                            child: DropdownSearch<String>(
                          mode: Mode.MENU,
                          showSelectedItem: true,
                          items: controller.groupedReminders.keys.toList(),
                          label: "Tag: ",
                          showClearButton: true,
                          onChanged: (value) {
                            controller.selectedTag.value =
                                value == null ? '' : value;
                          },
                        )),
                      ],
                    ),
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal)
                                      : TextStyle(
                                          fontSize: 16,
                                          // fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w300),
                                ),
                                trailing: controller
                                        .filteredReminderList[index].enabled
                                    ? null
                                    : Icon(Icons.alarm_off /*, size: 14*/),
                                leading: index == controller.selectedIndex.value
                                    ? Icon(Icons.keyboard_arrow_right)
                                    : null,
                                onTap: () {
                                  controller.selectedIndex.value = index;
                                  // _showEditDialog(context, index);
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
      TextEditingController editingController,
      final editedTag,
      final editedEnabled) {
    String label = editedTag.value;
    return Column(
      children: <Widget>[
        TextFormField(
          controller: editingController,
          maxLines: formMaxLines,
          maxLength: formMaxLength,
          // style: TextStyle(fontSize: 18),
        ),
        Row(children: <Widget>[
          Expanded(
              flex: 1, child: Text('Tag:', style: TextStyle(fontSize: 14))),
          Expanded(
              flex: 3,
              // IT DOESN'T LIKE THIS Obx:
              // child: Obx(() => TextField(
              child: TextField(
                decoration: InputDecoration(
                  // border: OutlineInputBorder(),
                  labelText: label,
                  // floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                // textAlign: TextAlign.center,
                autofillHints: controller.groupedReminders.keys.toList(),
                //onTap: () {
                //  controller.submitButtonEnabled.value = false;
                //},
                // onChanged: (value) {
                //   currentTag = value;
                // },
                // onEditingComplete: () {
                //   editedTag.value = currentTag;
                // },
                onSubmitted: (value) {
                  //  controller.submitButtonEnabled.value = true;
                  editedTag.value = value;
                },
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
    final editedTag = "default".obs;
    final editedEnabled = true.obs;

    TextEditingController editingController = new TextEditingController();
    DialogButton submitButton = DialogButton(
      onPressed: controller.submitButtonEnabled.value
          ? () {
              Reminder reminder = Reminder(
                  -1, // will be changed
                  editingController.text,
                  editedTag.value,
                  editedEnabled.value);
              controller.reminders.value.addReminder(reminder);
              controller.filteredReminderListDirty.value = true;

              controller.scrollToBottom.value = true;
              // _selectedIndex = controller.reminderList.length - 1;
              Navigator.pop(context);
            }
          : null,
      child: Text(
        "Add",
        style: getGlobalDialogTextStyle(Get.isDarkMode),
      ),
    );
    Alert(
        context: context,
        title: "Add Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: Obx(() => _buildAddEditColumn(
            context, editingController, editedTag, editedEnabled)),
        // content: _buildAddEditColumn(
        //     context, editingController, editedTag, editedEnabled),
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
          submitButton,
        ]).show();
  }

  void _showEditDialog(BuildContext context, int index) {
    final editedTag = controller.filteredReminderList[index].tag.obs;
    final editedText = controller.filteredReminderList[index].text.obs;
    final editedEnabled = controller.filteredReminderList[index].enabled.obs;

    TextEditingController editingController =
        new TextEditingController(text: editedText.value);
    DialogButton submitButton = DialogButton(
      onPressed: controller.submitButtonEnabled.value
          ? () {
              Reminder currentReminder = controller.filteredReminderList[index];
              Reminder reminder = Reminder(
                  currentReminder.index, // stays the same
                  editingController.text,
                  editedTag.value,
                  editedEnabled.value);
              controller.reminders.value.updateReminder(reminder);
              controller.filteredReminderListDirty.value = true;
              Navigator.pop(context);
            }
          : null,
      child: Text(
        "Save",
        style: getGlobalDialogTextStyle(Get.isDarkMode),
      ),
    );
    Alert(
        context: context,
        title: "Edit Reminder",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: Obx(() => _buildAddEditColumn(
            context, editingController, editedTag, editedEnabled)),
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
          submitButton,
        ]).show();
  }

  void _toggleEnabled(BuildContext context, int index) {
    Reminder currentReminder = controller.filteredReminderList[index];
    Reminder reminder = Reminder(
        currentReminder.index, // stays the same
        currentReminder.text,
        currentReminder.tag,
        currentReminder.enabled ? false : true);
    controller.reminders.value.updateReminder(reminder);
    logger.d("_toggleEnabled: $reminder");
    controller.filteredReminderListDirty.value = true;
  }

  void _showDeleteDialog(BuildContext context, int index) {
    Alert(
        context: context,
        title: "Delete Reminder?",
        style: getGlobalAlertStyle(Get.isDarkMode),
        content: Column(
          children: <Widget>[
            Text(controller.filteredReminderList[index].text,
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
              // controller.filteredReminderList.removeAt(index);
              controller.reminders.value
                  .deleteReminder(controller.filteredReminderList[index].index);
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

// DISMISSABLE:
// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//       appBar: AppBar(
//         centerTitle: true,
//         title: Text('Configure Reminders'),
//       ),
//       body: Center(
//           child: Obx(() => ListView.builder(
//                 itemCount: controller.reminderList.length,
//                 itemBuilder: (context, index) {
//                   return Dismissible(
//                     // Show a red background as the item is swiped away.
//                     background: Container(color: Colors.red),
//                     // Each Dismissible must contain a Key. Keys allow Flutter to
//                     // uniquely identify widgets.
//                     key: Key(controller.reminderList[index]),
//                     // Provide a function that tells the app
//                     // what to do after an item has been swiped away.
//                     onDismissed: (direction) {
//                       { direction == DismissDirection.endToStart ? _.${2:remove}() : _.${3:edit}() }
//                       // Remove the item from the data source.
//                       // setState(() {
//                       //   items.removeAt(index);
//                       // }
//                       //  );

//                       // Show a snackbar. This snackbar could also contain "Undo" actions.
//                       Scaffold.of(context).showSnackBar(SnackBar(
//                           content: Text(
//                               "${controller.reminderList[index]} dismissed")));
//                     },
//                     child: ListTile(
//                         title: Text('${controller.reminderList[index]}')),
//                   );
//                 },
//               ))));
// }

//           ListView.builder(
//                 itemCount: 10,
//                 itemBuilder: (BuildContext context, int index) {
//                   return ListTile(
//                     title: Text('Item $index'),
//                     selected: index == _selectedIndex,
//                     onTap: () {
//                       controller.reminderList[_selectedIndex] =
//                       // setState(() {
//                       //   _selectedIndex = index;
//                       // });
//                     },
//                   );
//                 },
//               ))));
// }
