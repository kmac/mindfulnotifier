import 'package:flutter/material.dart';
import 'package:date_format/date_format.dart';

String timeNumToString(int source) {
  if (source < 10) {
    return "0$source";
  }
  return source.toString();
}

String formatHHMM(DateTime dt) {
  return formatDate(
          DateTime(2019, 08, 1, dt.hour, dt.minute), [hh, ':', nn, " ", am])
      .toString();
}

String formatHHMMSS(DateTime dt) {
  return formatDate(DateTime(2019, 08, 1, dt.hour, dt.minute, dt.second),
      [hh, ':', nn, ':', ss, " ", am]).toString();
}

bool isDark(var context) {
  final Brightness brightnessValue = MediaQuery.of(context).platformBrightness;
  return brightnessValue == Brightness.dark;
}
