class NotificationItem {
  final String title;
  final String body;
  final DateTime date;
  final String? avatarAsset;
  bool viewed; // поле для отслеживания, просмотрено ли уведомление

  NotificationItem({
    required this.title,
    required this.body,
    required this.date,
    this.avatarAsset,
    this.viewed = false,
  });
}
