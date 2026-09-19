/// Compact relative timestamp used across the chat UI.
String formatChatTime(String? dateTimeString) {
  if (dateTimeString == null || dateTimeString.isEmpty) return '';
  try {
    final dateTime = DateTime.parse(dateTimeString).toLocal();
    final difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return "à l'instant";
    if (difference.inHours < 1) return 'il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'il y a ${difference.inDays} j';
    return '${dateTime.day}/${dateTime.month}';
  } catch (_) {
    return '';
  }
}
