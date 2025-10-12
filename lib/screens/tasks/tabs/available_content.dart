import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../swim_trip_screen.dart';

class AvailableContent extends StatelessWidget {
  const AvailableContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MonthLabel('Июнь 2025'),
        const SizedBox(height: 8),

        const _AvailableGrid(
          children: [
            AvailableTaskCard(
              icon: Icons.pedal_bike,
              badge: '200 км',
              title: '200 км на велосипеде за июнь',
              buttonText: 'Начать',
            ),
            AvailableTaskCard(
              icon: Icons.pool,
              badge: '10 км',
              title: 'Проплыть в июне 10 км',
              buttonText: 'Начать',
            ),
            AvailableTaskCard(
              icon: Icons.directions_walk,
              badge: '250 000',
              title: 'Сделать 250 000 шагов за июнь',
              buttonText: 'Начать',
            ),
          ],
        ),
        const SizedBox(height: 20),

        const _SectionLabel('Экспедиции'),
        const SizedBox(height: 8),

        _AvailableGrid(
          children: [
            const AvailableExpeditionCard(
              imageProvider: AssetImage('assets/Travel_velo.png'),
              title: 'Путешествия на велосипеде',
              buttonText: 'Смотреть',
            ),
            AvailableExpeditionCard(
              imageProvider: const AssetImage('assets/Travel_swim.png'),
              title: 'Плавательное приключение',
              buttonText: 'Смотреть',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const SwimTripScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// ===== Локальные виджеты «Доступных» =====

class _MonthLabel extends StatelessWidget {
  final String text;
  const _MonthLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.text,
      ),
    );
  }
}

class _AvailableGrid extends StatelessWidget {
  final List<Widget> children;
  const _AvailableGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: children,
    );
  }
}

class AvailableTaskCard extends StatelessWidget {
  final IconData icon;
  final String badge;
  final String title;
  final String buttonText;
  final VoidCallback? onPressed;

  const AvailableTaskCard({
    super.key,
    required this.icon,
    required this.badge,
    required this.title,
    required this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Center(
            child: _SmallCircleBadgeIcon(icon: icon, badge: badge),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          _PrimarySmallButton(text: buttonText, onPressed: onPressed),
        ],
      ),
    );
  }
}

class AvailableExpeditionCard extends StatelessWidget {
  final ImageProvider imageProvider;
  final String title;
  final String buttonText;
  final VoidCallback? onPressed;

  const AvailableExpeditionCard({
    super.key,
    required this.imageProvider,
    required this.title,
    required this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ClipOval(
              child: Image(
                image: imageProvider,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          _PrimarySmallButton(text: buttonText, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _SmallCircleBadgeIcon extends StatelessWidget {
  final IconData icon;
  final String badge;
  const _SmallCircleBadgeIcon({required this.icon, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6EE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: AppColors.text),
        ),
        Positioned(
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimarySmallButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const _PrimarySmallButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed ?? () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
