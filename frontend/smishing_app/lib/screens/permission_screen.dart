import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';
import '../services/notification_access_service.dart';
import 'home_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  bool _agreedPrivacy = false;
  bool _agreedNotification = false;

  bool get _canProceed => _agreedPrivacy && _agreedNotification;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recheckNotificationPermission();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      _recheckNotificationPermission();
    }
  }

  Future<void> _recheckNotificationPermission() async {
    if (kIsWeb) return;

    final listenerEnabled =
        await NotificationAccessService.isNotificationListenerEnabled();

    if (!mounted) return;

    setState(() {
      _agreedNotification = listenerEnabled;
    });
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('개인정보 처리방침'),
        content: const SingleChildScrollView(
          child: Text(
            '''스미싱 탐지기는 사용자의 개인정보를 중요하게 생각합니다.

1. 수집하는 정보
- 이메일 주소, 로그인 정보
- 사용자가 입력한 문자 내용 또는 URL
- 스미싱 탐지 결과, 앱 설정 정보

2. 개인정보 이용 목적
- 회원 식별 및 로그인 기능 제공
- 스미싱 탐지 서비스 제공

3. 개인정보 보관 및 파기
사용자가 입력한 내용은 탐지 완료 후 즉시 파기됩니다.

4. 개인정보 제3자 제공
본 앱은 개인정보를 외부에 제공하지 않습니다.''',
            style: TextStyle(fontSize: 14, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNotificationPermission() async {
    if (kIsWeb) {
      setState(() {
        _agreedNotification = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('웹에서는 테스트용으로 알림 접근 허용 처리됩니다.'),
        ),
      );
      return;
    }

    final notificationStatus = await Permission.notification.status;

    if (!notificationStatus.isGranted) {
      await Permission.notification.request();
    }

    final listenerEnabled =
        await NotificationAccessService.isNotificationListenerEnabled();

    if (!mounted) return;

    if (listenerEnabled) {
      setState(() {
        _agreedNotification = true;
      });
      return;
    }

    await NotificationAccessService.openNotificationListenerSettings();
  }

  void _proceed() {
    appState.agreePermission();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _exitApp() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('웹에서는 앱 종료가 지원되지 않습니다. 브라우저 탭을 닫아주세요.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('앱 종료'),
        content: const Text('필수 권한에 동의하지 않으면\n앱을 사용할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('돌아가기'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('종료'),
          ),
        ],
      ),
    );
  }

  Widget _permissionCard({
    required bool checked,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onSubtitleTap,
    bool subtitleBlue = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        color: const Color(0xFFF7F7FC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: checked ? const Color(0xFF1976D2) : const Color(0xFFEAEAEA),
            width: checked ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                activeColor: const Color(0xFF1976D2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: onSubtitleTap,
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleBlue
                              ? const Color(0xFF1976D2)
                              : Colors.black54,
                          decoration: subtitleBlue
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationSubtitle =
        kIsWeb ? '웹 테스트에서는 클릭 시 허용 처리됩니다.' : '위험 탐지 시 알림을 받기 위해 필요합니다.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '권한 설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF1976D2),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '아래 항목에 모두 동의해야\n앱을 사용할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '필수 동의 항목',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _permissionCard(
                checked: _agreedPrivacy,
                title: '개인정보 수집 및 이용 동의 (필수)',
                subtitle: '내용 보기 >',
                subtitleBlue: true,
                onTap: () {
                  setState(() {
                    _agreedPrivacy = !_agreedPrivacy;
                  });
                },
                onSubtitleTap: _showPrivacyDialog,
              ),
              const SizedBox(height: 12),
              _permissionCard(
                checked: _agreedNotification,
                title: '알림 접근 허용 (필수)',
                subtitle: notificationSubtitle,
                onTap: () async {
                  if (_agreedNotification) {
                    setState(() {
                      _agreedNotification = false;
                    });
                  } else {
                    await _handleNotificationPermission();
                  }
                },
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed ? _proceed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '동의하고 시작하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _exitApp,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '동의 안 함',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
