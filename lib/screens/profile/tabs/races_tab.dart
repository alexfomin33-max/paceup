import 'package:flutter/material.dart';

class RacesTab extends StatefulWidget {
  const RacesTab({super.key});
  @override
  State<RacesTab> createState() => _RacesTabState();
}

class _RacesTabState extends State<RacesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const Center(child: Text('Соревнования — скоро ✨'));
  }
}
