import 'package:flutter/cupertino.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AdolaTheme {
  AdolaTheme._();

  static final ShadThemeData light = ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadSlateColorScheme.light(),
    radius: const BorderRadius.all(Radius.circular(14)),
  );

  static final ShadThemeData dark = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadSlateColorScheme.dark(),
    radius: const BorderRadius.all(Radius.circular(14)),
  );

  static CupertinoThemeData cupertinoTheme(BuildContext context) {
    final shad = ShadTheme.of(context);
    final isDark = shad.brightness == Brightness.dark;

    return CupertinoThemeData(
      brightness: shad.brightness,
      primaryColor: shad.colorScheme.primary,
      scaffoldBackgroundColor: shad.colorScheme.background,
      barBackgroundColor: tabBarBackground(shad.brightness),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(
          color: shad.colorScheme.foreground,
          fontSize: 15,
          height: 1.4,
        ),
        navTitleTextStyle: TextStyle(
          color: shad.colorScheme.foreground,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        navLargeTitleTextStyle: TextStyle(
          color: shad.colorScheme.foreground,
          fontSize: 31,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        actionTextStyle: TextStyle(
          color: shad.colorScheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        tabLabelTextStyle: TextStyle(
          color: isDark
              ? shad.colorScheme.mutedForeground.withValues(alpha: 0.88)
              : shad.colorScheme.mutedForeground.withValues(alpha: 0.78),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Color tabBarBackground(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const Color(0xFF0F172A).withValues(alpha: 0.94);
    }
    return const Color(0xFFF8FAFC).withValues(alpha: 0.95);
  }

  static Border tabBarBorder(ShadThemeData theme) {
    return Border(
      top: BorderSide(
        color: theme.colorScheme.border.withValues(alpha: 0.88),
        width: 0.5,
      ),
    );
  }
}
