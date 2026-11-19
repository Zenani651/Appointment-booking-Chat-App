import 'package:flutter/material.dart';

/// Parses "08:30" into a TimeOfDay. Returns null if invalid.
TimeOfDay? parseHm(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return TimeOfDay(hour: h, minute: m);
}

String formatHm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class OpenStatus {
  final bool isOpen;
  final String label;
  const OpenStatus(this.isOpen, this.label);
}

/// Whether a business is open right now, based on the device's clock.
/// Returns null when the business hasn't set both times.
/// Works for overnight hours too (e.g. 18:00 to 02:00).
OpenStatus? openStatus(String? opensAt, String? closesAt, {DateTime? now}) {
  final opens = parseHm(opensAt);
  final closes = parseHm(closesAt);
  if (opens == null || closes == null) return null;

  final t = now ?? DateTime.now();
  final minutes = t.hour * 60 + t.minute;
  final o = opens.hour * 60 + opens.minute;
  final c = closes.hour * 60 + closes.minute;

  final open =
      o < c ? (minutes >= o && minutes < c) : (minutes >= o || minutes < c);

  return open
      ? OpenStatus(true, 'Open now · closes ${formatHm(closes)}')
      : OpenStatus(false, 'Closed · opens ${formatHm(opens)}');
}
