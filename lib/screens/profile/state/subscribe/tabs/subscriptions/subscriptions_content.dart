import 'package:flutter/material.dart';

import '../../../../../../providers/communication/communication_providers.dart';
import '../../widgets/communication_list_view.dart';

/// ────────────────────────────────────────────────────────────────────────────
///                               Вкладка «Подписки»
/// ────────────────────────────────────────────────────────────────────────────
class SubscriptionsContent extends StatelessWidget {
  const SubscriptionsContent({
    super.key,
    required this.query,
    this.userId,
  });

  final String query;
  final int? userId; // Если null, используется авторизованный пользователь

  @override
  Widget build(BuildContext context) {
    return CommunicationListView(
      tab: CommunicationTab.subscriptions,
      query: query,
      userId: userId,
      emptyTitle: 'Список подписок пуст',
      emptySubtitle: 'Подписывайтесь на атлетов, чтобы следить за ними',
    );
  }
}
