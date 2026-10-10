import 'dart:io';

import 'package:share_plus/share_plus.dart';

/// Builds an all-day iCalendar (.ics) event for a rental period. Openable by any
/// calendar app (Google/Apple/Outlook) — no device permission or extra package.
String buildRentalIcs({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
  String? location,
}) {
  String d(DateTime dt) =>
      '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  final now = DateTime.now().toUtc();
  final stamp =
      '${d(now)}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}00Z';
  // All-day events use an exclusive end date, so add one day.
  final dtEnd = end.add(const Duration(days: 1));
  final loc = (location != null && location.isNotEmpty)
      ? '\nLOCATION:$location'
      : '';
  return 'BEGIN:VCALENDAR\n'
      'VERSION:2.0\n'
      'PRODID:-//AnDaLoeS//Generator Rental//EN\n'
      'BEGIN:VEVENT\n'
      'UID:$id@andaloes\n'
      'DTSTAMP:$stamp\n'
      'DTSTART;VALUE=DATE:${d(start)}\n'
      'DTEND;VALUE=DATE:${d(dtEnd)}\n'
      'SUMMARY:Generator rental: $title$loc\n'
      'DESCRIPTION:Booked on Thabit Power.\n'
      'END:VEVENT\n'
      'END:VCALENDAR\n';
}

/// Writes the .ics to a temp file and opens the share sheet (add to calendar).
Future<void> shareRentalCalendar({
  required String id,
  required String title,
  required DateTime start,
  required DateTime end,
  String? location,
}) async {
  final ics = buildRentalIcs(
      id: id, title: title, start: start, end: end, location: location);
  final file = File('${Directory.systemTemp.path}/rental_$id.ics');
  await file.writeAsString(ics);
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/calendar')],
      subject: 'Generator rental: $title');
}
