extension StringInitials on String {
  String get initials {
    final trimmed = trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }
}
