import 'package:flutter/material.dart';

class OpdTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final dynamic prefixIcon; // Accepts IconData or Widget
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enablePasswordToggle;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;

  const OpdTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enablePasswordToggle = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<OpdTextField> createState() => _OpdTextFieldState();
}

class _OpdTextFieldState extends State<OpdTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    Widget? effectiveSuffix = widget.suffixIcon;

    if (widget.enablePasswordToggle) {
      effectiveSuffix = IconButton(
        icon: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: Colors.grey,
        ),
        onPressed: () => setState(() => _obscured = !_obscured),
      );
    }

    Widget? effectivePrefix;
    if (widget.prefixIcon is IconData) {
      effectivePrefix = Icon(widget.prefixIcon as IconData, size: 20);
    } else if (widget.prefixIcon is Widget) {
      effectivePrefix = widget.prefixIcon as Widget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          readOnly: widget.readOnly,
          onTap: widget.onTap,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: effectivePrefix,
            suffixIcon: effectiveSuffix,
          ),
        ),
      ],
    );
  }
}

typedef OPDTextField = OpdTextField;
