import 'package:cloud_firestore/cloud_firestore.dart';

import 'measurement.dart';

/// A reusable measurement profile (e.g., "Ayah", "Anak 1", "Baju Nikah")
class MeasurementProfile {
  final String profileId;
  final String profileName;
  final String sizeCategory;
  final List<Measurement> measurements;
  final ScanMetadata scanMetadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MeasurementProfile({
    required this.profileId,
    required this.profileName,
    required this.sizeCategory,
    required this.measurements,
    required this.scanMetadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory MeasurementProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse measurements
    final measurementsMap = data['measurements'] as Map<String, dynamic>? ?? {};
    final measurements = measurementsMap.entries
        .map((e) => Measurement.fromMap(e.key, e.value as Map<String, dynamic>))
        .toList();

    // Parse scan metadata
    final metaMap = data['scan_metadata'] as Map<String, dynamic>? ?? {};
    final scanMetadata = ScanMetadata.fromMap(metaMap);

    return MeasurementProfile(
      profileId: doc.id,
      profileName: data['profile_name'] as String? ?? 'Tanpa Nama',
      sizeCategory: data['size_category'] as String? ?? '-',
      measurements: measurements,
      scanMetadata: scanMetadata,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map for saving
  Map<String, dynamic> toFirestoreMap() {
    final measurementsMap = <String, dynamic>{};
    for (final m in measurements) {
      measurementsMap[m.key] = m.toMap();
    }

    return {
      'profile_name': profileName,
      'size_category': sizeCategory,
      'measurements': measurementsMap,
      'scan_metadata': scanMetadata.toMap(),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to Firestore map for updates (preserves created_at)
  Map<String, dynamic> toUpdateMap() {
    final measurementsMap = <String, dynamic>{};
    for (final m in measurements) {
      measurementsMap[m.key] = m.toMap();
    }

    return {
      'profile_name': profileName,
      'size_category': sizeCategory,
      'measurements': measurementsMap,
      'scan_metadata': scanMetadata.toMap(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  /// Get a specific measurement by key
  Measurement? getMeasurement(String key) {
    try {
      return measurements.firstWhere((m) => m.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Get chest measurement in cm (for size detection)
  double? get chestCm => getMeasurement('dada')?.valueCm;

  /// Get waist measurement in cm (for size detection)
  double? get waistCm => getMeasurement('pinggang')?.valueCm;

  /// Get shoulder measurement in cm (for size detection)
  double? get shoulderCm => getMeasurement('bahu')?.valueCm;

  /// Summary text for list display
  String get summaryText {
    final parts = <String>[];
    final chest = getMeasurement('dada');
    final waist = getMeasurement('pinggang');
    if (chest != null) parts.add('Dada: ${chest.valueCm} cm');
    if (waist != null) parts.add('Pinggang: ${waist.valueCm} cm');
    return parts.join(' • ');
  }
}

/// Metadata about the scan that produced this profile
class ScanMetadata {
  final double confidenceScore;
  final String scanVersion;
  final DateTime scannedAt;

  const ScanMetadata({
    required this.confidenceScore,
    required this.scanVersion,
    required this.scannedAt,
  });

  factory ScanMetadata.fromMap(Map<String, dynamic> map) {
    return ScanMetadata(
      confidenceScore: (map['confidence_score'] as num?)?.toDouble() ?? 0.0,
      scanVersion: map['scan_version'] as String? ?? '1.0.0',
      scannedAt: map['scanned_at'] is Timestamp
          ? (map['scanned_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'confidence_score': confidenceScore,
      'scan_version': scanVersion,
      'scanned_at': scannedAt,
    };
  }

  String get confidenceLabel {
    if (confidenceScore >= 0.8) return 'Tinggi';
    if (confidenceScore >= 0.6) return 'Sedang';
    return 'Rendah';
  }
}
