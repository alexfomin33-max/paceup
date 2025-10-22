import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_theme.dart';
import '../../widgets/app_bar.dart'; // ← наш глобальный AppBar
import '../../../widgets/transparent_route.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats/stats_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/races/races_tab.dart';
import 'tabs/equipment/equipment_tab.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/awards/awards_tab.dart';
import 'tabs/skills/skills_tab.dart';

// общий стейт видимости снаряжения
import 'widgets/gear_screen.dart';
import 'state/search/search_screen.dart';

// экран настроек
import 'state/settings_screen.dart';

import '../../models/user_profile_header.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _tabTitles = [
    'Основное',
    'Фото',
    'Статистика',
    'Тренировки',
    'Соревнования',
    'Снаряжение',
    'Клубы',
    'Награды',
    'Навыки',
  ];

  final PageController _pageController = PageController();
  final GearPrefs _gearPrefs = GearPrefs();

  UserProfileHeader? _profileHeader;

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileHeader();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  Map<String, dynamic> _safeDecodeJsonAsMap(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes);
    final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    final v = json.decode(cleaned);
    if (v is Map<String, dynamic>) return v;
    throw const FormatException('JSON is not an object');
  }

  Future<void> _loadProfileHeader() async {
    try {
      final uri = Uri.parse('http://api.paceup.ru/user_profile_header.php');
      final payload = {'user_id': widget.userId};

      final res = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final map = _safeDecodeJsonAsMap(res.bodyBytes);
      final dynamic raw = map['profile'] ?? map['data'] ?? map;
      if (raw is! Map)
        throw const FormatException('Bad payload: not a JSON object');

      setState(() {
        _profileHeader = UserProfileHeader.fromJson(
          Map<String, dynamic>.from(raw),
        );
      });
    } catch (e, st) {
      debugPrint('Profile load error: $e\n$st');
    }
  }

  void _onTabTap(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ─────────── Верхняя шапка: обычный, плоский PaceAppBar ───────────
      appBar: PaceAppBar(
        // Тот же заголовок с иконкой «AI тренер», но без стекла/прозрачности
        titleWidget: const Row(
          children: [
            Icon(
              CupertinoIcons.sparkles,
              size: 20,
              color: AppColors.iconPrimary,
            ),
            SizedBox(width: 8),
            Text(
              'AI тренер',
              style: TextStyle(fontFamily: 'Inter', fontSize: 16),
            ),
            SizedBox(width: 6),
          ],
        ),
        showBack: false, // это корневой экран профиля — кнопка назад не нужна
        actions: [
          const _AppIcon(CupertinoIcons.square_arrow_up),
          _AppIcon(
            CupertinoIcons.person_badge_plus,
            onPressed: () {
              Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const SearchPrefsPage(startIndex: 0),
                ),
              );
            },
          ),
          _AppIcon(
            CupertinoIcons.gear,
            onPressed: () {
              Navigator.of(
                context,
              ).push(TransparentPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 6),
        ],
        showBottomDivider: true,
      ),

      // ─────────── Статика сверху (HeaderCard + TabsBar) + вкладки ниже ───────────
      body: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Хедер профиля — статичный
          RepaintBoundary(
            child: HeaderCard(
              profile: _profileHeader,
              userId: widget.userId,
              onReload: _loadProfileHeader,
            ),
          ),

          // TabsBar — тоже статичный
          RepaintBoundary(
            child: SizedBox(
              height: 40.5,
              child: AnimatedBuilder(
                animation: _pageController,
                builder: (_, __) {
                  final page = _pageController.hasClients
                      ? (_pageController.page ?? _tab.toDouble())
                      : _tab.toDouble();
                  return TabsBar(
                    value: _tab,
                    page: page,
                    items: _tabTitles,
                    onChanged: _onTabTap,
                  );
                },
              ),
            ),
          ),

          // Разделитель под табами
          const Divider(height: 0.5, thickness: 0.5, color: AppColors.divider),

          // Контент вкладок — скроллится внутри, шапка/табы остаются на месте
          Expanded(
            child: GearPrefsScope(
              notifier: _gearPrefs,
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: _onPageChanged,
                children: [
                  MainTab(userId: widget.userId),
                  const PhotosTab(),
                  const StatsTab(),
                  const TrainingTab(),
                  const RacesTab(),
                  const GearTab(),
                  const ClubsTab(),
                  const AwardsTab(),
                  const SkillsTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _AppIcon(this.icon, {this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.iconPrimary, size: 20),
      onPressed: onPressed ?? () {},
      splashRadius: 22,
    );
  }
}
