import 'package:flutter/material.dart';

import '../../../../../providers/communication/communication_providers.dart';
import '../../widgets/communication_list_view.dart';

/// ────────────────────────────────────────────────────────────────────────────
///                              Вкладка «Подписчики»
/// ────────────────────────────────────────────────────────────────────────────
class SubscribersContent extends StatelessWidget {
  const SubscribersContent({
    super.key,
    required this.query,
    this.userId,
  });

  final String query;
  final int? userId; // Если null, используется авторизованный пользователь

  @override
  Widget build(BuildContext context) {
    return CommunicationListView(
      tab: CommunicationTab.subscribers,
      query: query,
      userId: userId,
      emptyTitle: 'На вас пока не подписались',
      emptySubtitle: 'Рассказывайте о себе, чтобы собирать аудиторию',
    );
  }
}
