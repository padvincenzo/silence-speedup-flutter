// This file is part of Silence SpeedUp, a Flutter app that speeds up your
// videos by speeding up (or removing) silences, using FFmpeg.
//
// Author: Vincenzo Padula <padvincenzo@gmail.com>
// License: GNU GPL v3 or later <http://www.gnu.org/copyleft/gpl.html>

import 'package:flutter/material.dart';

/// Width given to the label column, so every row in the sheet lines up.
const double _labelWidth = 168;

/// A titled group of settings.
class SettingSection extends StatelessWidget {
  const SettingSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// One label-plus-control line. Stacks the control under the label when the
/// sheet is narrow.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    required this.child,
    this.help,
  });

  final String label;
  final Widget child;

  /// Shown as a tooltip on the label, for the settings whose effect is not
  /// obvious from the name alone.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final Widget labelWidget = Tooltip(
      message: help ?? '',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (help != null) ...<Widget>[
            const SizedBox(width: 4),
            Icon(
              Icons.help_outline,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                labelWidget,
                const SizedBox(height: 6),
                child,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(width: _labelWidth, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

/// A slider whose stops are list indexes, with the selected label pinned to
/// its right so the value is readable while dragging.
class IndexSlider extends StatelessWidget {
  const IndexSlider({
    super.key,
    required this.value,
    required this.max,
    required this.labelAt,
    required this.onChanged,
    this.min = 0,
  });

  final int value;
  final int min;
  final int max;

  /// Text for a given index, used both on the chip and in the slider label.
  final String Function(int index) labelAt;

  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max > min ? max - min : null,
            label: labelAt(value),
            onChanged: onChanged == null
                ? null
                : (double raw) => onChanged!(raw.round()),
          ),
        ),
        const SizedBox(width: 8),
        _ValueChip(text: labelAt(value)),
      ],
    );
  }
}

/// A continuous slider for a seconds or quality value.
class ValueSlider extends StatelessWidget {
  const ValueSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.format,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final String Function(double value) format;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final int divisions = ((max - min) / step).round();

    return Row(
      children: <Widget>[
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null,
            label: format(value),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        _ValueChip(text: format(value)),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Thin wrapper over [DropdownButtonFormField] with consistent density.
class OptionDropdown<T> extends StatelessWidget {
  const OptionDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isDense: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
