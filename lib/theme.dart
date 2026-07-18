import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color oat, cup, espresso, crema, cremaInk, appMuted, appLine, cherry;
  const AppColors({
    required this.oat,
    required this.cup,
    required this.espresso,
    required this.crema,
    required this.cremaInk,
    required this.appMuted,
    required this.appLine,
    required this.cherry,
  });

  static const light = AppColors(
    oat: Color(0xFFECE6DB),
    cup: Color(0xFFFCFBF8),
    espresso: Color(0xFF2B2019),
    crema: Color(0xFFB67B2E),
    cremaInk: Color(0xFF8A5A18),
    appMuted: Color(0xFF8C8172),
    appLine: Color(0xFFE4DED2),
    cherry: Color(0xFF9E3B2D),
  );

  @override
  AppColors copyWith({Color? oat, Color? cup, Color? espresso, Color? crema,
      Color? cremaInk, Color? appMuted, Color? appLine, Color? cherry}) =>
      AppColors(
        oat: oat ?? this.oat, cup: cup ?? this.cup,
        espresso: espresso ?? this.espresso, crema: crema ?? this.crema,
        cremaInk: cremaInk ?? this.cremaInk, appMuted: appMuted ?? this.appMuted,
        appLine: appLine ?? this.appLine, cherry: cherry ?? this.cherry,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      oat: Color.lerp(oat, other.oat, t)!,
      cup: Color.lerp(cup, other.cup, t)!,
      espresso: Color.lerp(espresso, other.espresso, t)!,
      crema: Color.lerp(crema, other.crema, t)!,
      cremaInk: Color.lerp(cremaInk, other.cremaInk, t)!,
      appMuted: Color.lerp(appMuted, other.appMuted, t)!,
      appLine: Color.lerp(appLine, other.appLine, t)!,
      cherry: Color.lerp(cherry, other.cherry, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

TextStyle monoStyle({double size = 12, FontWeight weight = FontWeight.w600, Color? color}) =>
    TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['SF Mono', 'Menlo', 'Roboto Mono', 'Consolas'],
      fontSize: size,
      fontWeight: weight,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

class AppTheme {
  static ThemeData get light {
    const c = AppColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: c.crema,
      brightness: Brightness.light,
    ).copyWith(surface: c.cup, primary: c.crema);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.oat,
      extensions: const [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.oat,
        foregroundColor: c.espresso,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
