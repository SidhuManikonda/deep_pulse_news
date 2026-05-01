import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../data/repositories/news_repository.dart';

class ReportBottomSheet extends StatefulWidget {
  final String type; // "news" or "comment"
  final int itemId;
  final VoidCallback? onReported;

  const ReportBottomSheet({
    super.key,
    required this.type,
    required this.itemId,
    this.onReported,
  });

  static void show(
    BuildContext context, {
    required String type,
    required int itemId,
    VoidCallback? onReported,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBottomSheet(
        type: type,
        itemId: itemId,
        onReported: onReported,
      ),
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  static const List<String> _reasons = [
    'Fake News',
    'Misleading Content',
    'Hate Speech',
    'Violence',
    'Spam',
    'Inappropriate Content',
    'Copyright Violation',
    'Other',
  ];

  String? _selectedReason;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    final repository = NewsRepositoryImpl();
    final description = _descriptionController.text.trim();
    final success = await repository.sendReport(
      type: widget.type,
      itemId: widget.itemId,
      reason: _selectedReason!,
      description: description.isNotEmpty ? description : null,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    Navigator.pop(context);

    if (success) {
      widget.onReported?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report submitted successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit report. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  'Report ${widget.type == 'news' ? 'News' : 'Comment'}',
                  style: TextStyle(
                    fontSize: scaledFontSize(18),
                    fontWeight: FontWeight.bold,
                    color: theme.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a reason for reporting',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                // Reason chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reasons.map((reason) {
                    final isSelected = _selectedReason == reason;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedReason = reason),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.appPrimary.withOpacity(0.12)
                              : theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? theme.appPrimary
                                : theme.appGrey300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: scaledFontSize(13),
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? theme.appPrimary
                                : theme.appTextPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Description field
                Text(
                  'Additional details${_selectedReason == 'Other' ? '' : ' (optional)'}',
                  style: TextStyle(
                    fontSize: scaledFontSize(13),
                    fontWeight: FontWeight.w500,
                    color: theme.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Provide more details about the issue...',
                    hintStyle: TextStyle(
                      color: theme.appTextLight,
                      fontSize: scaledFontSize(13),
                    ),
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.appGrey300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.appGrey300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.appPrimary),
                    ),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  style: TextStyle(
                    fontSize: scaledFontSize(14),
                    color: theme.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed:
                        (_selectedReason != null && !_isSubmitting)
                            ? _submit
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.appPrimary,
                      disabledBackgroundColor: theme.appGrey300,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit Report',
                            style: TextStyle(
                              fontSize: scaledFontSize(15),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
