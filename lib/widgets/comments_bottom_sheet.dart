import 'package:flutter/material.dart';

class CommentsBottomSheet extends StatelessWidget {
  const CommentsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.white,
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage("assets/Avatar_3.png"),
              ),
              title: const Text(
                "Татьяна Капуста",
                style: TextStyle(fontFamily: 'Inter'),
              ),
              subtitle: const Text(
                "Что-то совсем маловато пробежал",
                style: TextStyle(fontFamily: 'Inter'),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: AssetImage("assets/Avatar_1.png"),
              ),
              title: const Text(
                "Алексей Лукашин",
                style: TextStyle(fontFamily: 'Inter'),
              ),
              subtitle: const Text(
                "Лёха Фомин и то намного больше и быстрее бегает. Я лучше с ним на эстафету поеду.",
                style: TextStyle(fontFamily: 'Inter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
