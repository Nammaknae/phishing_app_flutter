import 'package:flutter/material.dart';

import 'chatbot_screen.dart';

class ResultScreen extends StatelessWidget {
  final String inputText;
  final String sourceApp;
  final String messageText;
  final String detectedUrl;

  final String label;
  final double score;
  final String reason;
  final String action;

  final String? llmResponseGuide;

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

  const ResultScreen({
    super.key,
    required this.inputText,
    required this.sourceApp,
    required this.messageText,
    required this.detectedUrl,
    required this.label,
    required this.score,
    required this.reason,
    required this.action,
    this.llmResponseGuide,
    this.finalRiskGrade,
    this.finalRiskScore,
    this.safeBrowsing = const <Map<String, dynamic>>[],
    this.xgboostUsed,
    this.xgboostScore,
    this.xgboostVerdict,
    this.kcelectraUsed,
    this.kcelectraScore,
    this.kcelectraIntent,
    this.kcelectraVerdict,
    this.analyzedAt,
    this.errorMessage,
  });

  String get _gradeText {
    final grade = (finalRiskGrade ?? label).toUpperCase();

    switch (grade) {
      case 'SAFE':
      case 'SUCCESS':
        return '안전';

      case 'SUSPICIOUS':
      case 'WARNING':
      case 'CAUTION':
        return '주의';

      case 'DANGER':
      case 'RISK':
      case 'MALICIOUS':
        return '위험';

      default:
        return '주의';
    }
  }

  String _toKoreanGrade(String? value) {
    if (value == null || value.trim().isEmpty) return '-';

    switch (value.toUpperCase()) {
      case 'SAFE':
      case 'SUCCESS':
        return '안전';

      case 'SUSPICIOUS':
      case 'WARNING':
      case 'CAUTION':
        return '주의';

      case 'DANGER':
      case 'RISK':
      case 'MALICIOUS':
        return '위험';

      default:
        return value;
    }
  }

  Color get _gradeColor {
    switch (_gradeText) {
      case '위험':
        return const Color(0xFFE53935);
      case '주의':
        return const Color(0xFFFF7A00);
      case '안전':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF1976D2);
    }
  }

  IconData get _gradeIcon {
    switch (_gradeText) {
      case '위험':
        return Icons.dangerous_outlined;
      case '주의':
        return Icons.warning_amber_rounded;
      case '안전':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  String get _shortSummary {
    switch (_gradeText) {
      case '위험':
        return '위험한 패턴이 발견되었어요.\n링크를 누르거나 개인정보를 입력하지 마세요.';
      case '주의':
        return '의심스러운 요소가 발견되었어요.\n공식 사이트나 신뢰 가능한 출처에서 한 번 더 확인해 주세요.';
      case '안전':
        return '현재 검사 결과 위험 요소가 발견되지 않았어요.\n그래도 개인정보 입력 전에는 항상 확인하세요.';
      default:
        return '검사 결과를 확인했어요.\n필요하면 AI 상담사에게 자세히 물어보세요.';
    }
  }

  String _formatSafeBrowsing() {
    if (safeBrowsing.isEmpty) return '-';
    return safeBrowsing.map((item) {
      final url = item['url']?.toString() ?? '-';
      final isMalicious = item['isMalicious'] == true;
      return '${isMalicious ? '위험' : '안전'} ($url)';
    }).join('\n');
  }

  String _formatBool(bool? value) {
    if (value == null) return '-';
    return value ? '사용됨' : '사용 안 됨';
  }

  String _formatDouble(double? value, {int fraction = 6}) {
    if (value == null) return '-';
    return value.toStringAsFixed(fraction);
  }

  @override
  Widget build(BuildContext context) {
    final riskPercent = finalRiskScore?.toDouble() ?? score;
    final guideText = llmResponseGuide?.trim();

    const bgColor = Color(0xFFF7FBFF);
    const mainBlue = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '검사 결과',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                _gradeIcon,
                size: 82,
                color: _gradeColor,
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  _gradeText,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: _gradeColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '위험도 ${riskPercent.toInt()}%',
                  style: TextStyle(
                    fontSize: 20,
                    color: _gradeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _SimpleCard(
                title: '판단 요약',
                icon: Icons.info_outline,
                child: Text(
                  _shortSummary,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.65,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _SimpleCard(
                title: '기본 정보',
                icon: Icons.description_outlined,
                child: Column(
                  children: [
                    _InfoRow(
                      '입력 방식',
                      sourceApp.isEmpty ? '직접 입력' : sourceApp,
                    ),
                    _InfoRow('분류', kcelectraIntent ?? '-'),
                    _InfoRow('판정', _gradeText, valueColor: _gradeColor),
                    _InfoRow(
                      '최종 점수',
                      finalRiskScore?.toString() ??
                          riskPercent.toInt().toString(),
                    ),
                    _InfoRow('분석 시간', analyzedAt ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _SimpleCard(
                title: '탐지 정보',
                icon: Icons.shield_outlined,
                child: Column(
                  children: [
                    _InfoRow(
                      '탐지 엔진',
                      kcelectraUsed == true ? 'KcELECTRA' : '-',
                    ),
                    _InfoRow('점수', _formatDouble(kcelectraScore)),
                    _InfoRow('의도', kcelectraIntent ?? '-'),
                    _InfoRow(
                      '판정',
                      _toKoreanGrade(kcelectraVerdict ?? _gradeText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatBotScreen(
                          initialMessage: '검사 URL: $detectedUrl\n'
                              '최종 등급: $_gradeText\n'
                              '최종 점수: ${finalRiskScore ?? riskPercent.toInt()}\n'
                              '판단 이유: $reason\n'
                              '${guideText != null && guideText.isNotEmpty ? '상세 경고문: $guideText' : ''}',
                          onBackHome: () => Navigator.pop(context),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text(
                    'AI 상담사에게 물어보기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: mainBlue,
                    side: const BorderSide(color: mainBlue, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '다시 검사하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '💡 궁금한 점이 있다면 AI 상담사에게 물어보세요.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (guideText != null && guideText.isNotEmpty)
                _HiddenDetail(
                  title: '상세 설명',
                  content: guideText,
                ),
              _HiddenDetail(
                title: '고급 탐지 정보',
                content: 'Safe Browsing: ${_formatSafeBrowsing()}\n'
                    'XGBoost 사용 여부: ${_formatBool(xgboostUsed)}\n'
                    'XGBoost 점수: ${_formatDouble(xgboostScore)}\n'
                    'XGBoost 판정: ${_toKoreanGrade(xgboostVerdict)}\n'
                    'KcELECTRA 사용 여부: ${_formatBool(kcelectraUsed)}\n'
                    'KcELECTRA 점수: ${_formatDouble(kcelectraScore)}\n'
                    'KcELECTRA 의도: ${kcelectraIntent ?? '-'}\n'
                    'KcELECTRA 판정: ${_toKoreanGrade(kcelectraVerdict)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SimpleCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    const mainBlue = Color(0xFF1976D2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 23, color: mainBlue),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow(
    this.label,
    this.value, {
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: valueColor ?? Colors.black87,
                fontWeight:
                    valueColor == null ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenDetail extends StatelessWidget {
  final String title;
  final String content;

  const _HiddenDetail({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          color: Colors.black45,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}