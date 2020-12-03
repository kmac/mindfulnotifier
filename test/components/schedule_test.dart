import 'package:flutter_test/flutter_test.dart';

import 'package:remindfulbell/components/schedule.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Periodic', () {
    test('test schedule 15m', () {
      PeriodicScheduler scheduler = PeriodicScheduler(
          null, 0, 15, QuietHours.defaultQuietHours(), 'test');
      DateTime dt = DateTime(2020, 1, 1, 0, 5);
      DateTime start = scheduler.getInitialStart(now: dt);
      print("start: $start");
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 0);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 14, 59);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 15);

      dt = DateTime(2020, 1, 1, 0, 15);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 30);
    });
    test('test schedule 30m', () {
      PeriodicScheduler scheduler = PeriodicScheduler(
          null, 0, 30, QuietHours.defaultQuietHours(), 'test');
      // scheduler.durationMinutes = 30;
      DateTime dt = DateTime(2020, 1, 1, 0, 5);
      DateTime start = scheduler.getInitialStart(now: dt);
      print("start: $start");
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 0);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 14, 59);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 30);

      dt = DateTime(2020, 1, 1, 0, 15);
      start = scheduler.getInitialStart(now: dt);
      expect(start.minute, 30);
    });
  });
}
