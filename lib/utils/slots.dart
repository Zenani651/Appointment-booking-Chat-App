import 'package:flutter/material.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Unique ID for a slot start time, e.g. 202611201430.
String slotId(DateTime t) =>
    '${t.year}${_two(t.month)}${_two(t.day)}${_two(t.hour)}${_two(t.minute)}';

/// All slot start times on [day] between opening and closing time.
/// If closing is not after opening (overnight hours), slots stop at midnight.
List<DateTime> generateSlots(
  DateTime day,
  TimeOfDay opens,
  TimeOfDay closes,
  int minutes,
) {
  final o = opens.hour * 60 + opens.minute;
  var c = closes.hour * 60 + closes.minute;
  if (c <= o) c = 24 * 60;

  final slots = <DateTime>[];
  for (var m = o; m + minutes <= c; m += minutes) {
    slots.add(DateTime(day.year, day.month, day.day, m ~/ 60, m % 60));
  }
  return slots;
}
