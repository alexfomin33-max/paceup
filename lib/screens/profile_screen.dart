import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: const Center(child: Text('Контент Профиля')),
    );
  }
}
