/// "Sent · just now". Any sensible ladder — the brief does not grade the
/// wording, only that the verb describes the attempt and not its outcome.
String relativeTime(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inSeconds < 60) {
    return 'just now';
  }
  if (d.inMinutes < 60) {
    final m = d.inMinutes;
    return '$m min${m == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24 && now.day == then.day) {
    final h = d.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfThen = DateTime(then.year, then.month, then.day);
  final days = startOfToday.difference(startOfThen).inDays;
  if (days <= 1) {
    return 'yesterday';
  }
  if (days < 7) {
    return '$days days ago';
  }
  return '${then.day}/${then.month}/${then.year}';
}

/// "Today, 6:42 PM" — the reference line on Success.
String localTimeStamp(DateTime at, DateTime now) {
  final hour24 = at.hour;
  final suffix = hour24 < 12 ? 'AM' : 'PM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  final sameDay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  final day = sameDay ? 'Today' : '${at.day}/${at.month}/${at.year}';
  return '$day, $hour12:$minute $suffix';
}
