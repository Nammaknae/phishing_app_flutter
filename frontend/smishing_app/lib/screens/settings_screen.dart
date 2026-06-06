import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/setting_header.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onBackHome;

  const SettingsScreen({super.key, this.onBackHome});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  VoidCallback? _listener;

  @override
  void initState() {
    super.initState();

    _listener = () {
      if (mounted) setState(() {});
    };

    appState.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) {
      appState.removeListener(_listener!);
    }
    super.dispose();
  }

  String _getFontSizeLabel(double size) {
    if (size <= 0.8) return '작게';
    if (size <= 1.0) return '보통';
    if (size <= 1.2) return '크게';
    return '매우 크게';
  }

  void _handleBack(BuildContext context) {
    if (widget.onBackHome != null) {
      widget.onBackHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildGuestBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person_outline,
                    size: 34,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '비회원',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '비회원으로 이용 중입니다',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.login, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '로그인하기',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 34,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.userEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          '간편로그인 연동',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('개인정보 처리방침'),
          content: const SingleChildScrollView(
            child: Text(
              '''
스미싱 탐지기는 사용자의 개인정보를 중요하게 생각합니다.

1. 수집하는 정보

본 앱은 회원가입 및 간편로그인 기능 제공을 위해 아래 정보를 수집할 수 있습니다.

- 이메일 주소
- 로그인 정보
- 사용자 식별 정보
- 사용자가 직접 입력한 문자 내용 또는 URL
- 스미싱 탐지 결과
- 앱 설정 정보
- 알림 설정 정보

2. 개인정보 이용 목적

수집된 정보는 아래 목적을 위해 사용됩니다.

- 회원 식별 및 로그인 기능 제공
- 간편로그인 서비스 제공
- 스미싱 탐지 서비스 제공
- 위험, 주의, 안전 결과 제공
- 앱 기능 개선 및 사용자 편의 제공

3. 개인정보 보관 및 파기

회원가입 및 로그인 정보는 계정 관리 및 서비스 제공을 위해 데이터베이스(DB)에 저장될 수 있습니다.

사용자가 입력한 문자 내용 및 URL은 스미싱 탐지 기능 제공을 위해 일시적으로만 사용되며, 탐지 완료 후 즉시 파기됩니다.

또한 2026년 6월 18일부터 즉시 파기 정책을 적용합니다.

4. 개인정보 제3자 제공

본 앱은 사용자의 개인정보를 외부 업체나 제3자에게 제공하지 않습니다.

5. 개인정보 보호

본 앱은 사용자의 개인정보 보호를 중요하게 생각하며, 개인정보 유출 방지를 위해 노력하고 있습니다.

6. 프로젝트 안내

본 앱은 대학교 산학 프로젝트를 목적으로 개발된 스미싱 탐지 애플리케이션입니다.

사용자 보호 및 안전한 서비스 제공을 위해 개인정보 보호 정책을 준수합니다.
              ''',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => _handleBack(context),
        ),
        centerTitle: true,
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          appState.isLoggedIn
              ? _buildProfileBanner(context)
              : _buildGuestBanner(context),
          const SettingHeader(title: '화면'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEAEAEA)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: const Text('다크모드', style: TextStyle(fontSize: 18)),
                  subtitle: const Text('어두운 화면으로 전환합니다'),
                  value: appState.isDarkMode,
                  onChanged: (val) => appState.toggleDarkMode(),
                  secondary: const Icon(Icons.dark_mode_outlined, size: 28),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const Icon(Icons.text_fields, size: 28),
                  title: const Text('글씨 크기', style: TextStyle(fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        _getFontSizeLabel(appState.fontSize),
                        style: const TextStyle(fontSize: 14),
                      ),
                      Slider(
                        value: appState.fontSize,
                        min: 0.8,
                        max: 1.4,
                        divisions: 3,
                        onChanged: (val) => appState.setFontSize(val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SettingHeader(title: '알림'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEAEAEA)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: const Text(
                    '스미싱 경고 알림',
                    style: TextStyle(fontSize: 18),
                  ),
                  subtitle: const Text('위험 탐지 시 알림을 받습니다'),
                  value: appState.smishingAlert,
                  onChanged: (val) => appState.toggleSmishingAlert(),
                  secondary: const Icon(Icons.notifications_outlined, size: 28),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: const Text('주의 알림', style: TextStyle(fontSize: 18)),
                  subtitle: const Text('주의 탐지 시 알림을 받습니다'),
                  value: appState.cautionAlert,
                  onChanged: (val) => appState.toggleCautionAlert(),
                  secondary: const Icon(Icons.warning_amber_outlined, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SettingHeader(title: '앱 정보'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFEAEAEA)),
            ),
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Icon(Icons.info_outline, size: 28),
                  title: Text('버전', style: TextStyle(fontSize: 18)),
                  trailing: Text('1.0.0', style: TextStyle(fontSize: 16)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: const Icon(Icons.privacy_tip_outlined, size: 28),
                  title: const Text(
                    '개인정보 처리방침',
                    style: TextStyle(fontSize: 18),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPrivacyDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (appState.isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text(
                    '로그아웃',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () async {
                    await appState.logout();

                    if (!context.mounted) return;

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
