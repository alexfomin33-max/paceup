import 'package:flutter/material.dart';

class WorkoutsTab extends StatefulWidget {
  const WorkoutsTab({super.key});
  @override
  State<WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<WorkoutsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Center(child: Text('Тренировки — скоро ✨'));
  }
}
