import 'dart:math';
import 'package:flutter/material.dart';

enum SubmissionStatus {
  idle,
  submitting,
  success,
  error,
}

/// A lightweight, robust submission guard that manages in-flight submission state,
/// generates stable idempotency keys, and synchronously blocks rapid duplicate clicks.
class SubmissionController extends ChangeNotifier {
  SubmissionStatus _status = SubmissionStatus.idle;
  String? _currentIdempotencyKey;
  String? _errorMessage;
  int _lastSubmissionTime = 0;

  SubmissionStatus get status => _status;
  bool get isSubmitting => _status == SubmissionStatus.submitting;
  bool get isSuccess => _status == SubmissionStatus.success;
  bool get hasError => _status == SubmissionStatus.error;
  String? get errorMessage => _errorMessage;
  String? get currentIdempotencyKey => _currentIdempotencyKey;

  /// Generate a cryptographically stable idempotency key for this logical operation.
  String generateKey([String prefix = 'opd']) {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final hexStr = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$hexStr';
  }

  /// Begin a submission attempt.
  /// Synchronously checks if already submitting or if double-clicked (< 500ms).
  /// Returns false if duplicate request blocked; true if can proceed.
  bool begin() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_status == SubmissionStatus.submitting) {
      debugPrint('🛡️ [DUPLICATE GUARD] Synchronously blocked duplicate click while request in flight.');
      return false;
    }

    if (now - _lastSubmissionTime < 400) {
      debugPrint('🛡️ [DUPLICATE GUARD] Synchronously blocked rapid double-click within 400ms.');
      return false;
    }

    _lastSubmissionTime = now;
    _status = SubmissionStatus.submitting;
    _errorMessage = null;
    _currentIdempotencyKey ??= generateKey();
    notifyListeners();
    return true;
  }

  /// Complete submission successfully. Retains idempotency key until fresh reset.
  void completeSuccess() {
    _status = SubmissionStatus.success;
    _errorMessage = null;
    notifyListeners();
  }

  /// Complete submission with an error. Preserves the idempotency key for retry.
  void completeError(String error) {
    _status = SubmissionStatus.error;
    _errorMessage = error;
    notifyListeners();
  }

  /// Reset form state intentionally (e.g. "Register Another Patient").
  /// Clears the idempotency key so the next submission uses a fresh operation token.
  void reset() {
    _status = SubmissionStatus.idle;
    _currentIdempotencyKey = null;
    _errorMessage = null;
    notifyListeners();
  }
}

/// A responsive, accessible submit button with duplicate-submission protection,
/// animated loading spinner, and configurable progress text.
class GuardedSubmitButton extends StatelessWidget {
  final SubmissionController controller;
  final VoidCallback onPressed;
  final String label;
  final String submittingLabel;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const GuardedSubmitButton({
    super.key,
    required this.controller,
    required this.onPressed,
    required this.label,
    this.submittingLabel = 'Submitting...',
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isSubmitting = controller.isSubmitting;
        final isSuccess = controller.isSuccess;

        final buttonStyle = ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
          foregroundColor: foregroundColor ?? Colors.white,
          disabledBackgroundColor: (backgroundColor ?? Theme.of(context).primaryColor).withOpacity(0.65),
          disabledForegroundColor: (foregroundColor ?? Colors.white).withOpacity(0.85),
          minimumSize: Size(width ?? double.infinity, height),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(10),
          ),
          elevation: isSubmitting ? 0 : 2,
        );

        return SizedBox(
          width: width,
          height: height,
          child: ElevatedButton(
            style: buttonStyle,
            onPressed: isSubmitting ? null : onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSubmitting) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    submittingLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ] else if (isSuccess) ...[
                  const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ] else ...[
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
