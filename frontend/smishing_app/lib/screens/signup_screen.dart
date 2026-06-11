import 'package:flutter/material.dart';
import '../app_state.dart';
import '../services/api_client.dart';
import '../services/auth_api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _pwConfirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeTerms = false;
  bool _isLoading = false;

  void _showDialog(String title, String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: isSuccess
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFF44336),
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 18, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (isSuccess) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  Future<void> _handleSignup() async {
    final name = _nameController.text.trim();
    final email = _idController.text.trim();
    final password = _pwController.text;
    // 이름 입력 체크
    if (name.isEmpty) {
      _showDialog('입력 오류', '이름을 입력해주세요');
      return;
    }

    final nameRegex = RegExp(
      r'^[\uAC00-\uD7A3a-zA-Z\u3040-\u30FF\u4E00-\u9FFF ]+$',
    );
    if (!nameRegex.hasMatch(name)) {
      _showDialog(
        '이름 형식 오류',
        '이름에는 숫자나 특수문자를\n사용할 수 없습니다.\n한글, 영어, 다른 언어만 입력해주세요',
      );
      return;
    }

    if (email.isEmpty) {
      _showDialog('입력 오류', '이메일을 입력해주세요');
      return;
    }
    if (!_isValidEmail(email)) {
      _showDialog('입력 오류', '올바른 이메일 형식을 입력해주세요');
      return;
    }
    if (password.isEmpty) {
      _showDialog('입력 오류', '비밀번호를 입력해주세요');
      return;
    }
    if (password.length < 6) {
      _showDialog('입력 오류', '비밀번호는 6자 이상이어야 합니다');
      return;
    }
    if (password != _pwConfirmController.text) {
      _showDialog('비밀번호 오류', '비밀번호가 일치하지 않습니다.\n다시 확인해주세요');
      return;
    }
    if (!_agreeTerms) {
      _showDialog('약관 동의', '이용약관 및 개인정보 처리방침에\n동의해주세요');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthApiService.signup(
        name: name,
        email: email,
        password: password,
      );
      appState.setAuthenticatedSession(result.user, displayName: name);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      _showDialog('회원가입 실패', e.message);
    } catch (_) {
      _showDialog('회원가입 실패', '회원가입 중 오류가 발생했습니다');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // 이름
              const Text(
                '이름',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '이름을 입력하세요',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
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

              // 이메일 (백엔드 로그인 ID)
              const Text(
                '이메일',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _idController,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'example@email.com',
                  prefixIcon: const Icon(
                    Icons.person_outline,
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

              // 비밀번호
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

              const SizedBox(height: 16),

              // 비밀번호 확인
              const Text(
                '비밀번호 확인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pwConfirmController,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: '비밀번호를 다시 입력하세요',
                  prefixIcon: const Icon(
                    Icons.lock_outline,
                    size: 28,
                    color: Color(0xFF1976D2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
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

              const SizedBox(height: 20),

              // 이용약관 동의
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _agreeTerms,
                    onChanged: (val) {
                      setState(() => _agreeTerms = val ?? false);
                    },
                    activeColor: const Color(0xFF1976D2),
                  ),
	                  const Flexible(
	                    child: Text(
	                      '이용약관 및 개인정보 처리방침에 동의합니다',
	                      style: TextStyle(fontSize: 15),
	                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 회원가입 버튼
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
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
                          '회원가입',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
