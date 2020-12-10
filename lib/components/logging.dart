import 'package:logger/logger.dart';

// class SimpleLogPrinter extends PrettyPrinter {
//   // final String className;
//   // SimpleLogPrinter(this.className) {
//   SimpleLogPrinter()
//       : super(
//           methodCount: 0,
//           errorMethodCount: 8,
//           lineLength: 120,
//           colors: true,
//           printEmojis: false,
//           printTime: true,
//         );
// }

class SimpleLogPrinter extends LogPrinter {
  PrettyPrinter p;
  final String className;
  SimpleLogPrinter(this.className);

  @override
  List<String> log(LogEvent event) {
    // void log(Level level, message, error, StackTrace stackTrace) {
    var color = PrettyPrinter.levelColors[event.level];
    // var emoji = PrettyPrinter.levelEmojis[event.level];
    // return ([color('$emoji $className - ${event.message}')]);
    return ([color('${getTime()}: $className - ${event.message}')]);
  }

  String getTime() {
    String _threeDigits(int n) {
      if (n >= 100) return '$n';
      if (n >= 10) return '0$n';
      return '00$n';
    }

    String _twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    var now = DateTime.now();
    var h = _twoDigits(now.hour);
    var min = _twoDigits(now.minute);
    var sec = _twoDigits(now.second);
    var ms = _threeDigits(now.millisecond);
    return '$h:$min:$sec.$ms';
  }
}
