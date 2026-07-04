import 'package:flutter/cupertino.dart' show CupertinoThemeData;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

// ─── Spacing tokens (4px grid) ──────────────────────────────────────
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 32;

  // Semantic spacing
  static const double cardGap = 12;
  static const double sectionGap = 20;
  static const double screenPaddingH = 16;
}

// ─── Size tokens ────────────────────────────────────────────────────
class AppSize {
  static const double minTouchTarget = 44;
  static const double buttonSmall = 32;
  static const double buttonMedium = 40;
  static const double buttonLarge = 48;
}

// ─── Border radius tokens ───────────────────────────────────────────
class AppRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double input = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 44;
  static const double full = 999;

  static final BorderRadius cardRadius = BorderRadius.circular(lg);
  static final BorderRadius buttonRadius = BorderRadius.circular(md);
  static final BorderRadius inputRadius = BorderRadius.circular(input);
  static final BorderRadius sheetRadius = BorderRadius.vertical(top: Radius.circular(xxl));
}

// ─── Icon size tokens ───────────────────────────────────────────────
class AppIconSize {
  static const double small = 14;
  static const double base = 16;
  static const double medium = 18;
  static const double large = 24;
  static const double xlarge = 32;
}

// ─── Colors ─────────────────────────────────────────────────────────
class AppColors {
  // Brightness toggle — set by MaterialApp builder on theme change
  static Brightness _brightness = Brightness.light;
  static void updateBrightness(Brightness b) { _brightness = b; }
  static bool get _isDark => _brightness == Brightness.dark;
  static bool get isDarkMode => _isDark;

  // ─── Brand / accent colors (same in light & dark) ─────────────
  static const Color primary = Color(0xFF6366F1);       // indigo-500
  static const Color primaryLight = Color(0xFF818CF8);   // indigo-400
  static const Color primaryDark = Color(0xFF4F46E5);    // indigo-600
  static const Color primaryUltraLight = Color(0xFFE0E7FF); // indigo-100

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  // Macros
  static const Color macroProtein = Color(0xFFF43F5E);   // rose-500
  static const Color macroCarbs = Color(0xFF06B6D4);     // cyan-500
  static const Color macroFats = Color(0xFFF59E0B);      // amber-500

  // Success
  static const Color success = Color(0xFF10B981);        // emerald-500
  static const Color successLight = Color(0xFF34D399);   // emerald-400
  static const Color successDark = Color(0xFF059669);    // emerald-600

  // Danger
  static const Color danger = Color(0xFFEF4444);         // red-500
  static const Color dangerLight = Color(0xFFF87171);    // red-400
  static const Color dangerDark = Color(0xFFDC2626);     // red-600

  // Warning
  static const Color warning = Color(0xFFF59E0B);        // amber-500
  static const Color warningDark = Color(0xFFD97706);    // amber-600

  // Water/info
  static const Color water = Color(0xFF06B6D4);          // cyan-500
  static const Color waterLight = Color(0xFF22D3EE);     // cyan-400
  static const Color waterDark = Color(0xFF0891B2);      // cyan-600

  // Meal colors
  static const Color mealBreakfast = Color(0xFFF59E0B);
  static const Color mealLunch = Color(0xFF10B981);
  static const Color mealDinner = Color(0xFF6366F1);
  static const Color mealSnack = Color(0xFFEF4444);

  // Category colors
  static const Color catChest = Color(0xFFEF4444);
  static const Color catBack = Color(0xFF3B82F6);
  static const Color catShoulders = Color(0xFFA855F7);
  static const Color catLegs = Color(0xFF22C55E);
  static const Color catArms = Color(0xFFF97316);
  static const Color catCore = Color(0xFFEAB308);
  static const Color catCardio = Color(0xFF10B981);

  static const Map<String, Color> categoryColors = {
    'chest': catChest, 'back': catBack, 'shoulders': catShoulders,
    'legs': catLegs, 'arms': catArms, 'core': catCore, 'cardio': catCardio,
  };

  // Extra accent colors
  static const Color orange = Color(0xFFF97316);
  static const Color purple = Color(0xFFA855F7);
  static const Color blue = Color(0xFF3B82F6);
  static const Color yellow = Color(0xFFEAB308);
  static const Color lime = Color(0xFF84CC16);
  static const Color teal = Color(0xFF2DD4BF);
  static const Color sky = Color(0xFF0EA5E9);

  static const Color textOnPrimary = Colors.white;

  // ─── Theme-dependent colors (getters) ─────────────────────────

  // Surfaces
  static Color get background => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get surface    => _isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get surfaceAlt => _isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  // Borders
  static Color get border       => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  static Color get borderLight  => _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get borderSubtle => _isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000);

  // Divider / overlay
  static Color get dividerIOS   => _isDark ? const Color(0x3D787880) : const Color(0x1A787880);
  static Color get shadowLight  => _isDark ? const Color(0x33000000) : const Color(0x08000000);
  static Color get shadowMedium => _isDark ? const Color(0x4D000000) : const Color(0x0C000000);
  static Color get shadowSubtle => _isDark ? const Color(0x26000000) : const Color(0x06000000);

  // Text hierarchy
  static Color get textPrimary   => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  static Color get textSecondary => _isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static Color get textMuted     => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textHint      => _isDark ? const Color(0xFF64748B) : const Color(0xFF6B7A8D);
  static Color get iconMuted     => _isDark ? const Color(0xFF64748B) : const Color(0xFF6B7A8D);

  // Soft background tints (chips, badges, tags)
  static Color get successBg      => _isDark ? const Color(0xFF1B4D4D) : const Color(0xFFD1FAE5);
  static Color get dangerBg       => _isDark ? const Color(0xFF52303D) : const Color(0xFFFEF2F2);
  static Color get warningBg      => _isDark ? const Color(0xFF494031) : const Color(0xFFFFFBEB);
  static Color get macroProteinBg => _isDark ? const Color(0xFF492D42) : const Color(0xFFFEF2F2);
  static Color get macroCarbsBg   => _isDark ? const Color(0xFF19455A) : const Color(0xFFECFEFF);
  static Color get macroFatsBg    => _isDark ? const Color(0xFF494031) : const Color(0xFFFFFBEB);

  // ─── Gradient mesh background ─────────────────────────────────
  static Widget gradientMesh({required Widget child}) {
    final bg = background;
    final indigoA = _isDark ? 46 : 31;
    final violetA = _isDark ? 31 : 20;
    final pinkA   = _isDark ? 20 : 13;
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: bg)),
        // RepaintBoundary allows GPU to cache static gradient layers
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, 0.6),
                  radius: 0.8,
                  colors: [Color(0xFF6366F1).withAlpha(indigoA), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.6),
                  radius: 0.8,
                  colors: [Color(0xFF8B5CF6).withAlpha(violetA), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [Color(0xFFEC4899).withAlpha(pinkA), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }

  // ─── Card shadows ─────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadowLight, blurRadius: 3, offset: const Offset(0, 1)),
    BoxShadow(color: shadowLight, blurRadius: 8, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get cardShadowElevated => [
    BoxShadow(color: shadowMedium, blurRadius: 4, offset: const Offset(0, 1)),
    BoxShadow(color: shadowLight, blurRadius: 12, offset: const Offset(0, 4)),
  ];

  // Card decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: AppRadius.cardRadius,
    border: Border.all(color: borderSubtle),
    boxShadow: cardShadow,
  );

  static BoxDecoration get cardDecorationElevated => BoxDecoration(
    color: surface,
    borderRadius: AppRadius.cardRadius,
    border: Border.all(color: borderSubtle),
    boxShadow: cardShadowElevated,
  );
}

// ─── Text styles ────────────────────────────────────────────────────
class AppTextStyles {
  static TextStyle get display => TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, height: 1.2,
  );

  static TextStyle get headline => TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.25,
  );

  static TextStyle get heading => TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
  );

  static TextStyle get title => TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, height: 1.3,
  );

  static TextStyle get titleMedium => TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.35,
  );

  static TextStyle get subheading => TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, height: 1.4,
  );

  static TextStyle get body => TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.5,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500,
    color: AppColors.textPrimary, height: 1.5,
  );

  static TextStyle get label => TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, height: 1.4,
  );

  static TextStyle get caption => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.textSecondary, height: 1.4,
  );

  static TextStyle get small => TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500,
    color: AppColors.textMuted, height: 1.4,
  );

  static TextStyle get micro => TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textMuted, height: 1.3,
  );
}

// ─── Theme ──────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // Resolve colors locally without touching global _brightness
    final bg       = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surf     = isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
    final bord     = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPri  = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSec  = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final textMut  = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final hint     = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    final tDisplay    = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPri, height: 1.2);
    final tHeading    = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textPri, height: 1.2);
    final tTitle      = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPri, height: 1.25);
    final tSubheading = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textPri, height: 1.4);
    final tBodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPri, height: 1.5);
    final tBody       = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textPri, height: 1.5);
    final tLabel      = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSec, height: 1.4);
    final tCaption    = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSec, height: 1.4);
    final tSmall      = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textMut, height: 1.4);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        surface: surf,
      ),
      scaffoldBackgroundColor: bg,
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        // Don't override primaryColor — default system blue gives clean
        // glass tint on iOS 26 alerts instead of heavy indigo wash
        barBackgroundColor: surf.withAlpha(220),
        scaffoldBackgroundColor: bg,
      ),

      // Text theme with themed colors
      textTheme: TextTheme(
        displayLarge: tDisplay,
        headlineLarge: tHeading,
        titleLarge: tTitle,
        titleMedium: tSubheading,
        bodyLarge: tBodyMedium,
        bodyMedium: tBody,
        labelLarge: tLabel,
        bodySmall: tCaption,
        labelSmall: tSmall,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: surf,
        margin: EdgeInsets.zero,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        scrolledUnderElevation: _isIOS ? 0.1 : null,
        surfaceTintColor: _isIOS ? Colors.transparent : null,
        centerTitle: _isIOS,
        titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, color: textPri,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surf,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
        ),
        showDragHandle: false,
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: bord),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: bord),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: isDark ? surf : bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(color: hint),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withAlpha(60),
        selectionHandleColor: AppColors.primary,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x406366F1),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      dividerTheme: DividerThemeData(
        color: bord,
        thickness: 0.5,
        space: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
