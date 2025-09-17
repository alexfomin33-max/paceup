import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_block.dart';
import 'newpost_screen.dart';
import '../widgets/comments_bottom_sheet.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// 🔹 Экран Ленты (Feed)
class LentaScreen extends StatelessWidget {
  final int userId;

  final VoidCallback? onNewPostPressed;

  const LentaScreen({super.key, required this.userId, this.onNewPostPressed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0, // убираем стандартную тень
        scrolledUnderElevation:
            0, // 🔹 отключаем затемнение при скролле (Material3)
        surfaceTintColor: Colors.transparent, // 🔹 фиксируем цвет
        backgroundColor: Colors.white, // всегда белый фон
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        shape: const Border(
          bottom: BorderSide(
            color: Color(0xFFDFE2E8), // тонкая iOS-style линия
            width: 0.5,
          ),
        ),
        leading: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(icon: const Icon(Icons.star_border), onPressed: () {}),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
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
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    "9",
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.message_outlined),
          ),
        ],
      ),
      body: ListView(
        children: [
          const ActivityBlock(), // 🔹 Используем наш отдельный виджет
          const SizedBox(height: 16),
          _buildRecommendations(),
          const SizedBox(height: 16),
          _buildPostCard(context),
        ],
      ),
    );
  }

  /// 🔹 Блок рекомендаций
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
              color: Colors.grey,
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
              color: Colors.grey,
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
      width: double.infinity, // растягиваем на весь экран
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
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),

          // Картинка поста
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
                  Icons.favorite_border,
                  size: 20,
                  color: AppColors.red,
                ),
                const SizedBox(width: 4),
                const Text("2707", style: TextStyle(fontFamily: 'Inter')),
                const SizedBox(width: 16),

                // 🔹 Кнопка комментариев
                GestureDetector(
                  onTap: () {
                    // ⬇️ Меняешь здесь стиль на Material или Cupertino
                    showCupertinoModalBottomSheet(
                      context: context,
                      expand: false,
                      builder: (context) => const CommentsBottomSheet(),
                    );
                  },
                  child: Row(
                    children: const [
                      Icon(
                        Icons.chat_bubble_outline,
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
