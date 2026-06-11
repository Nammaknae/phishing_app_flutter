import 'package:flutter/material.dart';

/// =======================
/// 카카오 로고 (둥근 말풍선)
/// =======================
class KakaoLogo extends StatelessWidget {
  const KakaoLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _KakaoBubblePainter(),
      ),
    );
  }
}

class _KakaoBubblePainter extends CustomPainter {
  const _KakaoBubblePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A1D1D)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 둥근 말풍선 본체
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.15,
        size.height * 0.15,
        size.width * 0.70,
        size.height * 0.55,
      ),
      Radius.circular(size.height * 0.40),
    );

    canvas.drawRRect(bubble, paint);

    // 꼬리
    final tail = Path()
      ..moveTo(size.width * 0.40, size.height * 0.63)
      ..lineTo(size.width * 0.30, size.height * 0.85)
      ..lineTo(size.width * 0.52, size.height * 0.66)
      ..close();

    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// =======================
/// 네이버 로고
/// =======================
class NaverLogo extends StatelessWidget {
  const NaverLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// =======================
/// 구글 로고
/// =======================
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Image.asset(
        'assets/images/google_logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
