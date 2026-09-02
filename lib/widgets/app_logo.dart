// lib/widgets/app_logo.dart
import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String? customTitle;
  final String? customSubtitle;
  final Color? primaryColor;
  final double? borderRadius;

  const AppLogo({
    super.key,
    this.size = 72,
    this.showText = false,
    this.customTitle,
    this.customSubtitle,
    this.primaryColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.22);
    final baseColor = primaryColor ?? Colors.deepPurple.shade700;

    Widget iconBadge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/logo/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // Graceful fallback to styled vector icon badge if image fails to load
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [baseColor, Colors.deepPurple.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.qr_code_scanner,
                size: size * 0.58,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );

    if (!showText) return iconBadge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconBadge,
        const SizedBox(height: 14),
        Text(
          customTitle ?? 'Scan & Inventory',
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          customSubtitle ?? 'Smart Offline Point of Sale',
          style: TextStyle(
            fontSize: size * 0.17,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
