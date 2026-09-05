//A switch whose animation we control.
//
//Material's Switch animates over a hardcoded 200ms (kToggleDuration inside
//switch.dart). There is no parameter and no SwitchThemeData field for it, so
//the only way to slow the toggle down is to draw it ourselves.
//
//COLOURS ARE NOT DUPLICATED HERE: they resolve out of the app's existing
//SwitchThemeData in app_theme.dart, so this stays in step with the rest of the
//theme and dark mode keeps working without a second set of constants.

import 'package:flutter/material.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  //null disables the switch, matching Switch's own convention
  final ValueChanged<bool>? onChanged;
  //Material uses 200ms, which reads as instant. This is the whole point of the
  //widget - override per use if some switch wants to feel different.
  final Duration duration;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.duration = const Duration(milliseconds: 300),
  });

  //M3 metrics, so it sits the same as a real Switch next to a row of text
  static const double _trackWidth = 52;
  static const double _trackHeight = 32;
  static const double _trackPadding = 4;
  //the thumb grows as it travels, which is what makes the movement read as
  //deliberate rather than as a dot sliding
  static const double _thumbOff = 20;
  static const double _thumbOn = 24;

  //Material's Switch defaults to MaterialTapTargetSize.padded, which pads it
  //out to a 48x48 minimum tap target. That padding is what gave the old
  //switches room above and below inside a row - drawing the bare 32px track
  //made them sit flush against the text. Restored here rather than at each
  //call site so no usage can forget it, and INSIDE the GestureDetector so the
  //padded area stays tappable exactly as Material's does.
  static const double _minTapTarget = 48;
  static const double _verticalPadding = (_minTapTarget - _trackHeight) / 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final switchTheme = theme.switchTheme;
    final bool enabled = onChanged != null;

    final states = <WidgetState>{
      if (value) WidgetState.selected,
      if (!enabled) WidgetState.disabled,
    };

    final Color trackColor =
        switchTheme.trackColor?.resolve(states) ??
        (value
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest);
    final Color thumbColor =
        switchTheme.thumbColor?.resolve(states) ??
        (value ? theme.colorScheme.onPrimary : theme.colorScheme.outline);

    final double thumbSize = value ? _thumbOn : _thumbOff;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        //the whole track is the target, not just the thumb
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _verticalPadding),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeInOutCubic,
              width: _trackWidth,
              height: _trackHeight,
              padding: const EdgeInsets.all(_trackPadding),
              decoration: BoxDecoration(
                color: trackColor,
                borderRadius: BorderRadius.circular(_trackHeight / 2),
              ),
              child: AnimatedAlign(
                duration: duration,
                curve: Curves.easeInOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  width: thumbSize,
                  height: thumbSize,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
