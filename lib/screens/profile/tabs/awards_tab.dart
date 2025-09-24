import 'package:flutter/material.dart';

class AwardsTab extends StatefulWidget {
  const AwardsTab({super.key});
  @override
  State<AwardsTab> createState() => _AwardsTabState();
}

class _AwardsTabState extends State<AwardsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Center(child: Text('Награды — скоро ✨'));
  }
}
