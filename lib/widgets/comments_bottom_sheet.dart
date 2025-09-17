import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CommentsBottomSheet extends StatelessWidget {
  const CommentsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Список комментариев
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage("assets/Avatar_3.png"),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Татьяна Капуста", style: AppTextStyles.name),
                          const SizedBox(width: 6),
                          Text(
                            "· вчера, 18:50",
                            style: AppTextStyles.commenttext.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        "Что-то совсем маловато пробежал",
                        style: AppTextStyles.commenttext,
                      ),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage("assets/Avatar_1.png"),
                      ),
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Алексей Лукашин", style: AppTextStyles.name),
                          const SizedBox(width: 6),
                          Text(
                            "· вчера, 19:15",
                            style: AppTextStyles.commenttext.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      subtitle: const Text(
                        "Лёха Фомин и то намного больше и быстрее бегает. Я лучше с ним на эстафету поеду.",
                        style: AppTextStyles.commenttext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Разделитель бледно-серого цвета
            Divider(height: 1, color: AppColors.border),
            // Поле ввода
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Написать комментарий...",
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6, // уменьшили высоту поля
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xlarge),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(
                        10,
                      ), // уменьшили отступ кнопки
                      elevation: 0,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 20,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
