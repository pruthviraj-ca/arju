/// app_theme.dart
///
/// Central design system for the TruAssets CRM.
/// Defines the brand color palette, semantic status colors, surfaces,
/// text styles, and pre-built Material [ThemeData] for both light and
/// dark modes. All screens and widgets should reference constants from
/// [AppTheme] instead of defining colors or text styles inline.
///
/// THEME LOCK: light mode — designed for outdoor field use in real estate.
/// All screens must set `Scaffold.backgroundColor = AppTheme.backgroundLight`.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global design-system constants and Material theme configurations.
class AppTheme {
  // ─── Brand Colors ──────────────────────────────────────────────────────────

  /// Primary brand blue — used for buttons, active states, and accents.
  static const Color primary = Color(0xFF1a3c5e);

  /// Lighter tint of the primary color for hover/active states.
  static const Color primaryLight = Color(0xFF2d5f8a);

  /// Very light primary tint used for badge backgrounds and containers.
  static const Color primaryContainer = Color(0xFFd4e4f4);

  /// Amber accent color used for role badges and secondary highlights.
  static const Color accent = Color(0xFFf59e0b);

  /// Light amber container for accent badges.
  static const Color accentContainer = Color(0xFFfef3c7);

  // ─── Semantic Colors ───────────────────────────────────────────────────────

  static const Color success = Color(0xFF059669);
  static const Color successContainer = Color(0xFFd1fae5);

  static const Color warning = Color(0xFFd97706);
  static const Color warningContainer = Color(0xFFfef3c7);

  static const Color error = Color(0xFFdc2626);
  static const Color errorContainer = Color(0xFFfee2e2);

  static const Color purple = Color(0xFF7c3aed);
  static const Color purpleContainer = Color(0xFFede9fe);

  static const Color teal = Color(0xFF0d9488);
  static const Color tealContainer = Color(0xFFccfbf1);

  // ─── Lead Status Badge Colors ──────────────────────────────────────────────

  static const Color statusNew = Color(0xFF6b7280);
  static const Color statusNewBg = Color(0xFFf3f4f6);

  static const Color statusCalled = Color(0xFF1d4ed8);
  static const Color statusCalledBg = Color(0xFFdbeafe);

  static const Color statusFollowUp = Color(0xFFd97706);
  static const Color statusFollowUpBg = Color(0xFFfef3c7);

  static const Color statusSiteVisit = Color(0xFF7c3aed);
  static const Color statusSiteVisitBg = Color(0xFFede9fe);

  static const Color statusSiteVisitDone = Color(0xFF0d9488);
  static const Color statusSiteVisitDoneBg = Color(0xFFccfbf1);

  static const Color statusWon = Color(0xFF059669);
  static const Color statusWonBg = Color(0xFFd1fae5);

  static const Color statusLost = Color(0xFFdc2626);
  static const Color statusLostBg = Color(0xFFfee2e2);

  // ─── Surface Colors ────────────────────────────────────────────────────────

  /// Pure white surface — used for cards, modals, and the app bar.
  static const Color surfaceLight = Color(0xFFFFFFFF);

  /// Neutral off-white — used as the main scaffold/page background.
  static const Color backgroundLight = Color(0xFFF4F6F9);

  /// Subtle border color for cards and dividers.
  static const Color borderColor = Color(0xFFE5E7EB);

  /// Secondary / helper text color.
  static const Color mutedText = Color(0xFF6b7280);

  /// Primary body and heading text color.
  static const Color darkText = Color(0xFF111827);

  // ─── Dark Theme Surfaces ───────────────────────────────────────────────────

  static const Color surfaceDark = Color(0xFF1E2A3A);
  static const Color backgroundDark = Color(0xFF111827);

  // ─── Material ThemeData ────────────────────────────────────────────────────

  /// Light theme used throughout the app.
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: primaryContainer,
          onPrimaryContainer: primary,
          secondary: accent,
          onSecondary: Colors.white,
          secondaryContainer: accentContainer,
          onSecondaryContainer: Color(0xFF78350f),
          surface: surfaceLight,
          onSurface: darkText,
          surfaceContainerHighest: Color(0xFFF9FAFB),
          error: error,
          onError: Colors.white,
          outline: borderColor,
          outlineVariant: Color(0xFFF3F4F6),
        ),
        scaffoldBackgroundColor: backgroundLight,
        textTheme: GoogleFonts.interTextTheme(
          const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: borderColor,
          iconTheme: const IconThemeData(color: primary),
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: surfaceLight,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: error, width: 2),
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: mutedText,
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFFD1D5DB),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 0,
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle:
                GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF3F4F6),
          selectedColor: primaryContainer,
          labelStyle:
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide.none,
        ),
      );

  /// Dark theme — surfaces only; full dark-mode styling is not yet implemented.
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF5b9bd5),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFF1a3c5e),
          onPrimaryContainer: const Color(0xFFd4e4f4),
          secondary: accent,
          onSecondary: Colors.white,
          surface: surfaceDark,
          onSurface: const Color(0xFFE6E6E6),
          error: const Color(0xFFCF6679),
          onError: Colors.white,
          outline: const Color(0xFF374151),
          outlineVariant: const Color(0xFF1F2937),
        ),
        scaffoldBackgroundColor: backgroundDark,
        textTheme: GoogleFonts.interTextTheme(),
      );

  // ─── Status Color Helpers ──────────────────────────────────────────────────

  /// Returns the foreground (text/icon) color for a given lead [status] string.
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return statusNew;
      case 'called':
        return statusCalled;
      case 'follow-up':
        return statusFollowUp;
      case 'site visit scheduled':
        return statusSiteVisit;
      case 'site visit done':
        return statusSiteVisitDone;
      case 'won':
        return statusWon;
      case 'lost/dead':
        return statusLost;
      default:
        return statusNew;
    }
  }

  /// Returns the background color for a given lead [status] badge.
  static Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return statusNewBg;
      case 'called':
        return statusCalledBg;
      case 'follow-up':
        return statusFollowUpBg;
      case 'site visit scheduled':
        return statusSiteVisitBg;
      case 'site visit done':
        return statusSiteVisitDoneBg;
      case 'won':
        return statusWonBg;
      case 'lost/dead':
        return statusLostBg;
      default:
        return statusNewBg;
    }
  }
}
