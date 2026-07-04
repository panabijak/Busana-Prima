import '../../models/measurement_confidence.dart';
import '../../models/processed_landmarks.dart';
import '../measurement/ellipse_circumference.dart';
import 'symmetry_checker.dart';

/// Severity levels for quality issues.
enum Severity { info, warning, reject }

/// Types of quality issues detected.
enum QualityIssueType {
  asymmetry,
  lowVisibility,
  outOfRange,
  inconsistentRatio,
  insufficientData,
}

/// Recommendation after quality analysis.
enum QualityRecommendation { accept, acceptWithWarnings, rescan }

/// A single quality issue found during validation.
class QualityIssue {
  final QualityIssueType type;
  final String message;
  final Severity severity;
  final String? measurementKey;

  const QualityIssue({
    required this.type,
    required this.message,
    required this.severity,
    this.measurementKey,
  });
}

/// Complete quality report for a scan.
class QualityReport {
  final bool isAcceptable;
  final List<QualityIssue> issues;
  final QualityRecommendation recommendation;

  const QualityReport({
    required this.isAcceptable,
    required this.issues,
    required this.recommendation,
  });

  /// Issues that should be shown to the user.
  List<QualityIssue> get userVisibleIssues =>
      issues.where((i) => i.severity != Severity.info).toList();

  /// Issues that require a rescan.
  List<QualityIssue> get criticalIssues =>
      issues.where((i) => i.severity == Severity.reject).toList();
}

/// Orchestrates all quality checks on scan results.
///
/// ARCHITECTURE — two clearly separated concerns:
///
/// A. CAPTURE / DATA QUALITY (may REJECT the scan → rescan):
///    - Extreme pose asymmetry (tilted/rotated body)
///    - Landmark visibility/confidence (body not visible / poor lighting)
///    - Insufficient measurements computed (body not fully in frame)
///
/// B. MEASUREMENT PLAUSIBILITY (NEVER rejects — only WARNS + lowers
///    confidence): physiological range, anthropometric/proportional/tailoring
///    ratios. An estimated dimension that looks off must be surfaced as LOW
///    CONFIDENCE, not used to block a capture the user already completed.
///
/// This separation is deliberate: measurement values are downstream estimates
/// and must not gate the capture pipeline. Only genuine capture failures do.
class QualityController {
  final SymmetryChecker _symmetry = SymmetryChecker();

  /// Run all quality checks.
  QualityReport validate({
    required List<MeasurementWithConfidence> measurements,
    required ProcessedLandmarks landmarks,
    double? userHeightCm,
  }) {
    final issues = <QualityIssue>[];

    // ══ A. CAPTURE / DATA QUALITY (can reject) ══════════════════════════

    // A1. Pose asymmetry.
    // WARNING at ≥ 10% asymmetry (SymmetryChecker.maxAsymmetry = 0.10).
    // REJECT only at extreme (≥ 40%) tilt/rotation where landmarks are no
    // longer usable. Still-image JPEG detection has ~10–15% natural variance
    // vs live-stream YUV frames, so moderate asymmetry is a warning only.
    final symmetryResult = _symmetry.check(landmarks);
    if (!symmetryResult.isSymmetric) {
      issues.add(
        QualityIssue(
          type: QualityIssueType.asymmetry,
          message: symmetryResult.details ?? 'Posisi tubuh tidak simetris',
          severity: symmetryResult.deviation > 0.40
              ? Severity.reject
              : Severity.warning,
        ),
      );
    }

    // A2. Body visibility / landmark confidence.
    final lowConfLandmarks = landmarks.allLandmarks
        .where((lm) => lm.confidence < 0.5)
        .length;
    if (lowConfLandmarks > 5) {
      issues.add(
        QualityIssue(
          type: QualityIssueType.lowVisibility,
          message:
              '$lowConfLandmarks titik tubuh memiliki deteksi rendah. '
              'Pastikan pencahayaan cukup dan seluruh tubuh terlihat.',
          severity: Severity.reject,
        ),
      );
    } else if (lowConfLandmarks > 2) {
      issues.add(
        QualityIssue(
          type: QualityIssueType.lowVisibility,
          message: '$lowConfLandmarks titik tubuh memiliki kepercayaan rendah.',
          severity: Severity.warning,
        ),
      );
    }

    // A3. Minimum measurement count (body not fully in frame).
    if (measurements.length < 5) {
      issues.add(
        const QualityIssue(
          type: QualityIssueType.insufficientData,
          message: 'Terlalu sedikit pengukuran berhasil dihitung. '
              'Pastikan seluruh tubuh terlihat jelas.',
          severity: Severity.reject,
        ),
      );
    }

    // ══ B. MEASUREMENT PLAUSIBILITY (warnings only — never reject) ═══════

    // B1. Physiological range → flag as low confidence, do NOT block.
    for (final m in measurements) {
      if (!m.isWithinRange) {
        issues.add(
          QualityIssue(
            type: QualityIssueType.outOfRange,
            message: '${m.label}: nilai di luar rentang normal',
            severity: Severity.warning,
            measurementKey: m.key,
          ),
        );
      }
    }

    // B2. Anthropometric / proportional / tailoring ratios (warnings only).
    issues.addAll(_checkRatios(measurements, userHeightCm: userHeightCm));

    // Verdict: ONLY capture/data-quality rejects block the scan.
    final hasReject = issues.any((i) => i.severity == Severity.reject);
    final hasWarnings = issues.any((i) => i.severity == Severity.warning);

    return QualityReport(
      isAcceptable: !hasReject,
      issues: issues,
      recommendation: hasReject
          ? QualityRecommendation.rescan
          : hasWarnings
          ? QualityRecommendation.acceptWithWarnings
          : QualityRecommendation.accept,
    );
  }

  /// Check relationships between measurements for internal consistency.
  ///
  /// IMPORTANT: every issue here is a `Severity.warning` (never `reject`).
  /// These are proportional/anthropometric/tailoring sanity checks on
  /// *estimated* values — they lower measurement confidence but must not
  /// block a completed capture. Each issue carries a `measurementKey` so the
  /// ConfidenceScorer can mark the specific measurement(s) as LOW CONFIDENCE.
  List<QualityIssue> _checkRatios(
    List<MeasurementWithConfidence> measurements, {
    double? userHeightCm,
  }) {
    final issues = <QualityIssue>[];

    void warn(String key, String message) {
      issues.add(
        QualityIssue(
          type: QualityIssueType.inconsistentRatio,
          message: message,
          severity: Severity.warning,
          measurementKey: key,
        ),
      );
    }

    final chest = _find(measurements, 'dada');
    final waist = _find(measurements, 'pinggang');
    final hip = _find(measurements, 'pinggul');
    final shoulder = _find(measurements, 'bahu');
    final arm = _find(measurements, 'panjang_lengan');
    final leg = _find(measurements, 'panjang_kaki');
    final torso = _find(measurements, 'tinggi_torso');
    final back = _find(measurements, 'panjang_punggung');
    final chestWidth = _find(measurements, 'lebar_dada');
    final waistWidth = _find(measurements, 'lebar_pinggang');
    final hipWidth = _find(measurements, 'lebar_pinggul');

    // ── TASK 4: Anatomical consistency layer (warnings only) ──────────
    // Violations lower confidence and are labelled "anatomical inconsistency";
    // they never reject the scan.

    // Waist should generally be ≤ chest (allow 15% tolerance for body types)
    if (chest != null && waist != null && waist > chest * 1.15) {
      warn('pinggang',
          'Ketaksesuaian anatomi: pinggang lebih besar dari dada');
    }

    // Hip should be ≥ waist (allow some tolerance)
    if (hip != null && waist != null && waist > hip * 1.10) {
      warn('pinggul', 'Ketaksesuaian anatomi: rasio pinggang-pinggul tidak wajar');
    }

    // Shoulder (linear) should be ≥ waist width (torso tapers inward at waist).
    if (shoulder != null && waistWidth != null && shoulder < waistWidth * 0.95) {
      warn('lebar_pinggang',
          'Ketaksesuaian anatomi: lebar pinggang melebihi bahu');
    }

    // Hip width should be ≥ waist width (hips are the widest lower landmark).
    if (hipWidth != null && waistWidth != null && hipWidth < waistWidth * 0.95) {
      warn('lebar_pinggul',
          'Ketaksesuaian anatomi: lebar pinggul lebih kecil dari pinggang');
    }

    // Chest circumference / shoulder linear width is the principled shoulder
    // consistency check. Empirical range (ISO 8559, CAESAR): ~2.0–2.7; allow
    // 1.9–2.9 for rarer builds. (The old `shoulder > chest/π × 1.2` heuristic
    // was removed — it false-flagged every normal ~40 cm adult shoulder.)
    if (shoulder != null && chest != null) {
      final chestToShoulder = chest / shoulder;
      if (chestToShoulder < 1.9 || chestToShoulder > 2.9) {
        warn('dada',
            'Rasio dada dan bahu tidak wajar — kemungkinan lengan termasuk dalam pengukuran');
      }
    }

    // Circumference vs linear width (tailoring consistency).
    void checkCircToWidth({
      required double? circumference,
      required double? linearWidth,
      required String key,
      required String label,
      required double minRatio,
      required double maxRatio,
    }) {
      if (circumference == null || linearWidth == null || linearWidth <= 0) {
        return;
      }
      if (!EllipseCircumference.isPlausibleCircumferenceRatio(
        circumferenceCm: circumference,
        linearWidthCm: linearWidth,
        minRatio: minRatio,
        maxRatio: maxRatio,
      )) {
        warn(key,
            '$label: lingkar tidak seimbang dengan lebar linear '
            '(kemungkinan kedalaman badan terlebih ukur)');
      }
    }

    checkCircToWidth(
      circumference: chest,
      linearWidth: chestWidth,
      key: 'dada',
      label: 'Dada',
      minRatio: 2.15,
      maxRatio: 3.12,
    );
    checkCircToWidth(
      circumference: waist,
      linearWidth: waistWidth,
      key: 'pinggang',
      label: 'Pinggang',
      minRatio: 2.10,
      maxRatio: 3.08,
    );
    checkCircToWidth(
      circumference: hip,
      linearWidth: hipWidth,
      key: 'pinggul',
      label: 'Pinggul',
      minRatio: 2.20,
      maxRatio: 3.18,
    );

    // Linear width vs shoulder (arm contamination detector).
    if (shoulder != null && hipWidth != null && hipWidth > shoulder * 1.32) {
      warn('lebar_pinggul',
          'Lebar pinggul melebihi bahu — kemungkinan lengan termasuk dalam kontur');
    }

    if (back != null && torso != null && back > torso * 0.92) {
      warn('panjang_punggung',
          'Panjang punggung tidak seimbang dengan tinggi torso');
    }

    if (hip != null && waist != null) {
      final waistToHip = waist / hip;
      if (waistToHip < 0.55 || waistToHip > 1.25) {
        warn('pinggul', 'Rasio pinggang dan pinggul tidak wajar');
      }
    }

    if (userHeightCm != null && userHeightCm >= 80 && userHeightCm <= 230) {
      void checkHeightRatio({
        required String key,
        required double? value,
        required double min,
        required double max,
        required String message,
      }) {
        if (value == null) return;
        final ratio = value / userHeightCm;
        if (ratio < min || ratio > max) {
          warn(key, message);
        }
      }

      checkHeightRatio(
        key: 'bahu',
        value: shoulder,
        min: 0.18,
        max: 0.32,
        message: 'Lebar bahu tidak seimbang dengan tinggi badan',
      );
      checkHeightRatio(
        key: 'dada',
        value: chest,
        min: 0.46,
        max: 0.78,
        message: 'Lingkar dada tidak seimbang dengan tinggi badan',
      );
      checkHeightRatio(
        key: 'panjang_lengan',
        value: arm,
        min: 0.25,
        max: 0.48,
        message: 'Panjang lengan tidak seimbang dengan tinggi badan',
      );
      checkHeightRatio(
        key: 'panjang_kaki',
        value: leg,
        min: 0.30,
        max: 0.63,
        message: 'Panjang kaki tidak seimbang dengan tinggi badan',
      );
      checkHeightRatio(
        key: 'tinggi_torso',
        value: torso,
        min: 0.18,
        max: 0.40,
        message: 'Tinggi torso tidak seimbang dengan tinggi badan',
      );
    }

    return issues;
  }

  double? _find(List<MeasurementWithConfidence> list, String key) {
    try {
      return list.firstWhere((m) => m.key == key).valueCm;
    } catch (_) {
      return null;
    }
  }
}
