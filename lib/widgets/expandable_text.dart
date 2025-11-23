// lib/widgets/expandable_text.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Виджет для отображения текста с возможностью раскрытия
/// Показывает 3 строки, остальное скрывает с кнопкой "Показать все"
class ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? textStyle;
  final int maxLines;

  const ExpandableText({
    super.key,
    required this.text,
    this.textStyle,
    this.maxLines = 3,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Определяем, нужно ли раскрытие текста
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.text,
            style: widget.textStyle ?? AppTextStyles.h14w4,
          ),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);
        final needsExpansion = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: (widget.textStyle ?? AppTextStyles.h14w4).copyWith(
                color: AppColors.getTextPrimaryColor(context),
              ),
              maxLines: _isExpanded ? null : widget.maxLines,
              overflow:
                  _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (needsExpansion && !_isExpanded) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = true;
                  });
                },
                child: Text(
                  'Показать все',
                  style: (widget.textStyle ?? AppTextStyles.h14w4).copyWith(
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            ],
            if (_isExpanded && needsExpansion) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = false;
                  });
                },
                child: Text(
                  'Скрыть',
                  style: (widget.textStyle ?? AppTextStyles.h14w4).copyWith(
                    color: AppColors.getIconSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

