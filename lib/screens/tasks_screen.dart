// lib/screens/tasks_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'swim_trip_screen.dart';
import '200k_run_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _segment = 0; // 0 — Активные, 1 — Доступные

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Задачи',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.text,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [
            Center(
              child: _SegmentedPill(
                left: 'Активные',
                right: 'Доступные',
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            const SizedBox(height: 20),

            if (_segment == 0)
              ..._buildActiveTab()
            else
              ..._buildAvailableTab(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveTab() {
    return [
      const _MonthLabel('Июнь 2025'),
      const SizedBox(height: 8),

      TaskCard(
        colorTint: const Color(0xFFE9F7E3),

        icon: CupertinoIcons.star,
        badgeText: '10 дней',
        title: '10 дней активности',
        progressText: '6 из 10 дней',
        percent: 0.60,
      ),
      const SizedBox(height: 12),

      TaskCard(
        colorTint: const Color(0xFFE8F7F1),
        icon: Icons.directions_run,
        badgeText: '200 км',
        title: '200 км бега',
        progressText: '145,8 из 200 км',
        percent: 0.729,
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const Run200kScreen()),
          ); // ⬅️ без нижней навигации
        },
      ),
      const SizedBox(height: 12),

      TaskCard(
        colorTint: const Color(0xFFE8F5FF),

        icon: CupertinoIcons.arrow_up,
        badgeText: '1000 м',
        title: '1000 метров набора высоты',
        progressText: '537 из 1000 м',
        percent: 0.537,
      ),
      const SizedBox(height: 12),

      TaskCard(
        colorTint: const Color(0xFFF7F0FF),

        icon: CupertinoIcons.stopwatch,
        badgeText: '1000 мин',
        title: '1000 минут активности',
        progressText: '618 из 1000 мин',
        percent: 0.618,
      ),
      const SizedBox(height: 20),

      const _SectionLabel('Экспедиции'),
      const SizedBox(height: 8),

      ExpeditionCard(
        title: 'Суздаль',
        progressText: '21 784 из 110 033 шагов',
        percent: 0.198,
        image: const _RoundImage(provider: AssetImage('assets/Suzdal.png')),
      ),
      const SizedBox(height: 12),

      ExpeditionCard(
        title: 'Монблан',
        progressText: '3 521 из 4 810 метров',
        percent: 0.732,
        image: const _RoundImage(provider: AssetImage('assets/Monblan.png')),
      ),
    ];
  }

  List<Widget> _buildAvailableTab() {
    return [
      const _MonthLabel('Июнь 2025'),
      const SizedBox(height: 8),

      _AvailableGrid(
        children: [
          AvailableTaskCard(
            icon: Icons.pedal_bike,
            badge: '200 км',
            title: '200 км на велосипеде за июнь',
            buttonText: 'Начать',
            onTap: () {},
          ),
          AvailableTaskCard(
            icon: Icons.pool,
            badge: '10 км',
            title: 'Проплыть в июне 10 км',
            buttonText: 'Начать',
            onTap: () {},
          ),
          AvailableTaskCard(
            icon: Icons.directions_walk,
            badge: '250 000',
            title: 'Сделать 250 000 шагов за июнь',
            buttonText: 'Начать',
            onTap: () {},
          ),
        ],
      ),
      const SizedBox(height: 20),

      const _SectionLabel('Экспедиции'),
      const SizedBox(height: 8),

      _AvailableGrid(
        children: [
          AvailableExpeditionCard(
            imageProvider: const AssetImage('assets/Travel_velo.png'),
            title: 'Путешествия на велосипеде',
            buttonText: 'Смотреть',
            onTap: () {},
          ),
          AvailableExpeditionCard(
            imageProvider: const AssetImage('assets/Travel_swim.png'),
            title: 'Плавательное приключение',
            buttonText: 'Смотреть',
            onTap: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const SwimTripScreen()));
            },
          ),
        ],
      ),
    ];
  }
}

/// ───────────── UI блоки ─────────────

class _SegmentedPill extends StatelessWidget {
  final String left;
  final String right;
  final int value; // 0 или 1
  final ValueChanged<int> onChanged;
  const _SegmentedPill({
    required this.left,
    required this.right,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEAEAEA), // тонкая светло-серая линия
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_seg(0, left), _seg(1, right)],
      ),
    );
  }

  Widget _seg(int idx, String text) {
    final selected = value == idx;
    return GestureDetector(
      onTap: () => onChanged(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black87 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

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
        fontWeight: FontWeight.w600,
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
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}

// внутри tasks_screen.dart

class TaskCard extends StatelessWidget {
  final Color colorTint;
  final IconData icon;
  final String badgeText;
  final String title;
  final String progressText;
  final double percent;
  final VoidCallback? onTap; // ⬅️ добавили

  const TaskCard({
    super.key,
    required this.colorTint,
    required this.icon,
    required this.badgeText,
    required this.title,
    required this.progressText,
    required this.percent,
    this.onTap, // ⬅️ добавили
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _IconBadge(bg: colorTint, icon: icon, text: badgeText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(percent: percent),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.greytext,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.greytext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.large),
              onTap: onTap,
              child: card,
            ),
          );
  }
}

class ExpeditionCard extends StatelessWidget {
  final String title;
  final String progressText;
  final double percent;
  final Widget image;
  final VoidCallback? onTap; // ⬅️ добавили

  const ExpeditionCard({
    super.key,
    required this.title,
    required this.progressText,
    required this.percent,
    required this.image,
    this.onTap, // ⬅️ добавили
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          image,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                _ProgressBar(percent: percent),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progressText,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.greytext,
                      ),
                    ),
                    Text(
                      '${(percent * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.greytext,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.large),
              onTap: onTap,
              child: card,
            ),
          );
  }
}

class _ProgressBar extends StatelessWidget {
  final double percent;
  const _ProgressBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final currentWidth = (percent.clamp(0, 1)) * totalWidth;

        return Row(
          children: [
            // синяя часть (прогресс)
            Container(
              width: currentWidth,
              height: 6,
              decoration: BoxDecoration(
                color: Color(0xFF22CCB2),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            // серый остаток
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Color bg;
  final IconData icon;
  final String text;
  const _IconBadge({required this.bg, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 28, color: AppColors.text),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundImage extends StatelessWidget {
  final ImageProvider? provider;
  const _RoundImage({this.provider});

  /// Заглушка, если нет картинок
  const _RoundImage.placeholder() : provider = null;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          image: provider != null
              ? DecorationImage(image: provider!, fit: BoxFit.cover)
              : null,
        ),
        child: provider == null
            ? const Icon(CupertinoIcons.photo, size: 22, color: Colors.white70)
            : null,
      ),
    );
  }
}

/// ───────────── «Доступные» ─────────────

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
  final String badge; // «200 км», «10 км», «250 000»
  final String title;
  final String buttonText;
  final VoidCallback onTap;

  const AvailableTaskCard({
    super.key,
    required this.icon,
    required this.badge,
    required this.title,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            textAlign: TextAlign.center, // 🔹 центрируем текст
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          const Spacer(),
          _PrimarySmallButton(text: buttonText, onPressed: onTap),
        ],
      ),
    );
  }
}

class AvailableExpeditionCard extends StatelessWidget {
  final ImageProvider imageProvider;
  final String title;
  final String buttonText;
  final VoidCallback onTap;

  const AvailableExpeditionCard({
    super.key,
    required this.imageProvider,
    required this.title,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            textAlign: TextAlign.center, // 🔹 центрируем текст
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          _PrimarySmallButton(text: buttonText, onPressed: onTap),
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
            color: Color(0xFFEFF6EE), // мягкий светлый фон
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
                  blurRadius: 6,
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
  final VoidCallback onPressed;
  const _PrimarySmallButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
