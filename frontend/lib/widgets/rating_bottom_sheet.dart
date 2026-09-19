import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'star_rating.dart';

class RatingBottomSheet extends ConsumerStatefulWidget {
  final int tripId;
  final int requestId;
  final int reviewedUserId;
  final String reviewedUserName;
  final String? reviewedUserImage;
  final VoidCallback? onRatingSubmitted;

  const RatingBottomSheet({
    super.key,
    required this.tripId,
    required this.requestId,
    required this.reviewedUserId,
    required this.reviewedUserName,
    this.reviewedUserImage,
    this.onRatingSubmitted,
  });

  static Future<void> show({
    required BuildContext context,
    required int tripId,
    required int requestId,
    required int reviewedUserId,
    required String reviewedUserName,
    String? reviewedUserImage,
    VoidCallback? onRatingSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RatingBottomSheet(
        tripId: tripId,
        requestId: requestId,
        reviewedUserId: reviewedUserId,
        reviewedUserName: reviewedUserName,
        reviewedUserImage: reviewedUserImage,
        onRatingSubmitted: onRatingSubmitted,
      ),
    );
  }

  @override
  ConsumerState<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends ConsumerState<RatingBottomSheet> {
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      setState(() {
        _errorMessage = 'Veuillez sélectionner une note';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final apiService = ApiService();
      await apiService.createRating(
        tripId: widget.tripId,
        requestId: widget.requestId,
        reviewedUserId: widget.reviewedUserId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onRatingSubmitted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Évaluation envoyée avec succès'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: (screenHeight * 0.75).clamp(400.0, 600.0) + keyboardHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Évaluer le transport',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comment s\'est passé votre transport avec ${widget.reviewedUserName} ?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Reviewed user info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: widget.reviewedUserImage != null
                            ? NetworkImage(widget.reviewedUserImage!)
                            : null,
                        child: widget.reviewedUserImage == null
                            ? Text(
                                widget.reviewedUserName.isNotEmpty
                                    ? widget.reviewedUserName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reviewedUserName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                            ),
                            Text(
                              'Vous allez l\'évaluer',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Star rating
                  Text(
                    'Votre note',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 12),
                  InteractiveStarRating(
                    initialRating: _selectedRating,
                    size: 40,
                    onRatingChanged: (rating) {
                      setState(() {
                        _selectedRating = rating;
                        _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_selectedRating > 0)
                    Text(
                      _getRatingLabel(_selectedRating),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getRatingColor(_selectedRating),
                      ),
                    ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Comment field
                  Text(
                    'Commentaire (optionnel)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Partagez votre expérience...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Envoyer l\'évaluation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Très décevant';
      case 2:
        return 'Décevant';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return AppColors.error;
      case 3:
        return AppColors.warning;
      case 4:
      case 5:
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}

// Helper to show rating bottom sheet after completion
Future<void> showRatingIfNeeded({
  required BuildContext context,
  required WidgetRef ref,
  required int tripId,
  required int requestId,
  required int reviewedUserId,
  required String reviewedUserName,
  String? reviewedUserImage,
  required String currentUserId,
}) async {
  await RatingBottomSheet.show(
    context: context,
    tripId: tripId,
    requestId: requestId,
    reviewedUserId: reviewedUserId,
    reviewedUserName: reviewedUserName,
    reviewedUserImage: reviewedUserImage,
  );
}