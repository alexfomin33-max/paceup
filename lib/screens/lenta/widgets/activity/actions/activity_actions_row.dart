// lib/screens/lenta/widgets/activity/actions/activity_actions_row.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../../../../../theme/app_theme.dart';

/// Панель действий: лайк/комменты/совместно.
/// Здесь локальная анимация лайка + вызов API лайка.
/// Комментарии/совместно — пробрасываются наружу колбэками.
class ActivityActionsRow extends StatefulWidget {
  final int activityId;
  final int currentUserId;
  final int initialLikes;
  final bool initiallyLiked;
  final int commentsCount;

  final VoidCallback? onOpenComments;
  final VoidCallback? onOpenTogether;

  const ActivityActionsRow({
    super.key,
    required this.activityId,
    required this.currentUserId,
    required this.initialLikes,
    required this.initiallyLiked,
    required this.commentsCount,
    this.onOpenComments,
    this.onOpenTogether,
  });

  @override
  State<ActivityActionsRow> createState() => _ActivityActionsRowState();
}

class _ActivityActionsRowState extends State<ActivityActionsRow>
    with SingleTickerProviderStateMixin {
  static const String _likeEndpoint =
      'http://api.paceup.ru/activity_likes_toggle.php';

  late bool isLiked;
  late int likesCount;
  bool _busy = false;

  late AnimationController _likeController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    isLiked = widget.initiallyLiked;
    likesCount = widget.initialLikes;

    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );
    _likeController.addStatusListener((s) {
      if (s == AnimationStatus.completed) _likeController.reverse();
    });
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  Future<void> _onLikeTap() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });
    _likeController.forward(from: 0);

    final ok = await _sendLike(
      activityId: widget.activityId,
      userId: widget.currentUserId,
      isLikedNow: isLiked,
    );

    if (!ok && mounted) {
      setState(() {
        isLiked = !isLiked;
        likesCount += isLiked ? 1 : -1;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _sendLike({
    required int activityId,
    required int userId,
    required bool isLikedNow,
  }) async {
    final uri = Uri.parse(_likeEndpoint);
    try {
      final res = await http
          .post(
            uri,
            body: jsonEncode({
              'userId': '$userId',
              'activityId': '$activityId',
              'type': 'activity',
              'action': isLikedNow ? 'like' : 'dislike',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final raw = utf8.decode(res.bodyBytes);
      dynamic data;
      try {
        data = json.decode(raw);
      } catch (_) {
        data = null;
      }

      bool ok = false;
      int? serverLikes;

      if (data is Map<String, dynamic>) {
        ok = data['ok'] == true || data['status'] == 'ok';
        serverLikes = int.tryParse('${data['likes']}');
      } else if (data is List &&
          data.isNotEmpty &&
          data.first is Map<String, dynamic>) {
        final m = data.first as Map<String, dynamic>;
        ok = m['ok'] == true || m['status'] == 'ok';
        serverLikes = int.tryParse('${m['likes']}');
      } else {
        final t = raw.trim().toLowerCase();
        ok = (res.statusCode == 200) && (t == 'ok' || t == '1' || t == 'true');
      }

      if (ok && serverLikes != null && mounted) {
        setState(() => likesCount = serverLikes!);
      }
      return ok;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Левая группа: лайк + комментарии
        Row(
          children: [
            GestureDetector(
              onTap: _onLikeTap,
              child: Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ScaleTransition(
                  scale: _likeAnimation,
                  child: Icon(
                    isLiked ? CupertinoIcons.heart_solid : CupertinoIcons.heart,
                    size: 20,
                    color: isLiked ? AppColors.error : AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 0),
            Text(likesCount.toString(), style: AppTextStyles.normaltext),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onOpenComments,
              child: const Icon(
                CupertinoIcons.chat_bubble,
                size: 20,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              widget.commentsCount.toString(),
              style: AppTextStyles.normaltext,
            ),
          ],
        ),

        // Правая группа: «совместно»
        Row(
          children: [
            const Icon(
              CupertinoIcons.person_2,
              size: 20,
              color: AppColors.success,
            ),
            const SizedBox(width: 4),
            const Text('48', style: AppTextStyles.normaltext),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onOpenTogether,
              child: const Icon(
                CupertinoIcons.person_crop_circle_badge_plus,
                size: 20,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Text('3', style: AppTextStyles.normaltext),
          ],
        ),
      ],
    );
  }
}
