import 'dart:ui';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'package:rflutter_alert/rflutter_alert.dart';

import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/reminders.dart';

var logger = Logger(printer: SimpleLogPrinter('reminderview'));

class ReminderWidgetController extends GetxController {
  Reminders _reminders;

  final reminderList = <String>[].obs;
  final needToScroll = false.obs;
  final ScrollController scrollController = ScrollController();

  // UI event handlers, init code, etc goes here
  ReminderWidgetController() {
    // init();
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
    _reminders = await Reminders.create();
    reminderList.assignAll(_reminders.reminders);
    ever(reminderList, handleReminderList);
    ever(needToScroll, handleNeedToScroll);
  }

  void handleNeedToScroll(bool scroll) async {
    if (needToScroll.value) {
      logger.i("needToScroll");
      // WidgetsBinding.instance.addPostFrameCallback((_) =>
      //     scrollController.animateTo(scrollController.position.maxScrollExtent,
      //         duration: Duration(milliseconds: 200), curve: Curves.easeInOut));
      scrollController.animateTo(scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200), curve: Curves.easeInOut);
      needToScroll.value = false;
    }
  }

  void handleReminderList(changedReminderList) {
    _reminders.reminders = changedReminderList;
    _reminders.persist();
  }
}

class ReminderWidget extends StatelessWidget {
  final ReminderWidgetController controller =
      Get.put(ReminderWidgetController());

  // int _selectedIndex = 0;
  final formMaxLines = 7;
  final formMaxLength = 256;

  void _showAddDialog(BuildContext context) {
    TextEditingController editingController = new TextEditingController();
    Alert(
        context: context,
        title: "Add Reminder",
        content: Column(
          children: <Widget>[
            TextFormField(
              controller: editingController,
              maxLines: formMaxLines,
              maxLength: formMaxLength,
            ),
          ],
        ),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Cancel",
              style: TextStyle(color: Colors.white),
            ),
          ),
          DialogButton(
            onPressed: () {
              controller.reminderList.add(editingController.text);
              controller.needToScroll.value = true;
              // _selectedIndex = controller.reminderList.length - 1;
              Navigator.pop(context);
              // HOW TO SHOW A SNACKBAR HERE
              // Scaffold.of(context).showSnackBar(
              //     SnackBar(content: Text("Added reminder")));
            },
            child: Text(
              "Add",
              style: TextStyle(color: Colors.white),
            ),
          )
        ]).show();
  }

  void _showEditDialog(BuildContext context, int index) {
    TextEditingController editingController =
        new TextEditingController(text: controller.reminderList[index]);
    Alert(
        context: context,
        title: "Edit Reminder",
        content: Column(
          children: <Widget>[
            TextFormField(
              controller: editingController,
              maxLines: formMaxLines,
              maxLength: formMaxLength,
            ),
          ],
        ),
        buttons: [
          DialogButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Cancel",
              // style: TextStyle(color: Colors.white, fontSize: 20),
              style: TextStyle(color: Colors.white),
            ),
          ),
          DialogButton(
            onPressed: () {
              controller.reminderList[index] = editingController.text;
              Navigator.pop(context);
              // HOW TO SHOW A SNACKBAR HERE
              // Scaffold.of(context).showSnackBar(
              //     SnackBar(content: Text("Added reminder")));
            },
            child: Text(
              "Save",
              // style: TextStyle(color: Colors.white, fontSize: 20),
              style: TextStyle(color: Colors.white),
            ),
          )
        ]).show();
  }

  void _showDeleteDialog(BuildContext context, int index) {
    Alert(
        context: context,
        title: "Delete Reminder?",
        content: Column(
          children: <Widget>[
            Text(controller.reminderList[index],
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
              style: TextStyle(color: Colors.white),
            ),
          ),
          DialogButton(
            onPressed: () {
              controller.reminderList.removeAt(index);
              Navigator.pop(context);
              // HOW TO SHOW A SNACKBAR HERE
              // Scaffold.of(context).showSnackBar(
              //     SnackBar(content: Text("Added reminder")));
            },
            child: Text(
              "Delete",
              style: TextStyle(color: Colors.white),
            ),
          )
        ]).show();
  }

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
              Text('Tap to edit. Long-press to delete.',
                  style: TextStyle(
                    fontSize: 12.0,
                  )),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () {
              _showAddDialog(context);
            }),
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        body: Center(
            child: Obx(() => ListView.builder(
                  itemCount: controller.reminderList.length,
                  controller: controller.scrollController,
                  itemBuilder: (context, index) {
                    return Card(
                        child: ListTile(
                            title: Text('${controller.reminderList[index]}'),
                            trailing: Icon(Icons.keyboard_arrow_right),
                            onTap: () {
                              _showEditDialog(context, index);
                            },
                            onLongPress: () {
                              _showDeleteDialog(context, index);
                            }));
                  },
                ))));
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
