import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';
import 'package:mindfulnotifier/components/schedule.dart';

void main() {
  Scheduler scheduler;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    scheduler = Scheduler();
    scheduler.init();
  });
  tearDown(() {});

  group('Periodic', () {
    test('test schedule 15m', () {
      PeriodicScheduler delegate =
          PeriodicScheduler(scheduler, QuietHours.defaultQuietHours(), 0, 15);
      scheduler.delegate = delegate;
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
      PeriodicScheduler delegate =
          PeriodicScheduler(scheduler, QuietHours.defaultQuietHours(), 0, 30);
      scheduler.delegate = delegate;
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

  group('Random', () {
    test('test schedule 15m', () {});
  });

  group('Quiet Hours', () {
    test('quiet hours - before quiet', () {
      var quietHours = QuietHours(
          TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));
      DateTime dt = DateTime.parse("2020-01-01 14:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0).add(Duration(days: 1)));
    });
    test('quiet hours - in quiet', () {
      var quietHours = QuietHours(
          TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));
      DateTime dt = DateTime.parse("2020-01-01 22:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0).add(Duration(days: 1)));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0).add(Duration(days: 1)));

      dt = DateTime.parse("2020-01-01 08:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0));

      // edge case
      dt = DateTime.parse("2020-01-01 21:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0).add(Duration(days: 1)));

      dt = DateTime.parse("2020-01-01 09:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0));
    });
    test('quiet hours - late start', () {
      // start @1am
      var quietHours = QuietHours(
          TimeOfDay(hour: 1, minute: 0), TimeOfDay(hour: 9, minute: 0));
      // before quiet:
      DateTime dt = DateTime.parse("2020-01-01 22:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 1, 0).add(Duration(days: 1)));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0).add(Duration(days: 1)));

      // in quiet:
      dt = DateTime.parse("2020-01-02 02:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 1, 0).add(Duration(days: 1)));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0));
    });

    test('quiet hours - after quiet', () {
      var quietHours = QuietHours(
          TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));
      DateTime dt = DateTime.parse("2020-01-01 10:00:00");
      expect(quietHours.getNextQuietStart(now: dt),
          DateTime(dt.year, dt.month, dt.day, 21, 0));
      expect(quietHours.getNextQuietEnd(now: dt),
          DateTime(dt.year, dt.month, dt.day, 9, 0).add(Duration(days: 1)));
    });
  });
}
