import 'package:flutter_test/flutter_test.dart';

import 'package:mindfulnotifier/components/schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Periodic', () {
    test('test schedule 15m', () {
      Scheduler scheduler = Scheduler(null, 'test');
      PeriodicScheduler delegate =
          PeriodicScheduler(scheduler, QuietHours.defaultQuietHours(), 0, 15);
      DateTime dt = DateTime(2020, 1, 1, 0, 5);
      DateTime start = delegate.getInitialStart(now: dt);
      print("start: $start");
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 0);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 14, 59);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 15);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 30);
    });
    test('test schedule 30m', () {
      Scheduler scheduler = Scheduler(null, 'test');
      PeriodicScheduler delegate =
          PeriodicScheduler(scheduler, QuietHours.defaultQuietHours(), 0, 30);
      // scheduler.durationMinutes = 30;
      DateTime dt = DateTime(2020, 1, 1, 0, 5);
      DateTime start = delegate.getInitialStart(now: dt);
      print("start: $start");
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 0);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 14, 59);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 15);
      start = delegate.getInitialStart(now: dt);
      expect(start.minute, 30);
    });
  });
}
