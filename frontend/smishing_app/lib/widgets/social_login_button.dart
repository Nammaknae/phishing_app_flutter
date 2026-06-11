import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  final Color color;
  final Color textColor;
  final Widget logo;
  final String text;
  final VoidCallback onTap;
  final bool hasBorder;

  const SocialLoginButton({
    super.key,
    required this.color,
    required this.textColor,
    required this.logo,
    required this.text,
    required this.onTap,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: hasBorder ? 0 : 1,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: hasBorder
                ? const BorderSide(color: Color(0xFFE0E0E0), width: 1)
                : BorderSide.none,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 220,
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(child: logo),
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
