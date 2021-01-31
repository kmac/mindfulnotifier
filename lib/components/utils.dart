import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

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

void showInfoAlert(BuildContext context, String title, String alertText,
    {AlertType type, String desc}) {
  type ??= AlertType.info;
  Alert(
      context: context,
      title: title,
      desc: desc,
      type: type,
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
            style: TextStyle(color: Colors.white),
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
            style: TextStyle(color: Colors.white),
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
            style: TextStyle(color: Colors.white),
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
            style: TextStyle(color: Colors.white),
          ),
        ),
        DialogButton(
          onPressed: () {
            answer = true;
            Navigator.pop(context);
          },
          child: Text(
            yesButtonText,
            style: TextStyle(color: Colors.white),
          ),
        )
      ]).show();
  return answer;
}
