// lib/screens/lenta/widgets/activity/header/avatar.dart
import 'package:flutter/material.dart';

/// Аватар с безопасным fallback на ассет.
class Avatar extends StatelessWidget {
  final String image;
  final double size;

  const Avatar({super.key, required this.image, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final isNet = image.startsWith('http');
    return isNet
        ? Image.network(
            image,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback(),
          )
        : (image.isNotEmpty
              ? Image.asset(image, width: size, height: size, fit: BoxFit.cover)
              : _fallback());
  }

  Widget _fallback() => Image.asset(
    'assets/Avatar_2.png',
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
}
