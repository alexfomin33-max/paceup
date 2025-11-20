import 'package:flutter/material.dart';

import '../../../../../../providers/communication/communication_providers.dart';
import '../../widgets/communication_list_view.dart';

/// ────────────────────────────────────────────────────────────────────────────
///                              Вкладка «Подписчики»
/// ────────────────────────────────────────────────────────────────────────────
class SubscribersContent extends StatelessWidget {
  const SubscribersContent({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return CommunicationListView(
      tab: CommunicationTab.subscribers,
      query: query,
      emptyTitle: 'На вас пока не подписались',
      emptySubtitle: 'Рассказывайте о себе, чтобы собирать аудиторию',
    );
  }
}
