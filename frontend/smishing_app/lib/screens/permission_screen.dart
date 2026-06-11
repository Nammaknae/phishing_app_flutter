import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app_state.dart';
import 'home_screen.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> with WidgetsBindingObserver {
  bool _agreedPrivacy = false;
  bool _agreedNotification = false;

  bool get _canProceed => _agreedPrivacy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정창에서 돌아왔을 때 권한 상태 재확인
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckNotificationPermission();
    }
  }

  Future<void> _recheckNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      setState(() => _agreedNotification = true);
    }
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
    final status = await Permission.notification.status;

    if (status.isGranted) {
      setState(() => _agreedNotification = true);
      return;
    }

    if (status.isDenied) {
      final result = await Permission.notification.request();
      if (result.isGranted) {
        setState(() => _agreedNotification = true);
        return;
      }
    }

    // 영구 거부이거나 요청 후에도 거부된 경우 → 안내 다이얼로그
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한 필요'),
        content: const Text(
          '알림이 차단되어 있습니다.\n설정에서 알림을 허용한 후\n다시 시도해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  void _proceed() {
    appState.agreePermission();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _exitApp() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '권한 설정',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF212121)),
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
                    Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 24),
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
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _agreedPrivacy
                        ? const Color(0xFF1976D2)
                        : const Color(0xFFEAEAEA),
                    width: _agreedPrivacy ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CheckboxListTile(
                    value: _agreedPrivacy,
                    onChanged: (val) =>
                        setState(() => _agreedPrivacy = val ?? false),
                    activeColor: const Color(0xFF1976D2),
                    title: const Text(
                      '개인정보 수집 및 이용 동의 (필수)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    subtitle: GestureDetector(
                      onTap: _showPrivacyDialog,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '내용 보기 >',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1976D2),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _agreedNotification
                        ? const Color(0xFF1976D2)
                        : const Color(0xFFEAEAEA),
                    width: _agreedNotification ? 2 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: CheckboxListTile(
                    value: _agreedNotification,
                    onChanged: (val) async {
                      if (val == true) {
                        await _handleNotificationPermission();
                      } else {
                        setState(() => _agreedNotification = false);
                      }
                    },
                    activeColor: const Color(0xFF1976D2),
                    title: const Text(
                      '알림 접근 허용 (필수)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '위험 탐지 시 알림을 받기 위해 필요합니다.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
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
                  child: const Text('동의 안 함', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}