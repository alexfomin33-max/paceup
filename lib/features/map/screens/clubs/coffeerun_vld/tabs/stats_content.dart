import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../providers/services/api_provider.dart';
import '../../../../../../core/utils/error_handler.dart';
import '../../../../../../core/widgets/transparent_route.dart';
import '../../../../../../features/profile/screens/profile_screen.dart';

class CoffeeRunVldStatsContent extends ConsumerStatefulWidget {
  final int clubId;
  const CoffeeRunVldStatsContent({super.key, required this.clubId});

  @override
  ConsumerState<CoffeeRunVldStatsContent> createState() =>
      _CoffeeRunVldStatsContentState();
}

class _CoffeeRunVldStatsContentState
    extends ConsumerState<CoffeeRunVldStatsContent> {
  int _seg = 0; // 0 неделя, 1 месяц, 2 год
  static const double _kmColW = 70;
  static const int _limit = 10;
  List<_StatRow> _statistics = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  String? _currentPeriod; // Для отслеживания смены периода

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadStatistics(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CoffeeRunVldStatsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clubId != widget.clubId) {
      _loadStatistics(reset: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_loadingMore &&
        !_loading &&
        _hasMore) {
      _loadStatistics(reset: false);
    }
  }

  String _getPeriod() {
    switch (_seg) {
      case 0:
        return 'week';
      case 1:
        return 'month';
      case 2:
        return 'year';
      default:
        return 'week';
    }
  }

  Future<void> _loadStatistics({bool reset = false}) async {
    if (!mounted) return;
    if (_loading || _loadingMore) return;

    final period = _getPeriod();

    // Если период изменился, сбрасываем данные
    if (reset || _currentPeriod != period) {
      _currentPeriod = period;
      _currentPage = 1;
      _hasMore = true;
      // НЕ очищаем список сразу - показываем старые данные до загрузки новых
      // Это предотвращает скачки экрана
      setState(() {
        _loading = true;
        _error = null;
        // _statistics = []; // Убираем очистку списка
      });
      // НЕ сбрасываем скролл - это предотвращает скачки родительского экрана
    } else {
      // Подгрузка следующей страницы
      if (!_hasMore) return;
      setState(() {
        _loadingMore = true;
      });
    }

    try {
      final api = ref.read(apiServiceProvider);

      final data = await api.get(
        '/get_club_statistics.php',
        queryParams: {
          'club_id': widget.clubId.toString(),
          'period': period,
          'page': _currentPage.toString(),
          'limit': _limit.toString(),
        },
      );

      if (!mounted) return;

      if (data['success'] == true) {
        final statistics = data['statistics'] as List<dynamic>? ?? [];
        final hasMore = data['has_more'] as bool? ?? false;

        setState(() {
          final newRows = statistics
              .map((s) {
                final stat = s as Map<String, dynamic>;
                return _StatRow(
                  rank: stat['rank'] as int? ?? 0,
                  name: stat['name'] as String? ?? 'Пользователь',
                  avatarUrl: stat['avatar_url'] as String? ?? '',
                  distance: (stat['distance'] as num?)?.toDouble() ?? 0.0,
                  userId: stat['user_id'] as int?,
                  isCurrentUser: stat['is_current_user'] as bool? ?? false,
                );
              })
              .where(
                (row) => row.distance > 0.0,
              ) // Фильтруем пользователей с нулевыми показателями
              .toList();

          if (reset || _currentPage == 1) {
            // Заменяем данные только после загрузки новых
            _statistics = newRows;
          } else {
            _statistics.addAll(newRows);
          }

          _hasMore = hasMore;
          _currentPage++;
          _loading = false;
          _loadingMore = false;
        });
      } else {
        setState(() {
          _error = data['message'] as String? ?? 'Ошибка загрузки статистики';
          _loading = false;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.format(e);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onPeriodChanged(int index) {
    if (_seg == index) return; // Если период не изменился, ничего не делаем
    setState(() {
      _seg = index;
    });
    _loadStatistics(reset: true);
  }

  void _navigateToProfile(int userId) {
    Navigator.of(
      context,
    ).push(TransparentPageRoute(builder: (_) => ProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // сегмент
        Container(
          decoration: BoxDecoration(
            color: AppColors.disabled,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(
            children: List.generate(3, (i) {
              final labels = ['Эта неделя', 'Этот месяц', 'Этот год'];
              final selected = _seg == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onPeriodChanged(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        // список с прокруткой
        if (_error != null && _statistics.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else if (_statistics.isEmpty && !_loading)
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(
              child: Text(
                'Нет данных за выбранный период',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          Stack(
            children: [
              ListView.builder(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _statistics.length + (_loadingMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _statistics.length) {
                    // Индикатор загрузки в конце списка
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final m = _statistics[i];
                  final isCurrentUser = m.isCurrentUser;
                  return Column(
                    children: [
                      InkWell(
                        onTap: m.userId != null
                            ? () => _navigateToProfile(m.userId!)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  m.rank.toString(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: isCurrentUser
                                        ? Colors.green
                                        : AppColors.textPrimary,
                                    fontWeight: isCurrentUser
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: m.avatarUrl,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 36,
                                    height: 36,
                                    color: AppColors.border,
                                    child: const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 36,
                                        height: 36,
                                        color: AppColors.border,
                                        child: const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: isCurrentUser
                                        ? Colors.green
                                        : AppColors.textPrimary,
                                    fontWeight: isCurrentUser
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: _kmColW,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${m.distance.toStringAsFixed(2).replaceAll('.', ',')} км',
                                    softWrap: false,
                                    overflow: TextOverflow.fade,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: isCurrentUser
                                          ? Colors.green
                                          : AppColors.textPrimary,
                                      // табличные цифры, чтобы разряды не «прыгали»
                                      fontFeatures: [
                                        const FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i != _statistics.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.border,
                        ),
                    ],
                  );
                },
              ),
              // Индикатор загрузки поверх списка при смене периода
              if (_loading && _statistics.isNotEmpty)
                Container(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _StatRow {
  final int rank;
  final String name;
  final String avatarUrl;
  final double distance;
  final int? userId;
  final bool isCurrentUser;
  const _StatRow({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.distance,
    this.userId,
    required this.isCurrentUser,
  });
}
