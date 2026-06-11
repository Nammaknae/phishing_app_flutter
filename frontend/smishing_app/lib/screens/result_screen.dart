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

  String _replaceEnglishGrades(String text) {
    return text
        .replaceAll(RegExp(r'suspicious', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'suspious', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'warning', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'caution', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'safe', caseSensitive: false), '안전')
        .replaceAll(RegExp(r'success', caseSensitive: false), '안전')
        .replaceAll(RegExp(r'danger', caseSensitive: false), '위험')
        .replaceAll(RegExp(r'risk', caseSensitive: false), '위험')
        .replaceAll(RegExp(r'malicious', caseSensitive: false), '위험');
  }

  String get _gradeText {
    final grade = (finalRiskGrade ?? label).trim().toUpperCase();

    switch (grade) {
      case 'SAFE':
      case 'SUCCESS':
        return '안전';

      case 'SUSPICIOUS':
      case 'SUSPIOUS':
      case 'WARNING':
      case 'CAUTION':
        return '주의';

      case 'DANGER':
      case 'RISK':
      case 'MALICIOUS':
        return '위험';

      default:
        return _replaceEnglishGrades(grade);
    }
  }

  String _toKoreanGrade(String? value) {
    if (value == null || value.trim().isEmpty) return '-';

    final grade = value.trim().toUpperCase();

    switch (grade) {
      case 'SAFE':
      case 'SUCCESS':
        return '안전';

      case 'SUSPICIOUS':
      case 'SUSPIOUS':
      case 'WARNING':
      case 'CAUTION':
        return '주의';

      case 'DANGER':
      case 'RISK':
      case 'MALICIOUS':
        return '위험';

      default:
        return _replaceEnglishGrades(value);
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
    final hasUrl = detectedUrl.trim().isNotEmpty && detectedUrl.trim() != '-';

    final reasonText = reason.trim().isNotEmpty
        ? _replaceEnglishGrades(reason.trim())
        : '구체적인 판단 이유가 제공되지 않았습니다.';

    final actionText = action.trim().isNotEmpty
        ? _replaceEnglishGrades(action.trim())
        : '메시지의 출처를 다시 확인하고, 의심되는 링크나 첨부파일은 열지 않는 것이 좋습니다.';

    switch (_gradeText) {
      case '위험':
        return '위험도가 높은 메시지로 판단되었어요.\n\n'
            '이 메시지는 스미싱 또는 악성 메시지에서 자주 나타나는 특징이 포함되어 있을 가능성이 큽니다. '
            '${hasUrl ? '특히 링크가 포함되어 있으므로 절대 바로 누르지 마세요. ' : ''}'
            '개인정보, 인증번호, 계좌정보, 카드번호, 비밀번호 입력을 요구한다면 매우 위험할 수 있어요.\n\n'
            '판단 이유: $reasonText\n\n'
            '권장 행동: $actionText';

      case '주의':
        return '주의가 필요한 메시지로 판단되었어요.\n\n'
            '현재 메시지에서 의심스러운 표현이나 확인이 필요한 요소가 발견되었습니다. '
            '${hasUrl ? '링크가 포함되어 있다면 공식 앱이나 공식 홈페이지를 직접 검색해서 접속하는 것이 안전해요. ' : ''}'
            '택배, 결제, 과태료, 본인인증, 계정 정지처럼 급하게 행동하도록 유도하는 문구가 있다면 더 조심해야 합니다.\n\n'
            '판단 이유: $reasonText\n\n'
            '권장 행동: $actionText';

      case '안전':
        return '현재 검사 결과 큰 위험 요소는 발견되지 않았어요.\n\n'
            '다만 안전으로 표시되더라도 모든 메시지가 100% 안전하다고 단정할 수는 없습니다. '
            '${hasUrl ? '링크를 열기 전에는 주소가 공식 사이트와 일치하는지 한 번 더 확인해 주세요. ' : ''}'
            '개인정보나 결제정보를 입력해야 하는 경우에는 반드시 공식 경로인지 확인하는 것이 좋아요.\n\n'
            '판단 이유: $reasonText\n\n'
            '권장 행동: $actionText';

      default:
        return '검사 결과를 확인했어요.\n\n'
            '메시지의 문구, 포함된 링크, 위험 점수 등을 바탕으로 판단했습니다.\n\n'
            '판단 이유: $reasonText\n\n'
            '권장 행동: $actionText';
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
    final koreanGuideText =
        guideText == null ? null : _replaceEnglishGrades(guideText);

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
                    _InfoRow(
                      '분류',
                      kcelectraIntent == null
                          ? '-'
                          : _replaceEnglishGrades(kcelectraIntent!),
                    ),
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
                    _InfoRow(
                      '의도',
                      kcelectraIntent == null
                          ? '-'
                          : _replaceEnglishGrades(kcelectraIntent!),
                    ),
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
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatBotScreen(
                          initialMessage: '검사 URL: $detectedUrl\n'
                              '최종 등급: $_gradeText\n'
                              '최종 점수: ${finalRiskScore ?? riskPercent.toInt()}\n'
                              '판단 이유: ${_replaceEnglishGrades(reason)}\n'
                              '${koreanGuideText != null && koreanGuideText.isNotEmpty ? '상세 경고문: $koreanGuideText' : ''}',
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'AI 상담사에게 물어보기',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
                  '궁금한 점이 있다면 AI 상담사에게 물어보세요.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (koreanGuideText != null && koreanGuideText.isNotEmpty)
                _HiddenDetail(
                  title: '상세 설명',
                  content: koreanGuideText,
                ),
              _HiddenDetail(
                title: '고급 탐지 정보',
                content: 'Safe Browsing: ${_formatSafeBrowsing()}\n'
                    'XGBoost 사용 여부: ${_formatBool(xgboostUsed)}\n'
                    'XGBoost 점수: ${_formatDouble(xgboostScore)}\n'
                    'XGBoost 판정: ${_toKoreanGrade(xgboostVerdict)}\n'
                    'KcELECTRA 사용 여부: ${_formatBool(kcelectraUsed)}\n'
                    'KcELECTRA 점수: ${_formatDouble(kcelectraScore)}\n'
                    'KcELECTRA 의도: ${kcelectraIntent == null ? '-' : _replaceEnglishGrades(kcelectraIntent!)}\n'
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

  String _replaceEnglishGrades(String text) {
    return text
        .replaceAll(RegExp(r'suspicious', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'suspious', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'warning', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'caution', caseSensitive: false), '주의')
        .replaceAll(RegExp(r'safe', caseSensitive: false), '안전')
        .replaceAll(RegExp(r'success', caseSensitive: false), '안전')
        .replaceAll(RegExp(r'danger', caseSensitive: false), '위험')
        .replaceAll(RegExp(r'risk', caseSensitive: false), '위험')
        .replaceAll(RegExp(r'malicious', caseSensitive: false), '위험');
  }

  @override
  Widget build(BuildContext context) {
    final koreanContent = _replaceEnglishGrades(content);

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
            koreanContent,
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
