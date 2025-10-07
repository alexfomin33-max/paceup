// lib/screens/profile/tabs/clubs_tab.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../state/search/search_prefs.dart';
import '../../map/clubs/coffeerun_vld/coffeerun_vld_screen.dart';

class ClubsTab extends StatefulWidget {
  const ClubsTab({super.key});
  @override
  State<ClubsTab> createState() => _ClubsTabState();
}

class _ClubsTabState extends State<ClubsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Данные клубов — подставил новые ассеты.
  static const _clubs = <_Club>[
    _Club(
      title: 'PaceUp Club',
      members: 58234,
      asset: 'assets/club_1.png',
      circleLogo: false,
    ),
    _Club(
      title: '"CoffeeRun_vld"',
      members: 400,
      asset: 'assets/club_2.png',
      circleLogo: false,
    ),
    _Club(
      title: 'I Love Swimming',
      members: 1670,
      asset: 'assets/club_3.png',
      circleLogo: true,
    ),
    _Club(
      title: 'I Love Cycling',
      members: 3217,
      asset: 'assets/club_4.png',
      circleLogo: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Сетка карточек 2xN
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 174,
            ),
            itemCount: _clubs.length,
            itemBuilder: (context, i) => _ClubCard(_clubs[i]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Кнопка "Найти клуб"
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          const SearchPrefsPage(startIndex: 1), // сразу «Клубы»
                    ),
                  );
                },
                icon: const Icon(CupertinoIcons.search, size: 18),
                label: const Text(
                  'Найти клуб',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _ClubCard extends StatelessWidget {
  final _Club club;
  const _ClubCard(this.club);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Логотип
          SizedBox(
            height: 100,
            width: 100,
            child: club.circleLogo
                ? ClipOval(child: _LogoImage(path: club.asset))
                : ClipOval(child: _LogoImage(path: club.asset)),
          ),
          const SizedBox(height: 8),

          // Название
          Text(
            club.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),

          // Участники
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Участников: ${_formatMembers(club.members)}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Делает кликабельной ТОЛЬКО карточку CoffeeRun_vld
    final isCoffee = club.title.replaceAll('"', '') == 'CoffeeRun_vld';
    if (!isCoffee) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(
          context,
        ).push(CupertinoPageRoute(builder: (_) => const CoffeeRunVldScreen()));
      },
      child: card,
    );
  }
}

class _LogoImage extends StatelessWidget {
  final String path;
  const _LogoImage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.black.withValues(alpha: 0.06),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.photo,
          size: 24,
          color: AppColors.greytext,
        ),
      ),
    );
  }
}

class _Club {
  final String title;
  final int members;
  final String asset;
  final bool circleLogo;
  const _Club({
    required this.title,
    required this.members,
    required this.asset,
    required this.circleLogo,
  });
}

// Формат "58 234"
String _formatMembers(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    buf.write(s[i]);
    if (rev > 1 && rev % 3 == 1) {
      buf.write('\u202F'); // узкий неразрывный пробел
    }
  }
  return buf.toString();
}
