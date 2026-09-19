import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool interactive;
  final ValueChanged<int>? onRatingChanged;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starRating = index + 1;
        return GestureDetector(
          onTap: interactive
              ? () => onRatingChanged?.call(starRating)
              : null,
          child: Icon(
            starRating <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            size: size,
            color: starRating <= rating
                ? (activeColor ?? AppColors.warning)
                : (inactiveColor ?? AppColors.textTertiary),
          ),
        );
      }),
    );
  }
}

class InteractiveStarRating extends StatefulWidget {
  final int initialRating;
  final int maxRating;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final ValueChanged<int>? onRatingChanged;

  const InteractiveStarRating({
    super.key,
    this.initialRating = 0,
    this.maxRating = 5,
    this.size = 32,
    this.activeColor,
    this.inactiveColor,
    this.onRatingChanged,
  });

  @override
  State<InteractiveStarRating> createState() => _InteractiveStarRatingState();
}

class _InteractiveStarRatingState extends State<InteractiveStarRating> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxRating, (index) {
        final starRating = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = starRating;
            });
            widget.onRatingChanged?.call(starRating);
          },
          onHorizontalDragUpdate: (details) {
            final renderBox = context.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              final localPosition = renderBox.globalToLocal(details.globalPosition);
              final starWidth = widget.size + 4;
              final newRating = ((localPosition.dx / starWidth).ceil()).clamp(1, widget.maxRating);
              if (newRating != _currentRating) {
                setState(() {
                  _currentRating = newRating;
                });
                widget.onRatingChanged?.call(newRating);
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starRating <= _currentRating ? Icons.star_rounded : Icons.star_border_rounded,
              size: widget.size,
              color: starRating <= _currentRating
                  ? (widget.activeColor ?? AppColors.warning)
                  : (widget.inactiveColor ?? AppColors.textTertiary),
            ),
          ),
        );
      }),
    );
  }
}

class StarRatingDisplay extends StatelessWidget {
  final double rating;
  final int count;
  final double starSize;
  final double fontSize;

  const StarRatingDisplay({
    super.key,
    required this.rating,
    required this.count,
    this.starSize = 18,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final hasHalfStar = (rating - fullStars) >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(fullStars, (index) => Icon(
              Icons.star_rounded,
              size: starSize,
              color: AppColors.warning,
            )),
        if (hasHalfStar)
          Icon(
            Icons.star_half_rounded,
            size: starSize,
            color: AppColors.warning,
          ),
        ...List.generate(emptyStars, (index) => Icon(
              Icons.star_border_rounded,
              size: starSize,
              color: AppColors.textTertiary,
            )),
        const SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} ★',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count évaluations',
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}