import 'package:logger/logger.dart';

// import 'dart:io';
// import 'package:logger/src/outputs/file_output.dart';
// import 'package:mindfulnotifier/components/constants.dart' as constants;
//
// bool useFileLogging = false;
// Directory baseDir;
//
// void initializeLogging(Directory outputDir) {
//   baseDir = outputDir;
//   if (baseDir != null) {
//     useFileLogging = true;
//   }
// }

Logger createLogger(String className) {
  // if (useFileLogging) {
  //   return createLoggerMulti(className);
  // }
  return Logger(
    printer: SimpleLogPrinter(className),
    filter: ProductionFilter(),
    output: ConsoleOutput(),
  );
}

// Logger createLoggerMulti(String className) {
//   return Logger(
//       printer: SimpleLogPrinter(className),
//       filter: ProductionFilter(),
//       output: MultiOutput([
//         ConsoleOutput(),
//         FileOutput(file: File('$baseDir/${constants.appName}.log'))
//       ]));
// }

class SimpleLogPrinter extends LogPrinter {
  final String className;
  SimpleLogPrinter(this.className);

  @override
  List<String> log(LogEvent event) {
    var color = PrettyPrinter.levelColors[event.level];
    // var emoji = PrettyPrinter.levelEmojis[event.level];
    List<String> logmsg = [
      color(
          '${getTime()} ${getLevel(event.level)} $className: ${event.message}')
    ];
    if (event.error != null) {
      logmsg.add(color('error=${event.error}'));
    }
    if (event.stackTrace != null) {
      logmsg.add(color('stacktrace=${event.stackTrace}'));
    }
    return logmsg;
  }

  String getLevel(Level level) {
    switch (level) {
      case Level.verbose:
        return "VERBOSE:";
      case Level.debug:
        return "DEBUG:";
      case Level.info:
        return "INFO:";
      case Level.warning:
        return "WARN:";
      case Level.error:
        return "ERROR:";
      case Level.wtf:
        return "WTF:";
      case Level.nothing:
        return "n/a:";
    }
    return 'UNKNOWN:';
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
