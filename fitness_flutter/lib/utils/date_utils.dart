// Shared date utilities to avoid duplicating date formatting logic.

/// Returns today's date as 'YYYY-MM-DD' string.
String todayDateString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Formats any DateTime as 'YYYY-MM-DD' string.
String formatDateString(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
