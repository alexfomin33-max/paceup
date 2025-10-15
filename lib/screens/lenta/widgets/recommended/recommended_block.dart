import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Блок «Рекомендации для вас», вынесенный в отдельный виджет.
/// Пока данные захардкожены — позже можно передать список через параметры.
class RecommendedBlock extends StatelessWidget {
  const RecommendedBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Рекомендации для вас', style: AppTextStyles.numberstat),
        ),
        SizedBox(height: 12),
        _RecommendedList(),
      ],
    );
  }
}

/// Горизонтальный список карточек рекомендаций.
class _RecommendedList extends StatelessWidget {
  const _RecommendedList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 283,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 300,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: const [
          _FriendCard(
            name: 'Екатерина Виноградова',
            desc: '36 лет, Санкт-Петербург',
            mutual: '6 общих друзей',
            avatarAsset: 'assets/recommended_1.png',
          ),
          SizedBox(width: 12),
          _FriendCard(
            name: 'Юрий Селиванов',
            desc: '38 лет, Ковров',
            mutual: '4 общих друга',
            avatarAsset: 'assets/recommended_2.jpg',
          ),
          SizedBox(width: 12),
          _FriendCard(
            name: 'Евгения Миронова',
            desc: '29 лет, Иваново',
            mutual: '3 общих друга',
            avatarAsset: 'assets/recommended_3.png',
          ),
        ],
      ),
    );
  }
}

/// Одна карточка рекомендации.
class _FriendCard extends StatelessWidget {
  final String name;
  final String desc;
  final String mutual;
  final String avatarAsset;

  const _FriendCard({
    required this.name,
    required this.desc,
    required this.mutual,
    required this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
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
            style: AppTextStyles.numberstat,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: AppTextStyles.date,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            mutual,
            style: AppTextStyles.date,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
              ),
              child: const Text(
                'Подписаться',
                style: TextStyle(color: AppColors.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
