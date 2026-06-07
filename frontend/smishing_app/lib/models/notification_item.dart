import 'alert_scan_result.dart';

class NotificationItem {
  final String packageName;
  final String title;
  final String text;
  final List<String> urls;

  final String? resultId;
  final String? finalRiskGrade;
  final int? finalRiskScore;
  final List<Map<String, dynamic>> safeBrowsing;

  final bool? xgboostUsed;
  final double? xgboostScore;
  final String? xgboostVerdict;

  final bool? kcelectraUsed;
  final double? kcelectraScore;
  final String? kcelectraIntent;
  final String? kcelectraVerdict;

  final String? analyzedAt;
  final String? errorMessage;

  const NotificationItem({
    required this.packageName,
    required this.title,
    required this.text,
    required this.urls,
    required this.resultId,
    required this.finalRiskGrade,
    required this.finalRiskScore,
    required this.safeBrowsing,
    required this.xgboostUsed,
    required this.xgboostScore,
    required this.xgboostVerdict,
    required this.kcelectraUsed,
    required this.kcelectraScore,
    required this.kcelectraIntent,
    required this.kcelectraVerdict,
    required this.analyzedAt,
    required this.errorMessage,
  });

  factory NotificationItem.fromScanResponse({
    required String packageName,
    required String title,
    required String text,
    required List<String> urls,
    required Map<String, dynamic> response,
  }) {
    final List<Map<String, dynamic>> safeBrowsing =
        _parseSafeBrowsing(response['safe_browsing']);

    final Map<String, dynamic>? xgboostMap = _toMap(response['xgboost']);
    final List<Map<String, dynamic>> xgboostList = _toMapList(response['xgboost']);

    bool? xgboostUsed;
    double? xgboostScore;
    String? xgboostVerdict;

    if (xgboostMap != null) {
      xgboostUsed = _toBool(xgboostMap['used']);
      xgboostScore = _toDouble(xgboostMap['score']);
      xgboostVerdict = _toStringOrNull(xgboostMap['verdict']);
    } else if (xgboostList.isNotEmpty) {
      xgboostUsed = true;
      xgboostScore = xgboostList
          .map((Map<String, dynamic> item) => _toDouble(item['score']) ?? 0.0)
          .fold<double>(0.0, (double prev, double next) => next > prev ? next : prev);

      xgboostVerdict = _worstVerdict(
        xgboostList
            .map((Map<String, dynamic> item) => _toStringOrNull(item['verdict']))
            .whereType<String>()
            .toList(),
      );
    }

    final Map<String, dynamic>? kcelectraMap = _toMap(response['kcelectra']);

    return NotificationItem(
      packageName: packageName,
      title: title,
      text: text,
      urls: urls,
      resultId: _toStringOrNull(response['result_id']),
      finalRiskGrade: _toStringOrNull(response['final_risk_grade']),
      finalRiskScore: _toInt(response['final_risk_score']),
      safeBrowsing: safeBrowsing,
      xgboostUsed: xgboostUsed,
      xgboostScore: xgboostScore,
      xgboostVerdict: xgboostVerdict,
      kcelectraUsed: _toBool(kcelectraMap?['used']),
      kcelectraScore: _toDouble(kcelectraMap?['score']),
      kcelectraIntent: _toStringOrNull(kcelectraMap?['intent']),
      kcelectraVerdict: _toStringOrNull(kcelectraMap?['verdict']),
      analyzedAt: _toStringOrNull(response['analyzed_at']),
      errorMessage: null,
    );
  }

  /// 알림 스캔 응답(SAFE | CAUTION | WARNING)을 UI 목록 항목으로 변환합니다.
  factory NotificationItem.fromAlertScanResult({
    required String packageName,
    required String title,
    required String text,
    required List<String> urls,
    required AlertScanResult result,
  }) {
    final level = result.riskLevel.toUpperCase();
    final String displayGrade;
    switch (level) {
      case 'WARNING':
        displayGrade = 'DANGER';
        break;
      case 'CAUTION':
        displayGrade = 'SUSPICIOUS';
        break;
      default:
        displayGrade = 'SAFE';
    }

    return NotificationItem(
      packageName: packageName,
      title: title,
      text: text,
      urls: urls,
      resultId: result.id,
      finalRiskGrade: displayGrade,
      finalRiskScore: null,
      safeBrowsing: const <Map<String, dynamic>>[],
      xgboostUsed: null,
      xgboostScore: null,
      xgboostVerdict: null,
      kcelectraUsed: null,
      kcelectraScore: null,
      kcelectraIntent: null,
      kcelectraVerdict: null,
      analyzedAt: result.createdAt?.toIso8601String(),
      errorMessage: null,
    );
  }

  factory NotificationItem.withError({
    required String packageName,
    required String title,
    required String text,
    required List<String> urls,
    required String errorMessage,
  }) {
    return NotificationItem(
      packageName: packageName,
      title: title,
      text: text,
      urls: urls,
      resultId: null,
      finalRiskGrade: null,
      finalRiskScore: null,
      safeBrowsing: const <Map<String, dynamic>>[],
      xgboostUsed: null,
      xgboostScore: null,
      xgboostVerdict: null,
      kcelectraUsed: null,
      kcelectraScore: null,
      kcelectraIntent: null,
      kcelectraVerdict: null,
      analyzedAt: null,
      errorMessage: errorMessage,
    );
  }

  static List<Map<String, dynamic>> _parseSafeBrowsing(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return _toMapList(raw);
  }

  static Map<String, dynamic>? _toMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((dynamic k, dynamic v) => MapEntry(k.toString(), v));
  }

  static List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];

    return value
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              item.map((dynamic k, dynamic v) => MapEntry(k.toString(), v)),
        )
        .toList();
  }

  static String? _toStringOrNull(dynamic value) {
    if (value == null) return null;
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    return text;
  }

  static bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final String text = value.toString().toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();

    return int.tryParse(value.toString()) ??
        double.tryParse(value.toString())?.round();
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _worstVerdict(List<String> verdicts) {
    if (verdicts.isEmpty) return null;

    final List<String> normalized =
        verdicts.map((String value) => value.toLowerCase()).toList();

    if (normalized.contains('malicious')) return 'malicious';
    if (normalized.contains('suspicious')) return 'suspicious';
    if (normalized.contains('safe')) return 'safe';

    return verdicts.first;
  }
}
