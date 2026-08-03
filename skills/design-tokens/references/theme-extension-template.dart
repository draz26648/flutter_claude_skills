// Reference structure for the AppTokens ThemeExtension.
// Adapt names to the project; keep the shape.

import 'package:flutter/material.dart';

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.color,
    required this.space,
    required this.radius,
    required this.text,
    required this.elevation,
    required this.motion,
  });

  final AppColors color;
  final AppSpacing space;
  final AppRadius radius;
  final AppTypography text;
  final AppElevation elevation;
  final AppMotion motion;

  @override
  AppTokens copyWith({
    AppColors? color,
    AppSpacing? space,
    AppRadius? radius,
    AppTypography? text,
    AppElevation? elevation,
    AppMotion? motion,
  }) {
    return AppTokens(
      color: color ?? this.color,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      text: text ?? this.text,
      elevation: elevation ?? this.elevation,
      motion: motion ?? this.motion,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      color: color.lerp(other.color, t),
      space: space,
      radius: radius,
      text: text,
      elevation: elevation,
      motion: motion,
    );
  }

  static const light = AppTokens(
    color: AppColors.light,
    space: AppSpacing.standard,
    radius: AppRadius.standard,
    text: AppTypography.standard,
    elevation: AppElevation.light,
    motion: AppMotion.standard,
  );

  static const dark = AppTokens(
    color: AppColors.dark,
    space: AppSpacing.standard,
    radius: AppRadius.standard,
    text: AppTypography.standard,
    elevation: AppElevation.dark,
    motion: AppMotion.standard,
  );
}

@immutable
class AppColors {
  const AppColors({
    required this.surface,
    required this.surfaceRaised,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.danger,
    required this.success,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color textPrimary;
  final Color textSecondary;
  final Color brand;
  final Color danger;
  final Color success;

  static const light = AppColors(
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF7F8FA),
    textPrimary: Color(0xFF101828),
    textSecondary: Color(0xFF667085),
    brand: Color(0xFF1B6EF3),
    danger: Color(0xFFD92D20),
    success: Color(0xFF039855),
  );

  static const dark = AppColors(
    surface: Color(0xFF0C111D),
    surfaceRaised: Color(0xFF161B26),
    textPrimary: Color(0xFFF5F5F6),
    textSecondary: Color(0xFF94969C),
    brand: Color(0xFF528BFF),
    danger: Color(0xFFF97066),
    success: Color(0xFF47CD89),
  );

  AppColors lerp(AppColors other, double t) {
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

@immutable
class AppSpacing {
  const AppSpacing();
  static const standard = AppSpacing();

  double get xsValue => 4;
  double get smValue => 8;
  double get mdValue => 16;
  double get lgValue => 24;
  double get xlValue => 32;

  EdgeInsetsGeometry get xs => const EdgeInsets.all(4);
  EdgeInsetsGeometry get sm => const EdgeInsets.all(8);
  EdgeInsetsGeometry get md => const EdgeInsets.all(16);
  EdgeInsetsGeometry get lg => const EdgeInsets.all(24);

  // Directional variants. Use these, never EdgeInsets.only(left:).
  EdgeInsetsGeometry get screenH =>
      const EdgeInsetsDirectional.symmetric(horizontal: 16);
}

@immutable
class AppRadius {
  const AppRadius();
  static const standard = AppRadius();

  BorderRadius get sm => BorderRadius.circular(8);
  BorderRadius get card => BorderRadius.circular(12);
  BorderRadius get sheet => BorderRadius.circular(20);
  BorderRadius get pill => BorderRadius.circular(999);
}

@immutable
class AppTypography {
  const AppTypography();
  static const standard = AppTypography();

  TextStyle get displayLarge =>
      const TextStyle(fontSize: 32, height: 1.25, fontWeight: FontWeight.w700);
  TextStyle get titleMedium =>
      const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600);
  TextStyle get bodyMedium =>
      const TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w400);
  TextStyle get caption =>
      const TextStyle(fontSize: 12, height: 1.33, fontWeight: FontWeight.w400);
}

@immutable
class AppElevation {
  const AppElevation({required this.low, required this.high});
  final List<BoxShadow> low;
  final List<BoxShadow> high;

  static const light = AppElevation(
    low: [BoxShadow(color: Color(0x0D101828), blurRadius: 4, offset: Offset(0, 2))],
    high: [BoxShadow(color: Color(0x1A101828), blurRadius: 16, offset: Offset(0, 8))],
  );

  static const dark = AppElevation(
    low: [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
    high: [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 8))],
  );
}

@immutable
class AppMotion {
  const AppMotion();
  static const standard = AppMotion();

  Duration get fast => const Duration(milliseconds: 150);
  Duration get normal => const Duration(milliseconds: 250);
  Duration get slow => const Duration(milliseconds: 400);
  Curve get standardCurve => Curves.easeOutCubic;
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
