import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/api_client.dart';
import '../services/auth_api_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'onboarding_screen.dart';
import '../widgets/social_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _pwController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _pwController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력해주세요');
      return;
    }

    if (!_isValidEmail(email)) {
      _showSnack('올바른 이메일 형식을 입력해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthApiService.login(
        email: email,
        password: password,
      );
      appState.setAuthenticatedSession(result.user);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('로그인 중 오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingScreen()),
            );
          },
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '스미싱 탐지기',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                '이메일',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'example@email.com',
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    size: 28,
                    color: Color(0xFF1976D2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1976D2),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '비밀번호',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pwController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '비밀번호를 입력하세요',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 28,
                    color: Color(0xFF1976D2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1976D2),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    '아직 계정이 없으신가요? 회원가입',
                    style: TextStyle(fontSize: 16, color: Color(0xFF1976D2)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '간편 로그인',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              SocialLoginButton(
                color: const Color(0xFFFEE500),
                textColor: const Color(0xFF191919),
                icon: Icons.chat_bubble,
                iconColor: const Color(0xFF191919),
                text: '카카오로 시작하기',
                onTap: () => _showSnack('간편 로그인은 다음 단계에서 연동됩니다'),
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                color: const Color(0xFF03C75A),
                textColor: Colors.white,
                icon: Icons.login,
                iconColor: Colors.white,
                text: '네이버로 시작하기',
                onTap: () => _showSnack('간편 로그인은 다음 단계에서 연동됩니다'),
              ),
              const SizedBox(height: 12),
              SocialLoginButton(
                color: Colors.white,
                textColor: const Color(0xFF191919),
                icon: Icons.g_mobiledata,
                iconColor: const Color(0xFF4285F4),
                text: '구글로 시작하기',
                onTap: () => _showSnack('간편 로그인은 다음 단계에서 연동됩니다'),
                hasBorder: true,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
