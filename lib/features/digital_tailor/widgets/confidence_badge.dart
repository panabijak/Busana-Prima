import 'package:flutter/material.dart';

/// A small badge that displays confidence level with color coding.
///
/// Colors:
/// - Green (≥ 85%): Sangat Tinggi
/// - Light green (70-84%): Tinggi
/// - Orange (55-69%): Sedang
/// - Red (< 55%): Rendah
class ConfidenceBadge extends StatelessWidget {
  /// Confidence score (0.0 to 1.0).
  final double confidence;

  /// Optional override for the label text.
  final String? label;

  /// Size variant.
  final ConfidenceBadgeSize size;

  const ConfidenceBadge({
    super.key,
    required this.confidence,
    this.label,
    this.size = ConfidenceBadgeSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final text = label ?? _label;
    final fontSize = size == ConfidenceBadgeSize.small ? 10.0 : 12.0;
    final iconSize = size == ConfidenceBadgeSize.small ? 12.0 : 14.0;
    final hPad = size == ConfidenceBadgeSize.small ? 6.0 : 10.0;
    final vPad = size == ConfidenceBadgeSize.small ? 2.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.70) return Colors.lightGreen.shade700;
    if (confidence >= 0.55) return Colors.orange;
    return Colors.red;
  }

  String get _label {
    if (confidence >= 0.85) return 'Sangat Tinggi';
    if (confidence >= 0.70) return 'Tinggi';
    if (confidence >= 0.55) return 'Sedang';
    return 'Rendah';
  }
}

/// A small colored dot indicating confidence level for inline use.
class ConfidenceDot extends StatelessWidget {
  final double confidence;

  const ConfidenceDot({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
    );
  }

  Color get _color {
    if (confidence >= 0.85) return Colors.green;
    if (confidence >= 0.70) return Colors.lightGreen.shade700;
    if (confidence >= 0.55) return Colors.orange;
    return Colors.red;
  }
}

enum ConfidenceBadgeSize { small, medium }
