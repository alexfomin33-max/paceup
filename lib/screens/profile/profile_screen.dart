import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// общие виджеты
import 'widgets/header_card.dart';
import 'widgets/tabs_bar.dart';

// вкладки
import 'tabs/main_tab.dart';
import 'tabs/photos_tab.dart';
import 'tabs/stats/stats_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/races/races_tab.dart';
import 'tabs/equipment/equipment_tab.dart';
import 'tabs/clubs_tab.dart';
import 'tabs/awards/awards_tab.dart';
import 'tabs/skills/skills_tab.dart';

// общий стейт видимости снаряжения
import 'state/gear_prefs.dart';
import 'state/search/search_prefs.dart';

// 👉 экран настроек
import 'settings_screen.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Map<String, dynamic> _safeDecodeJsonAsMap(List<int> bodyBytes) {
    final raw = utf8.decode(bodyBytes);
    final cleaned = raw.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    final v = json.decode(cleaned);
    if (v is Map<String, dynamic>) return v;
    throw const FormatException('JSON is not an object');
  }

  Future<void> _loadProfileHeader() async {
  try {
    final uri = Uri.parse('http://api.paceup.ru/user_profile_header.php'); // свой путь
    final payload = {
      'user_id': widget.userId,        // ← отправляем userId в JSON
    };

    final res = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
            // 'Authorization': 'Bearer <token>', // если нужно
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final map = _safeDecodeJsonAsMap(res.bodyBytes);

    // Поддержим разные обертки ответа:
    // { ...поля профиля... }   ИЛИ   { "data": { ... } }   ИЛИ   { "profile": { ... } }
    final dynamic raw = map['profile'] ?? map['data'] ?? map;
    if (raw is! Map) throw const FormatException('Bad payload: not a JSON object');

    setState(() {
      _profileHeader = UserProfileHeader.fromJson(Map<String, dynamic>.from(raw as Map));
    });
  } catch (e, st) {
    debugPrint('Profile load error: $e\n$st');
    // Не рушим верстку: оставим заглушки из HeaderCard как есть
  }
}

@override
void initState() {
  super.initState();
  _loadProfileHeader();
}


  int _tab = 0;

  void _onTabTap(int i) {
    setState(() => _tab = i);
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int i) => setState(() => _tab = i);

  @override
  void dispose() {
    _pageController.dispose();
    _gearPrefs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Вариант без «прилипания» TabsBar: он скроллится вместе со страницей
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // Закреплённый AppBar
          SliverAppBar(
            backgroundColor: Colors.white,
            pinned: true,
            elevation: 0,
            centerTitle: false,
            titleSpacing: 8,
            title: const Row(
              children: [
                Icon(CupertinoIcons.sparkles, size: 18, color: AppColors.text),
                SizedBox(width: 8),
                Text(
                  'AI тренер',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(width: 6),
              ],
            ),
            // actions теперь НЕ const, чтобы передать колбэк
            actions: [
              const _AppIcon(CupertinoIcons.square_arrow_up),
              _AppIcon(
                CupertinoIcons.person_badge_plus,
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) =>
                          const SearchPrefsPage(startIndex: 0), // «Друзья»
                    ),
                  );
                },
              ),
              _AppIcon(
                CupertinoIcons.gear,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(0.5),
              child: SizedBox(
                height: 0.5,
                child: ColoredBox(color: Color(0xFFEAEAEA)),
              ),
            ),
          ),

          // Хедер профиля
          SliverToBoxAdapter(child: RepaintBoundary(child: HeaderCard(profile: _profileHeader))),

          // TabsBar — обычным сливером (не pinned)
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (_, __) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? _tab.toDouble())
                    : _tab.toDouble();
                return SizedBox(
                  height: 40.5,
                  child: TabsBar(
                    value: _tab,
                    page: page,
                    items: _tabTitles,
                    onChanged: _onTabTap,
                  ),
                );
              },
            ),
          ),
        ],
        // Тело — свайповый PageView, обёрнут в GearPrefsScope
        body: GearPrefsScope(
          notifier: _gearPrefs,
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _onPageChanged,
            children: const [
              MainTab(),
              PhotosTab(),
              StatsTab(),
              TrainingTab(),
              RacesTab(),
              GearTab(),
              ClubsTab(),
              AwardsTab(),
              SkillsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed; // 👈 добавили колбэк
  const _AppIcon(this.icon, {this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: AppColors.text, size: 20),
      onPressed: onPressed ?? () {},
      splashRadius: 18,
    );
  }
}
