import 'package:flutter/material.dart';

import '../config/measurement_debug_flags.dart';
import '../models/calibration_result.dart';
import '../models/measurement_debug.dart';
import '../services/validation/quality_controller.dart';

/// Developer-only panel showing calibration + measurement computation traces.
///
/// Shown on [ResultsScreen] after success AND on [ScannerScreen] when
/// processing fails — so engineers can diagnose rejections without a
/// successful scan.
class MeasurementDebugPanel extends StatelessWidget {
  final CalibrationResult? frontCalibration;
  final CalibrationResult? sideCalibration;
  final QualityReport? qualityReport;
  final List<MeasurementDebugTrace>? measurementDebug;

  /// When true, renders as a compact scrollable box (scanner overlay).
  final bool compact;

  const MeasurementDebugPanel({
    super.key,
    this.frontCalibration,
    this.sideCalibration,
    this.qualityReport,
    this.measurementDebug,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!kMeasurementDebugEnabled) return const SizedBox.shrink();

    final body = _DebugBody(
      frontCalibration: frontCalibration,
      sideCalibration: sideCalibration,
      qualityReport: qualityReport,
      measurementDebug: measurementDebug,
    );

    if (compact) {
      return Container(
        constraints: const BoxConstraints(maxHeight: 220),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade900.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
        ),
        child: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.greenAccent,
              height: 1.5,
            ),
            child: body,
          ),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: compact,
        leading: const Icon(Icons.bug_report, size: 18, color: Colors.orange),
        title: const Text(
          'Developer Debug (debug mode only)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.greenAccent,
                height: 1.6,
              ),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugBody extends StatelessWidget {
  final CalibrationResult? frontCalibration;
  final CalibrationResult? sideCalibration;
  final QualityReport? qualityReport;
  final List<MeasurementDebugTrace>? measurementDebug;

  const _DebugBody({
    this.frontCalibration,
    this.sideCalibration,
    this.qualityReport,
    this.measurementDebug,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '── CALIBRATION ─────────────────────',
          style: TextStyle(color: Colors.white70),
        ),
        if (frontCalibration != null) ...[
          Text('Front method:     ${frontCalibration!.method}'),
          Text(
            'Front pixelToCm:  ${frontCalibration!.pixelToCm.toStringAsFixed(5)} cm/px',
          ),
          Text(
            'Front confidence: ${(frontCalibration!.confidence * 100).toStringAsFixed(1)}%',
          ),
          if (frontCalibration!.detectedLengthPx != null)
            Text(
              'Front body ht px: ${frontCalibration!.detectedLengthPx!.toStringAsFixed(1)} px',
            ),
        ] else
          const Text(
            'Front calibration: N/A',
            style: TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 4),
        if (sideCalibration != null) ...[
          Text('Side method:      ${sideCalibration!.method}'),
          Text(
            'Side pixelToCm:   ${sideCalibration!.pixelToCm.toStringAsFixed(5)} cm/px',
          ),
          Text(
            'Side confidence:  ${(sideCalibration!.confidence * 100).toStringAsFixed(1)}%',
          ),
          if (sideCalibration!.detectedLengthPx != null)
            Text(
              'Side body ht px:  ${sideCalibration!.detectedLengthPx!.toStringAsFixed(1)} px',
            ),
        ] else
          const Text(
            'Side calibration: N/A',
            style: TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 6),
        const Text(
          '── QUALITY ──────────────────────────',
          style: TextStyle(color: Colors.white70),
        ),
        if (qualityReport != null) ...[
          Text('Acceptable:       ${qualityReport!.isAcceptable}'),
          Text('Recommendation:   ${qualityReport!.recommendation.name}'),
          ...qualityReport!.issues.map(
            (i) => Text(
              '  [${i.severity.name.toUpperCase()}] ${i.message}',
              style: TextStyle(
                color: i.severity.name == 'reject'
                    ? Colors.redAccent
                    : Colors.yellowAccent,
              ),
            ),
          ),
        ] else
          const Text('Quality: N/A'),
        const SizedBox(height: 6),
        const Text(
          '── MEASUREMENT ENGINE ───────────────',
          style: TextStyle(color: Colors.white70),
        ),
        if (measurementDebug != null && measurementDebug!.isNotEmpty) ...[
          ...measurementDebug!.map(_formatTrace),
        ] else
          const Text('Measurement traces: N/A'),
        const SizedBox(height: 6),
        const Text(
          '── SANITY CHECK (adult ranges) ──────',
          style: TextStyle(color: Colors.white70),
        ),
        ..._sanityChecks(),
      ],
    );
  }

  /// Per-measurement anatomical sanity ranges for an adult (cm).
  static const Map<String, (double, double)> _sanityRanges = {
    'bahu': (35, 55),
    'dada': (75, 125),
    'pinggang': (60, 110),
    'pinggul': (75, 130),
    'panjang_lengan': (50, 75),
    'panjang_kaki': (70, 105),
  };

  List<Widget> _sanityChecks() {
    final traces = measurementDebug;
    if (traces == null || traces.isEmpty) {
      return const [Text('Sanity: N/A')];
    }
    final values = <String, double>{};
    for (final t in traces) {
      values[t.key] = t.finalCm;
    }

    final rows = <Widget>[];
    _sanityRanges.forEach((key, range) {
      final v = values[key];
      if (v == null) {
        rows.add(Text('  ${key.padRight(16)} —      (no data)',
            style: const TextStyle(color: Colors.white38)));
        return;
      }
      final pass = v >= range.$1 && v <= range.$2;
      rows.add(Text(
        '  ${key.padRight(16)} ${v.toStringAsFixed(1).padLeft(6)} cm  '
        '${pass ? 'PASS' : 'FAIL'} [${range.$1.toInt()}-${range.$2.toInt()}]',
        style: TextStyle(
          color: pass ? Colors.greenAccent : Colors.redAccent,
          fontWeight: pass ? FontWeight.normal : FontWeight.w700,
        ),
      ));
    });
    return rows;
  }

  Widget _formatTrace(MeasurementDebugTrace t) {
    final wPx = t.widthPx?.toStringAsFixed(1) ?? '-';
    final dPx = t.depthPx?.toStringAsFixed(1) ?? '-';
    final wCm = t.contourWidthCm?.toStringAsFixed(1) ?? '-';
    final dCm = t.contourDepthCm?.toStringAsFixed(1) ?? '-';
    final pCm = t.pixelToCm?.toStringAsFixed(5) ?? '-';
    final pSide = t.pixelToCmSide?.toStringAsFixed(5) ?? '-';
    final highlight = t.key == 'pinggul' || t.key == 'dada';
    return Text(
      '${t.key.padRight(18)} ${t.finalCm.toStringAsFixed(1)} cm '
      '(${(t.confidence * 100).toStringAsFixed(0)}%)\n'
      '  px: w=$wPx d=$dPx | cm: w=$wCm d=$dCm\n'
      '  scale: front=$pCm side=$pSide | ${t.method}',
      style: highlight
          ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
          : null,
    );
  }
}
