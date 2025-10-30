// =========================== main_tab.dart ===========================
// Экран вкладки "Основное" в профиле.
// Здесь:
//   • загружаем данные по API (FutureBuilder),
//   • подписываемся на локальные предпочтения пользователя (GearPrefsScope),
//   • собираем сливер-ленту из простых презентеров/виджетов,
//   • используем вынесенные модели и секцию снаряжения.
//
// Важно: вся логика данных (парсинг JSON и модели) вынесена в main_tab_data.dart,
// а секция снаряжения — в gear_section_sliver.dart. Это упрощает поддержку и тестирование.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import 'widgets/gear_screen.dart';
import '../equipment/viewing/viewing_equipment_screen.dart';
import '../../../../service/api_service.dart';

// 🔹 Модели и парсинг данных
import 'models/main_tab_data.dart';
// 🔹 Виджет-секция "Снаряжение" как один sliver
import 'widgets/gear_section_sliver.dart';

class MainTab extends StatefulWidget {
  final int userId; // ID пользователя, для которого показываем вкладку
  const MainTab({super.key, required this.userId});

  @override
  State<MainTab> createState() => _MainTabState();
}

class _MainTabState extends State<MainTab> with AutomaticKeepAliveClientMixin {
  // Храним будущий результат загрузки, чтобы не перезагружать при каждом build
  Future<MainTabData>? _future;

  void _openShoesView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewingEquipmentScreen(initialSegment: 0),
      ),
    );
  }

  void _openBikesView() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ViewingEquipmentScreen(initialSegment: 1),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _load(); // первая загрузка при открытии вкладки
  }

  @override
  void didUpdateWidget(covariant MainTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если userId изменился (например, открыли профиль другого пользователя),
    // перезапускаем загрузку данных.
    if (oldWidget.userId != widget.userId) {
      _future = _load();
    }
  }

  // Запрос к API: отправляем userId, получаем JSON, парсим в MainTabData
  Future<MainTabData> _load() async {
    final api = ApiService();
    final jsonMap = await api.post(
      '/user_profile_maintab.php',
      body: {'userId': '${widget.userId}'}, // 🔹 PHP ожидает строки
    );

    // Универсальная обработка ошибок API
    if (jsonMap['ok'] == false) {
      throw Exception(jsonMap['error'] ?? 'API error');
    }

    // Превращаем сырые данные в типизированные модели для UI
    return MainTabData.fromJson(jsonMap);
  }

  // Вкладка должна сохранять своё состояние (скролл, позиции и т.д.), когда мы перелистываем PageView
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // важно для AutomaticKeepAliveClientMixin
    final prefs = GearPrefsScope.of(
      context,
    ); // локальные настройки видимости снаряжения

    return FutureBuilder<MainTabData>(
      future: _future ??= _load(), // повторная подстраховка
      builder: (context, snap) {
        // Состояние "ждём" — показываем индикатор по центру экрана
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemainingCentered(
            child: CupertinoActivityIndicator(),
          );
        }

        // Состояние "ошибка" — показываем текст ошибки
        if (snap.hasError) {
          return SliverFillRemainingCentered(
            child: Text(
              'Не удалось загрузить данные\n${snap.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
            ),
          );
        }

        // Успешная загрузка — собираем сливеры
        final data = snap.data!;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ───────────────── Активность (горизонтальный скроллер) ─────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            const SliverToBoxAdapter(child: _SectionTitle('Активность')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Преобразуем модели активности в простые элементы для карточек
            SliverToBoxAdapter(
              child: _ActivityScroller(
                items: data.activity
                    .map((a) => _ActItem(a.asset, a.value, a.label))
                    .toList(growable: false),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ───────────────── Снаряжение (кроссовки / велосипеды) ─────────────────
            // Вставляем секцию как полноценный sliver без дополнительных обёрток.
            if (prefs.showShoes && data.shoes.isNotEmpty)
              GearSectionSliver(
                title: 'Кроссовки',
                items: data.shoes,
                isBike: false,
                onItemTap: _openShoesView,
              ),

            if (prefs.showBikes && data.bikes.isNotEmpty)
              GearSectionSliver(
                title: 'Велосипед',
                items: data.bikes,
                isBike: true,
                onItemTap: _openBikesView,
              ),

            // ───────────────── Личные рекорды ─────────────────
            const SliverToBoxAdapter(child: _SectionTitle('Личные рекорды')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _PRRow(items: data.prs)),

            // ───────────────── Показатели ─────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            const SliverToBoxAdapter(child: _SectionTitle('Показатели')),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _MetricsCard(data: data.metrics)),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

/// ───────────────────── Мелкие презентеры (чистая верстка без логики) ─────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    // Заголовок секций внутри ленты
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActivityScroller extends StatelessWidget {
  final List<_ActItem>
  items; // список элементов активности (иконка + значение + подпись)
  const _ActivityScroller({required this.items});

  @override
  Widget build(BuildContext context) {
    // Горизонтальный список карточек активности (ходьба/бег/вел/плавание)
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (_, i) => _ActivityCard(items[i]),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }
}

// Простой контейнер данных для карточки активности (UI-слой)
class _ActItem {
  final String asset; // путь к локальной картинке
  final String value; // числовое значение (например: "12 км")
  final String label; // подпись под числом (например: "Бег")
  _ActItem(this.asset, this.value, this.label);
}

class _ActivityCard extends StatelessWidget {
  final _ActItem item;
  const _ActivityCard(this.item);

  @override
  Widget build(BuildContext context) {
    // Одна карточка активности
    return SizedBox(
      width: 120,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Картинка (иконка вида активности)
            ClipOval(
              child: Image.asset(
                item.asset,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            // Значение (крупный текст)
            Text(
              item.value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            // Подпись (мелкий текст)
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PRRow extends StatelessWidget {
  final List<(PRAsset, String)> items; // список кортежей (иконка, время)
  const _PRRow({required this.items});

  @override
  Widget build(BuildContext context) {
    // Ряд из 4 бейджей с PR (5k/10k/21k/42k) и временем
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: items
              .map((e) => _PRBadge(asset: e.$1.path, time: e.$2))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PRBadge extends StatelessWidget {
  final String asset; // путь к локальной картинке медали/дистанции
  final String time; // строка времени PR
  const _PRBadge({required this.asset, required this.time});

  @override
  Widget build(BuildContext context) {
    // Один бейдж из секции PR
    return Column(
      children: [
        Image.asset(asset, width: 72, height: 72, fit: BoxFit.contain),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
      ],
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final MetricsData data; // данные показателей (VO2max, темп, мощность и т.д.)
  const _MetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    // Готовим строки для отображения: иконка, подпись, значение справа
    final rows = <(IconData, String, String)>[
      (
        CupertinoIcons.arrow_right,
        'Среднее расстояние в неделю',
        data.avgWeekDistance,
      ),
      (CupertinoIcons.heart, 'МПК', data.vo2max),
      (CupertinoIcons.speedometer, 'Средний темп', data.avgPace),
      (CupertinoIcons.bolt, 'Мощность', data.power),
      (CupertinoIcons.waveform, 'Каденс', data.cadence),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: List.generate(rows.length, (i) {
            final r = rows[i];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(r.$1, size: 16, color: AppColors.brandPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.$2,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        r.$3,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != rows.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.divider,
                    indent: 40,
                    endIndent: 10,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// Вспомогательный виджет: центрирует любой child в SliverFillRemaining (для экранов статуса)
class SliverFillRemainingCentered extends StatelessWidget {
  final Widget child;
  const SliverFillRemainingCentered({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverFillRemaining(hasScrollBody: false, child: Center(child: child)),
      ],
    );
  }
}
