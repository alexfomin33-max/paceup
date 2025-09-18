import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_block.dart';
import 'newpost_screen.dart';
import '../widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'chat_screen.dart'; // импортируем страницу чата
import 'notifications_screen.dart';
import '../models/notification_item.dart';

/// 🔹 Экран Ленты (Feed)
class LentaScreen extends StatefulWidget {
  final int userId;
  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, required this.userId, this.onNewPostPressed});

  @override
  State<LentaScreen> createState() => _LentaScreenState();
}

class _LentaScreenState extends State<LentaScreen> {
  int _unreadCount =
      3; // пример начального количества непрочитанных уведомлений
  final List<NotificationItem> _notifications = [
    NotificationItem(
      title: "Новая подписка",
      body: "Пользователь Алексей подписался на вас.",
      date: DateTime.now().subtract(const Duration(minutes: 5)),
      avatarAsset: "assets/Avatar_1.png",
    ),
    NotificationItem(
      title: "Новый комментарий",
      body: "Мария оставила комментарий к вашему посту.",
      date: DateTime.now().subtract(const Duration(hours: 1)),
      avatarAsset: "assets/Avatar_2.png",
    ),
    NotificationItem(
      title: "Обновление приложения",
      body: "Доступна новая версия приложения.",
      date: DateTime.now().subtract(const Duration(days: 1)),
      avatarAsset: "assets/Avatar_3.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDFE2E8), width: 0.5),
        ),
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(CupertinoIcons.star),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.add_circled),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewPostScreen()),
                );
              },
            ),
          ],
        ),
        title: const Text("Лента", style: AppTextStyles.h1),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Basic()),
              );
            },
            icon: const Icon(CupertinoIcons.bubble_left_bubble_right),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  // Переход на экран уведомлений
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NotificationsScreen()),
                  );
                  // После возвращения можно пометить все уведомления как просмотренные
                  setState(() {
                    _unreadCount = 0;
                  });
                },
                icon: const Icon(CupertinoIcons.bell),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 10,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "$_unreadCount",
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        children: [
          const ActivityBlock(),
          const SizedBox(height: 16),
          _buildRecommendations(),
          const SizedBox(height: 16),
          _buildPostCard(context),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            "Рекомендации для вас",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 282,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _friendCard(
                "Екатерина Виноградова",
                "36 лет, Санкт-Петербург",
                "6 общих друзей",
                "assets/Recommended_1.png",
              ),
              const SizedBox(width: 12),
              _friendCard(
                "Анатолий Курагин",
                "38 лет, Ковров",
                "4 общих друга",
                "assets/Recommended_2.png",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _friendCard(
    String name,
    String desc,
    String mutual,
    String avatarAsset,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(60),
            child: Image.asset(
              avatarAsset,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            mutual,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.text,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Подписаться",
                style: TextStyle(fontFamily: 'Inter', color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(width: 0.5, color: Color(0xFFBDC1CA)),
          bottom: BorderSide(width: 0.5, color: Color(0xFFBDC1CA)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    "assets/Avatar_1.png",
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Алексей Лукашин",
                        style: AppTextStyles.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "7 июня 2025, в 14:36",
                        style: AppTextStyles.date,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(CupertinoIcons.ellipsis),
                ),
              ],
            ),
          ),
          Image.asset(
            "assets/post.png",
            fit: BoxFit.cover,
            height: 300,
            width: double.infinity,
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              "Вот так вот очень легко всех победил",
              style: TextStyle(fontFamily: 'Inter'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.heart,
                  size: 20,
                  color: AppColors.red,
                ),
                const SizedBox(width: 4),
                const Text("2707", style: TextStyle(fontFamily: 'Inter')),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    showCupertinoModalBottomSheet(
                      context: context,
                      expand: false,
                      builder: (context) => const CommentsBottomSheet(),
                    );
                  },
                  child: Row(
                    children: const [
                      Icon(
                        CupertinoIcons.chat_bubble,
                        size: 20,
                        color: AppColors.orange,
                      ),
                      SizedBox(width: 4),
                      Text("50", style: TextStyle(fontFamily: 'Inter')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
