/// 알림 스캔 응답 모델 — 위험 등급: SAFE | CAUTION | WARNING
class AlertScanResult {
  final String id;
  final String riskLevel;
  final DateTime? createdAt;

  const AlertScanResult({
    required this.id,
    required this.riskLevel,
    this.createdAt,
  });

  factory AlertScanResult.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt'] ?? json['created_at'];
    DateTime? createdAt;
    if (rawCreated is String && rawCreated.isNotEmpty) {
      createdAt = DateTime.tryParse(rawCreated);
    }

    return AlertScanResult(
      id: json['id']?.toString() ?? '',
      riskLevel: (json['riskLevel'] ?? json['risk_level'] ?? 'SAFE')
          .toString()
          .toUpperCase(),
      createdAt: createdAt,
    );
  }

  bool get shouldNotify {
    final level = riskLevel.toUpperCase();
    return level == 'WARNING' || level == 'CAUTION';
  }

  bool get isWarning => riskLevel.toUpperCase() == 'WARNING';

  bool get isCaution => riskLevel.toUpperCase() == 'CAUTION';
}
