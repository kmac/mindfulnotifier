import 'package:date_format/date_format.dart';

String timeNumToString(int source) {
  if (source < 10) {
    return "0$source";
  }
  return source.toString();
}

String formatHHMMSS(DateTime dt) {
  return formatDate(
          DateTime(2019, 08, 1, dt.hour, dt.minute), [hh, ':', nn, " ", am])
      .toString();
}
