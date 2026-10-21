import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class OpdSearchBar extends StatelessWidget {
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const OpdSearchBar({
    super.key,
    this.hint = 'Search...',
    required this.value,
    required this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBorder
              : AppColors.lightBorder,
        ),
      ),
      child: TextField(
        controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.primaryBlue),
          suffixIcon: value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
