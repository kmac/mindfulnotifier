import 'package:flutter/material.dart';
import 'package:mindfulnotifier/components/alarmservice.dart';
import 'package:mindfulnotifier/components/constants.dart' as constants;
import 'package:mindfulnotifier/components/logging.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/scheduler.dart';
import 'package:mindfulnotifier/components/timerservice.dart';
import 'package:mindfulnotifier/components/utils.dart';

var logger = createLogger('quiethours');

const int quietHoursStartAlarmID = 5521;

void quietHoursStartCallback() async {
  logger
      .i("[${DateTime.now()}] quietHoursStartCallback ${getCurrentIsolate()}");
  Scheduler scheduler = await Scheduler.getScheduler();
  QuietHours quietHours = scheduler.delegate.quietHours;
  quietHours.quietStart();

  var nextQuietStart = quietHours.getNextQuietStart();
  assert(nextQuietStart.isAfter(DateTime.now()));

  TimerService timerService = await getAlarmManagerTimerService();
  await timerService.oneShotAt(
      nextQuietStart, quietHoursStartAlarmID, quietHoursStartCallback);
}

class QuietHours {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  bool notifyQuietHours = false;

  QuietHours(this.startTime, this.endTime, this.notifyQuietHours);

  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0),
            false);

  DateTime _convertTimeOfDayToToday(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    return DateTime(
        current.year, current.month, current.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToTomorrow(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    final tomorrow = current.add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime _convertTimeOfDayToYesterday(TimeOfDay tod, {DateTime current}) {
    // now can be overridden for testing
    current ??= DateTime.now();
    final yesterday = current.subtract(Duration(days: 1));
    return DateTime(
        yesterday.year, yesterday.month, yesterday.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart({DateTime current}) {
    current ??= DateTime.now();
    DateTime quietStart = _convertTimeOfDayToToday(startTime, current: current);
    if (quietStart.isBefore(current)) {
      quietStart = _convertTimeOfDayToTomorrow(startTime, current: current);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd({DateTime current}) {
    current ??= DateTime.now();
    DateTime quietEnd = _convertTimeOfDayToToday(endTime, current: current);
    // if (quietEnd.isAtSameMomentAs(now) || quietEnd.isBefore(now)) {
    if (quietEnd.isBefore(current)) {
      quietEnd = _convertTimeOfDayToTomorrow(endTime, current: current);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime givenDate) {
    /*
         yesterday ???   today     ???     tomorrow  ???
        ---------------------------------------------------------------
              now1              now2                now3 (same as now1)
               V                 V                   V
        ----------------|---------------------|-------------
                    quiet start            quiet end
                  (past or future)      (ALWAYS IN THE FUTURE)

      Quiet end is always in the future.
      Quiet start may be in the past (only when in quiet hours) or future.
      Therefore, we can start from the end and work our way back.
    */
    // Note: 'today' and 'tomorrow' are all relative to the date we're given.
    DateTime todayEnd = _convertTimeOfDayToToday(endTime, current: givenDate);
    DateTime tomorrowEnd =
        _convertTimeOfDayToTomorrow(endTime, current: givenDate);
    DateTime todayStart =
        _convertTimeOfDayToToday(startTime, current: givenDate);

    // Is quiet end today or tomorrow? It is always in the future.
    DateTime end;
    if (givenDate.isBefore(todayEnd)) {
      end = todayEnd;
    } else {
      end = tomorrowEnd;
    }
    assert(givenDate.isBefore(end)); // always in the future

    // Now we can base quiet start on what we know to be the end
    // Adjust today's start if necessary (for instance, if it is just after midnight)
    if (todayStart.add(Duration(days: 1)).isBefore(end)) {
      todayStart = todayStart.add(Duration(days: 1));
    }

    if (todayStart.isAfter(end)) {
      // Today's start is after today's end, but we haven't reached
      // today's end yet (see above end calculation), which must mean that:
      // 1) quiet hours started _yesterday_, and
      // 2) we must be in quiet hours, since we haven't reached today's end yet.
      DateTime yesterdayStart =
          _convertTimeOfDayToYesterday(startTime, current: givenDate);
      assert(givenDate.isAfter(yesterdayStart));
      assert(givenDate.isBefore(end));
      assert(givenDate.isBefore(todayStart));
      return true;
    }

    // Now we know that we are before 'end' (which is either today or
    // tomorrow - we don't care, because it is somewhere in the future).
    // So, if we are before today's start then we're before quiet hours;
    // otherwise we are in quiet hours.
    if (givenDate.isBefore(todayStart)) {
      return false;
    }
    return true;
  }

  void initializeTimers() async {
    if (isInQuietHours(DateTime.now())) {
      quietStart();
    }
    var nextQuietStart = getNextQuietStart();
    var nextQuietEnd = getNextQuietEnd();
    TimerService timerService = await getAlarmManagerTimerService();
    await timerService.cancel(quietHoursStartAlarmID);
    // await timerService.cancel(quietHoursEndAlarmID);
    logger.i(
        "Initializing quiet hours timers, start=$nextQuietStart, end=$nextQuietEnd");
    assert(nextQuietStart.isAfter(DateTime.now()));
    await timerService.oneShotAt(
        nextQuietStart, quietHoursStartAlarmID, quietHoursStartCallback);
  }

  void cancelTimers() async {
    logger.i("Cancelling quiet hours timers");
    TimerService timerService = await getAlarmManagerTimerService();
    await timerService.cancel(quietHoursStartAlarmID);
  }

  void quietStart() async {
    logger.i("Quiet hours start");
    Scheduler scheduler = await Scheduler.getScheduler();
    scheduler.sendReminderMessage(constants.reminderMessageQuietHours);
    if (notifyQuietHours) {
      Notifier().showQuietHoursNotification(true);
    }
  }
}
