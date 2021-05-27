import 'dart:isolate';

import 'package:device_info/device_info.dart';
import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

AndroidBuildVersion _cachedBbuildVersion;

String getCurrentIsolate() {
  return "I:${Isolate.current.hashCode}";
}

Future<AndroidBuildVersion> getAndroidBuildVersion() async {
  if (_cachedBbuildVersion == null) {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    _cachedBbuildVersion = androidInfo.version;
  }
  return _cachedBbuildVersion;
}

String timeNumToString(int source) {
  if (source < 10) {
    return "0$source";
  }
  return source.toString();
}

String formatHHMM(DateTime dt) {
  if (dt == null) {
    return "n/a";
  }
  return formatDate(dt, [hh, ':', nn, " ", am]).toString();
}

String formatHHMMSS(DateTime dt) {
  if (dt == null) {
    return "n/a";
  }
  return formatDate(dt, [hh, ':', nn, ':', ss, " ", am]).toString();
}

String formatYYYYMMDDHHMM(DateTime dt) {
  if (dt == null) {
    return "n/a";
  }
  return formatDate(dt, [yyyy, mm, dd, '-', HH, nn]).toString();
}

bool isDark(var context) {
  final Brightness brightnessValue = MediaQuery.of(context).platformBrightness;
  return brightnessValue == Brightness.dark;
}

TextStyle getGlobalDialogTextStyle(bool isDark, {double fontSize}) {
  TextStyle defaultTextStyle = TextStyle();
  fontSize ??= defaultTextStyle.fontSize;
  return isDark
      ? TextStyle(color: Colors.blue[900], fontSize: fontSize)
      : TextStyle(color: Colors.white, fontSize: fontSize);
}

AlertStyle getGlobalAlertStyle(bool isDark) {
  return isDark
      ? AlertStyle(
          titleStyle: TextStyle(color: Colors.white),
          descStyle: TextStyle(color: Colors.white, fontSize: 18),
        )
      : AlertStyle(descStyle: TextStyle(fontSize: 18));
}

void showInfoAlert(BuildContext context, String title, String alertText,
    {AlertType type,
    String desc,
    AlertStyle alertStyle,
    TextStyle dialogTextStyle}) {
  type ??= AlertType.info;
  alertStyle ??= getGlobalAlertStyle(Get.isDarkMode);
  dialogTextStyle ??= getGlobalDialogTextStyle(Get.isDarkMode);
  Alert(
      context: context,
      title: title,
      desc: desc,
      type: type,
      style: alertStyle,
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
            style: dialogTextStyle,
          ),
        ),
      ]).show();
}

void showWarnAlert(BuildContext context, String title, String alertText,
    {String desc}) {
  Alert(
      context: context,
      title: title,
      desc: desc,
      type: AlertType.warning,
      style: getGlobalAlertStyle(Get.isDarkMode),
      content: Column(
        children: <Widget>[
          Text(alertText,
              style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).errorColor,
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
            style: getGlobalDialogTextStyle(Get.isDarkMode),
          ),
        ),
      ]).show();
}

void showErrorAlert(BuildContext context, String title, String alertText,
    {String desc}) {
  Alert(
      context: context,
      title: title,
      desc: desc,
      type: AlertType.error,
      style: getGlobalAlertStyle(Get.isDarkMode),
      content: Column(
        children: <Widget>[
          Text(alertText,
              style: TextStyle(
                fontSize: 16.0,
                color: Theme.of(context).errorColor,
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
            style: getGlobalDialogTextStyle(Get.isDarkMode),
          ),
        ),
      ]).show();
}

Future<bool> showYesNoAlert(
    BuildContext context, String title, String alertText,
    {String desc, String yesButtonText, String noButtonText}) async {
  bool answer = false;
  yesButtonText ??= 'Yes';
  noButtonText ??= 'No';
  await Alert(
      context: context,
      title: title,
      desc: desc,
      type: AlertType.warning,
      style: getGlobalAlertStyle(Get.isDarkMode),
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
            answer = false;
            Navigator.pop(context);
          },
          child: Text(
            noButtonText,
            style: getGlobalDialogTextStyle(Get.isDarkMode),
          ),
        ),
        DialogButton(
          onPressed: () {
            answer = true;
            Navigator.pop(context);
          },
          child: Text(
            yesButtonText,
            style: getGlobalDialogTextStyle(Get.isDarkMode),
          ),
        )
      ]).show();
  return answer;
}
