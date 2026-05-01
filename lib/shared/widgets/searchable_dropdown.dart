import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_font_sizes.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_shadows.dart';

class SearchableDropdown<T> extends StatefulWidget {
  final String label;
  final IconData icon;
  final String? selectedValue;
  final bool isLoading;
  final List<T> items;
  final String Function(T) getName;
  final void Function(T) onSelected;

  const SearchableDropdown({
    super.key,
    required this.label,
    required this.icon,
    this.selectedValue,
    this.isLoading = false,
    required this.items,
    required this.getName,
    required this.onSelected,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  bool _isOpen = false;
  String _query = '';
  final _searchFocus = FocusNode();

  List<T> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((e) => widget.getName(e).toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _open() {
    if (_isOpen || widget.isLoading || widget.items.isEmpty) return;
    setState(() {
      _isOpen = true;
      _query = '';
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _close() {
    setState(() => _isOpen = false);
    _searchFocus.unfocus();
  }

  void _select(T item) {
    widget.onSelected(item);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedValue != null;

    if (widget.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg - 2,
          vertical: AppSpacing.md + 1,
        ),
        decoration: BoxDecoration(
          color: theme.appCard,
          borderRadius: AppRadius.smAll,
          border: Border.all(color: theme.appDivider),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: theme.appGrey400),
            const SizedBox(width: AppSpacing.sm + 2),
            Text(
              'Loading ${widget.label}...',
              style: TextStyle(
                fontSize: scaledFontSize(14),
                color: theme.appGrey400,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.appGrey400,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Trigger
        GestureDetector(
          onTap: _isOpen ? _close : _open,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg - 2,
              vertical: AppSpacing.md + 1,
            ),
            decoration: BoxDecoration(
              color: theme.appCard,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: theme.appDivider),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: theme.appGrey400),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    isSelected
                        ? widget.selectedValue!
                        : 'Select ${widget.label}',
                    style: TextStyle(
                      fontSize: scaledFontSize(14),
                      color: isSelected
                          ? theme.appTextPrimary
                          : theme.appGrey400,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: theme.appGrey400,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Dropdown panel
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            constraints: const BoxConstraints(maxHeight: 210),
            decoration: BoxDecoration(
              color: theme.appCard,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: theme.appDivider),
              boxShadow: theme.shadowMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search field
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm + 2,
                    AppSpacing.xs + 2,
                    AppSpacing.sm + 2,
                    AppSpacing.xs + 2,
                  ),
                  child: TextField(
                    focusNode: _searchFocus,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(
                      fontSize: scaledFontSize(13),
                      color: theme.appTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.label.toLowerCase()}...',
                      hintStyle: TextStyle(
                        color: theme.appGrey300,
                        fontSize: scaledFontSize(13),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.appGrey300,
                        size: 18,
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.xlAll,
                        borderSide: BorderSide(color: theme.appDivider),
                      ),
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm + 2,
                      ),
                    ),
                  ),
                ),
                // Results list
                Flexible(
                  child: _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Center(
                            child: Text(
                              'No results',
                              style: TextStyle(
                                fontSize: scaledFontSize(13),
                                color: theme.appGrey300,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xs / 2,
                          ),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final item = _filtered[i];
                            final name = widget.getName(item);
                            final selected = name == widget.selectedValue;
                            return InkWell(
                              onTap: () => _select(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg - 2,
                                  vertical: AppSpacing.sm + 2,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: scaledFontSize(13),
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: selected
                                              ? theme.appTextSecondary
                                              : theme.appTextSecondary,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: theme.appGrey500,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          crossFadeState: _isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
