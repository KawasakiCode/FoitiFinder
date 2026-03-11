import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable 6-digit OTP input widget.
///
/// Features:
///  - Auto-advances focus to the next box when a digit is typed.
///  - Moves focus back to the previous box on backspace when the current box is empty.
///  - Handles full-code paste (e.g. "123456") by distributing digits across all boxes.
///  - Enables SMS autofill hints so iOS/Android suggest the code above the keyboard.
///
/// Usage:
/// ```dart
/// OtpInputWidget(
///   onCompleted: (code) => print('OTP: $code'),
///   onChanged: (code) => print('Current: $code'),
/// )
/// ```
class OtpInputWidget extends StatefulWidget {
  /// Called when all 6 digits have been entered. Receives the full code string.
  final void Function(String code)? onCompleted;

  /// Called every time any digit changes. Receives the current partial/full code.
  final void Function(String code)? onChanged;

  /// Number of OTP digits (defaults to 6).
  final int length;

  /// Style applied to the digit text inside each box.
  final TextStyle? digitStyle;

  /// Border colour for an unfocused box.
  final Color? borderColor;

  /// Border colour for the currently focused box.
  final Color? focusedBorderColor;

  /// Background fill colour for each box.
  final Color? fillColor;

  const OtpInputWidget({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.length = 6,
    this.digitStyle,
    this.borderColor,
    this.focusedBorderColor,
    this.fillColor,
  });

  @override
  State<OtpInputWidget> createState() => _OtpInputWidgetState();
}

class _OtpInputWidgetState extends State<OtpInputWidget> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  String get _currentCode =>
      _controllers.map((c) => c.text).join();

  void _moveFocusTo(int index) {
    if (index >= 0 && index < widget.length) {
      FocusScope.of(context).requestFocus(_focusNodes[index]);
    }
  }

  // ─── feature 1 & 3: auto-advance + paste ────────────────────────────────────

  void _onChanged(int index, String value) {
    // ── Feature 3: Paste handling ───────────────────────────────────────────
    // When the user pastes a string that is longer than 1 character we distribute
    // the digits across all controllers and dismiss the keyboard.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), ''); // keep only digits
      for (int i = 0; i < widget.length; i++) {
        _controllers[i].text = i < digits.length ? digits[i] : '';
      }

      // Dismiss keyboard after a successful paste
      FocusScope.of(context).unfocus();

      widget.onChanged?.call(_currentCode);
      if (digits.length >= widget.length) {
        widget.onCompleted?.call(_currentCode);
      }
      return;
    }

    // ── Feature 1: Auto-advance ─────────────────────────────────────────────
    if (value.length == 1) {
      if (index < widget.length - 1) {
        _moveFocusTo(index + 1);
      } else {
        // Last box filled — dismiss keyboard
        _focusNodes[index].unfocus();
      }
    }

    widget.onChanged?.call(_currentCode);

    // Fire onCompleted only when every box has exactly one digit
    if (_controllers.every((c) => c.text.length == 1)) {
      widget.onCompleted?.call(_currentCode);
    }
  }

  // ─── feature 2: backspace trap ──────────────────────────────────────────────

  /// Wraps each [TextFormField] in a [KeyboardListener] so we can intercept the
  /// raw backspace key event before Flutter's text-field logic swallows it.
  ///
  /// Behaviour:
  ///  - If the current box is *empty* and backspace is pressed → move to the
  ///    previous box (and optionally clear it so the user can retype).
  ///  - If the current box has a digit and backspace is pressed → let the
  ///    default field behaviour clear it (no focus change needed).
  KeyEventResult _handleKeyEvent(int index, KeyEvent event) {
    final isBackspace = event.logicalKey == LogicalKeyboardKey.backspace;
    final isKeyDown = event is KeyDownEvent || event is KeyRepeatEvent;

    if (isBackspace && isKeyDown && _controllers[index].text.isEmpty) {
      if (index > 0) {
        _moveFocusTo(index - 1);
        // Optionally clear the previous box so the user can retype it cleanly
        _controllers[index - 1].clear();
        widget.onChanged?.call(_currentCode);
      }
      return KeyEventResult.handled; // stop propagation
    }
    return KeyEventResult.ignored;
  }

  // ─── build ───────────────────────────────────────────────────────────────────

  Widget _buildBox(int index) {
    return KeyboardListener(
      focusNode: FocusNode(), // listener needs its own FocusNode
      onKeyEvent: (event) => _handleKeyEvent(index, event),
      child: SizedBox(
        width: 45,
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          maxLength: 6, // allow >1 so paste can be detected in onChanged
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: widget.digitStyle ??
              const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          // ── Feature 4: SMS autofill hints ──────────────────────────────────
          autofillHints: index == 0
              ? const [AutofillHints.oneTimeCode]
              : null,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            counterText: '', // hide the "0/6" counter Flutter adds
            filled: widget.fillColor != null,
            fillColor: widget.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.borderColor ?? Colors.grey.shade400,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.borderColor ?? Colors.grey.shade400,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.focusedBorderColor ?? Colors.blue,
                width: 2,
              ),
            ),
          ),
          onChanged: (value) => _onChanged(index, value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AutofillGroup is required for SMS autofill to work on both iOS and Android.
    return AutofillGroup(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _buildBox(i),
          );
        }),
      ),
    );
  }
}