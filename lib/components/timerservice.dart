import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('timerservice');

abstract class TimerService {
  Future<void> oneShotAt(DateTime time, int id, Function callback);
  Future<void> cancel(int id);
}
