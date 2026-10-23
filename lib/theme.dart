import 'package:flutter/material.dart';

class MoreJobColors {
  static const Color ink = Color(0xFF102033);
  static const Color muted = Color(0xFF6B7280);
  static const Color brand = Color(0xFFFF7A11);
  static const Color brandStrong = Color(0xFFFF5A00);
  static const Color brandSoft = Color(0xFFFFF4EC);
  static const Color brandBorder = Color(0xFFFFD8BD);
  static const Color green = Color(0xFF10B981);
  static const Color greenDark = Color(0xFF00875A);
  static const Color greenSoft = Color(0xFFEDFAF5);
  static const Color blueSoft = Color(0xFFE6F0FF);
  static const Color bluePrimary = Color(0xFF1A5FA8);
  static const Color panel = Color(0xFFF5F8FF);
  static const Color bg = Color(0xFFF5F8FF);
  static const Color shell = Color(0xFFEEF6FF);
  static const Color accent = Color(0xFF0F3560);
  static const Color navy = Color(0xFF0F3560);
  static const Color sidebar = Color(0xFFE9F8FF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFFBEB);
}

class MoreJobTheme {
  static const String fontFamily = 'Be Vietnam Pro';
  static const List<String> fontFamilyFallback = [
    'Segoe UI',
    'Roboto',
    'Helvetica',
    'Arial',
    'sans-serif',
  ];

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      bodyColor: MoreJobColors.ink,
      displayColor: MoreJobColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      scaffoldBackgroundColor: MoreJobColors.panel,
      colorScheme: ColorScheme.fromSeed(
        seedColor: MoreJobColors.brand,
        primary: MoreJobColors.brand,
        onPrimary: Colors.white,
        secondary: MoreJobColors.accent,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: MoreJobColors.ink,
        error: MoreJobColors.danger,
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: MoreJobColors.ink,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: MoreJobColors.ink,
          letterSpacing: -0.4,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: MoreJobColors.ink,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: MoreJobColors.ink,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: MoreJobColors.ink,
        ),
        titleSmall: baseTextTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: MoreJobColors.ink,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: MoreJobColors.ink,
          height: 1.45,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: MoreJobColors.ink,
          height: 1.45,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: MoreJobColors.muted,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: MoreJobColors.ink,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.white,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: MoreJobColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MoreJobColors.border),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MoreJobColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: MoreJobColors.muted,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MoreJobColors.ink,
          side: const BorderSide(color: MoreJobColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: const TextStyle(
          color: MoreJobColors.muted,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoreJobColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoreJobColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoreJobColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MoreJobColors.danger),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: MoreJobColors.brandSoft,
        surfaceTintColor: Colors.white,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? MoreJobColors.brandStrong : MoreJobColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? MoreJobColors.brandStrong : MoreJobColors.muted,
            size: 22,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MoreJobColors.brandSoft,
        selectedColor: MoreJobColors.brand,
        secondarySelectedColor: MoreJobColors.brand,
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: MoreJobColors.ink,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: MoreJobColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MoreJobColors.border,
        thickness: 1,
      ),
    );
  }
}

class MoreJobLogoText extends StatelessWidget {
  const MoreJobLogoText({
    super.key,
    this.fontSize = 22,
    this.darkBackground = false,
  });
  final double fontSize;
  final bool darkBackground;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: MoreJobTheme.fontFamily,
          fontFamilyFallback: MoreJobTheme.fontFamilyFallback,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'More',
            style: TextStyle(
              color: darkBackground ? Colors.white : MoreJobColors.ink,
            ),
          ),
          const TextSpan(
            text: 'Job',
            style: TextStyle(color: MoreJobColors.brand),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color,
    this.background = MoreJobColors.brandSoft,
    this.foreground = MoreJobColors.brandStrong,
    this.icon,
  });

  final String label;
  final Color? color;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? foreground;
    final bg = color != null ? color!.withValues(alpha: 0.14) : background;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
