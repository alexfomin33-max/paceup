// lib/features/map/screens/clubs/tabs/lenta_content.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/error_handler.dart';
import '../../../../../providers/services/api_provider.dart';

/// Контент вкладки "Лента" для детальной страницы клуба
/// Отображает активность участников клуба
class ClubLentaContent extends ConsumerStatefulWidget {
  final int clubId;

  const ClubLentaContent({
    super.key,
    required this.clubId,
  });

  @override
  ConsumerState<ClubLentaContent> createState() => _ClubLentaContentState();
}

class _ClubLentaContentState extends ConsumerState<ClubLentaContent> {
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _limit = 20;
  final ScrollController _scrollController = ScrollController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// ──────────────────────── Загрузка активностей клуба ────────────────────────
  Future<void> _loadActivities({bool reset = false}) async {
    if (_isLoading) return;

    if (reset) {
      setState(() {
        _activities.clear();
        _currentPage = 1;
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore && !reset) return;

    try {
      setState(() => _isLoading = true);

      final api = ref.read(apiServiceProvider);
      final data = await api.get(
        '/get_club_activities.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (data['success'] == true && mounted) {
        final activities = data['activities'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        setState(() {
          if (reset) {
            _activities = activities
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } else {
            _activities.addAll(
              activities.map((item) => item as Map<String, dynamic>),
            );
          }
          _currentPage++;
          _hasMore = hasMore;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'] as String? ?? 'Ошибка загрузки ленты';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorHandler.formatWithContext(
            e,
            context: 'загрузке ленты клуба',
          );
          _isLoading = false;
        });
      }
    }
  }

  /// ──────────────────────── Обработка скролла для пагинации ────────────────────────
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _loadActivities();
    }
  }

  /// ──────────────────────── Обновление ленты ────────────────────────
  void refreshLenta() {
    _loadActivities(reset: true);
  }

  /// ──────────────────────── Получение списка виджетов для SliverList ────────────────────────
  List<Widget> buildActivityWidgets(BuildContext context) {
    if (_error != null && _activities.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: AppColors.getIconSecondaryColor(context),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadActivities(reset: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: AppColors.getSurfaceColor(context),
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ];
    }

    if (_activities.isEmpty && !_isLoading) {
      return [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.news,
                size: 48,
                color: AppColors.getIconSecondaryColor(context),
              ),
              const SizedBox(height: 16),
              Text(
                'Лента пуста',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Участники клуба еще не добавили активности',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (int index = 0; index < _activities.length; index++) {
      final activity = _activities[index];
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.getBorderColor(context),
              width: 1,
            ),
          ),
          child: Text(
            'Активность #${activity['id'] ?? index}',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.getTextPrimaryColor(context),
            ),
          ),
        ),
      );
    }

    if (_hasMore) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CupertinoActivityIndicator(radius: 10),
          ),
        ),
      );
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                size: 48,
                color: AppColors.getIconSecondaryColor(context),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadActivities(reset: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.button,
                  foregroundColor: AppColors.getSurfaceColor(context),
                ),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activities.isEmpty && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.news,
                size: 48,
                color: AppColors.getIconSecondaryColor(context),
              ),
              const SizedBox(height: 16),
              Text(
                'Лента пуста',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Участники клуба еще не добавили активности',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.getTextSecondaryColor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Этот виджет используется внутри CustomScrollView,
    // поэтому возвращаем пустой контейнер
    // Реальный контент будет построен через buildActivityWidgets
    return const SizedBox.shrink();
  }
}
