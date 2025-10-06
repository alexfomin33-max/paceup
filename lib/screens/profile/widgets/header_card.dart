import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../edit_profile_screen.dart';
import '../state/communications/communication_prefs.dart';
import '../../../models/user_profile_header.dart';

class HeaderCard extends StatelessWidget {
  final UserProfileHeader? profile;
  final int userId;
  const HeaderCard({super.key, this.profile, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: (profile?.avatar != null && profile!.avatar!.isNotEmpty)
                    ? Image.network(
                        profile!.avatar!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/avatar.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
              ),

              Positioned(
                bottom: -20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(                        
                        (() {
                          final fn = (profile?.firstName ?? '').trim();
                          final ln = (profile?.lastName ?? '').trim();
                          final full = [fn, ln].where((s) => s.isNotEmpty).join(' ').trim();
                          return full.isNotEmpty ? full : 'Константин Разумовский';
                        })(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    SizedBox(width: 6),
                    _SmallIconBtn(
                      icon: CupertinoIcons.pencil,
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => EditProfileScreen(userId: userId),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  _subtitleFrom(profile) ?? '38 лет, Санкт-Петербург',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    _FollowStat(
                      label: 'Подписки',
                      value: (profile?.following ?? 736).toString(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const CommunicationPrefsPage(
                              startIndex: 0,
                            ), // Подписки
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 18),
                    _FollowStat(
                      label: 'Подписчики',
                      value: (profile?.followers ?? 659).toString(),
                      onTap: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => const CommunicationPrefsPage(
                              startIndex: 1,
                            ), // Подписчики
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _yearsRu(int? n) {
    if (n == null) return 'лет';
    final last2 = n % 100;
    if (11 <= last2 && last2 <= 14) return 'лет';
    switch (n % 10) {
      case 1: return 'год';
      case 2:
      case 3:
      case 4: return 'года';
      default: return 'лет';
    }
  }

  String? _subtitleFrom(UserProfileHeader? p) {
    if (p == null) return null;
    final parts = <String>[];
    if (p.age != null) parts.add('${p.age} ${_yearsRu(p.age)}');
    if ((p.city ?? '').isNotEmpty) parts.add(p.city!);
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _SmallIconBtn({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, size: 16, color: AppColors.text),
      ),
    );
  }
}

class _FollowStat extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _FollowStat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Делаем удобную область тапа и не меняем внешний вид текста
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.text,
            ),
            children: [
              TextSpan(text: '$label: '),
              const TextSpan(
                text: '\u200B',
              ), // микропробел для ровного переноса
              TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
