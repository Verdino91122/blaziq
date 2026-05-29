import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design system for Blaziq.
/// All colors, text styles, and ThemeData live here.
/// Screens must import this file — never hardcode colors or text styles.
class AppTheme {
  AppTheme._();

  // ── Colors ───────────────────────────────────────────────────────────────

  /// Main screen background
  static const Color arenaBlack = Color(0xFF1A1A2E);

  /// Card / surface background
  static const Color cardSurface = Color(0xFF242440);

  /// Deepest background — nav bar, overlays
  static const Color voidBlack = Color(0xFF0D0D1A);

  /// Primary accent — gold (correct answers, XP, highlights, CTAs)
  static const Color blazeGold = Color(0xFFF0B429);

  /// Secondary accent — pink (wrong answers, toggles, live states)
  static const Color sparkPink = Color(0xFFE91E8C);

  /// Primary text
  static const Color whiteText = Color(0xFFF5F5F5);

  /// Secondary / muted text
  static const Color mutedText = Color(0xFF888888);

  /// Divider / border
  static const Color divider = Color(0xFF2A2A4A);

  /// Header bar — slightly darker than arenaBlack
  static const Color headerBar = Color(0xFF14142A);

  /// Store power-up item icon colour
  static const Color powerUpBlue = Color(0xFF5B9BD5);

  /// Best-offer ribbon background
  static const Color bestOfferRed = Color(0xFFD32F2F);

  // Difficulty level colours — Solo game mode
  static const Color difficultyEasy = blazeGold;
  static const Color difficultyMedium = Color(0xFF64B5F6);
  static const Color difficultyHard = sparkPink;

  // Mode card gradient — shared by all three mode cards
  /// Dark indigo gradient used on Solo, Friend, and Online cards
  static const Color modeCardStart = Color(0xFF2D2D5E);
  static const Color modeCardEnd = Color(0xFF1A1A3A);

  // Google Sign-In brand colours
  static const Color googleButtonText = Color(0xFF3C4043);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleRed = Color(0xFFEA4335);

  // Leaderboard rank medal colours
  /// Silver — 2nd place badge
  static const Color rankSilver = Color(0xFF90A4AE);

  /// Bronze — 3rd place badge
  static const Color rankBronze = Color(0xFFB87333);

  /// Placeholder avatar colours for the static leaderboard (indices 0–9)
  static const List<Color> leaderboardAvatars = [
    Color(0xFF5B6FA8), // 0 – Rita Singh (2nd)
    Color(0xFFC49A3A), // 1 – Stephan Jones (1st)
    Color(0xFF9B6B4A), // 2 – Sami Kamara (3rd)
    Color(0xFF4A6A8A), // 3 – Elena Rodriguez
    Color(0xFF6A4A8A), // 4 – Marco Rossi
    Color(0xFF4A8A6A), // 5 – Amara Okoro
    Color(0xFF8A6A4A), // 6 – Leo Dubois
    Color(0xFF8A4A6A), // 7 – Julia Silva
    Color(0xFF4A7A8A), // 8 – David Cuevas
    Color(0xFF7A8A4A), // 9 – Sarah Miller
  ];

  // ── Text Styles ──────────────────────────────────────────────────────────

  /// Main screen titles — LEADERBOARD, SETTINGS
  static TextStyle get screenTitle => GoogleFonts.rajdhani(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: whiteText,
        letterSpacing: 4.0,
      );

  /// Store screen title — SHOP
  static TextStyle get storeTitle => GoogleFonts.rajdhani(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: whiteText,
        letterSpacing: 4.0,
      );

  /// App bar title — e.g. SOLO MODE
  static TextStyle get appBarTitle => GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: whiteText,
        letterSpacing: 3.0,
      );

  /// Profile page heading — SAVE YOUR PROGRESS!
  static TextStyle get subheading => GoogleFonts.rajdhani(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: whiteText,
        letterSpacing: 2.0,
      );

  /// "SELECT A MODE" label above carousel
  static TextStyle get selectModeLabel => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: whiteText,
        letterSpacing: 3.0,
      );

  /// Carousel mode card title — SOLO, WITH FRIEND, ONLINE
  static TextStyle get modeTitle => GoogleFonts.rajdhani(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: whiteText,
        letterSpacing: 4.0,
      );

  /// CTA button labels on colored backgrounds (dark text)
  static TextStyle get buttonLabel => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: voidBlack,
        letterSpacing: 2.0,
      );

  /// Settings section header — AUDIO & HAPTICS
  static TextStyle get sectionHeader => GoogleFonts.rajdhani(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: mutedText,
        letterSpacing: 1.5,
      );

  /// Settings row label text
  static TextStyle get rowLabel => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: whiteText,
      );

  /// Body text, muted — descriptions, subtitles
  static TextStyle get bodyMuted => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: mutedText,
        height: 1.5,
      );

  /// Header bar stat chip values — "67", "6"
  static TextStyle get statValue => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: whiteText,
      );

  /// Small caption — XP counter, sub-labels
  static TextStyle get caption => GoogleFonts.rajdhani(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: mutedText,
      );

  /// Bottom nav labels — color resolved by caller with copyWith
  static TextStyle get navLabel => GoogleFonts.rajdhani(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      );

  /// Leaderboard filter tab text — color resolved by caller with copyWith
  static TextStyle get filterTab => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      );

  /// Rank badge inside podium cards — 1st, 2nd, 3rd
  static TextStyle get rankBadge => GoogleFonts.rajdhani(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 0.5,
      );

  /// Podium player first name
  static TextStyle get podiumName => GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: whiteText,
      );

  /// Podium score value (gold)
  static TextStyle get podiumScore => GoogleFonts.rajdhani(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: blazeGold,
      );

  /// Player rank number in list rows (muted)
  static TextStyle get rankNumber => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: mutedText,
      );

  /// Player name in list rows
  static TextStyle get playerName => GoogleFonts.rajdhani(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: whiteText,
      );

  /// Score value in list rows (gold)
  static TextStyle get score => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: blazeGold,
      );

  /// Store bundle name strip text
  static TextStyle get bundleName => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 2.5,
      );

  /// Store price button text — dark text on gold button
  static TextStyle get priceText => GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: voidBlack,
      );

  /// Store item quantity label
  static TextStyle get itemLabel => GoogleFonts.rajdhani(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: whiteText,
      );

  /// Store coin balance in header chip
  static TextStyle get coinBalance => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      );

  /// Best-offer ribbon label
  static TextStyle get ribbonLabel => GoogleFonts.rajdhani(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: 1.0,
      );

  /// Reward / highlight note (gold)
  static TextStyle get rewardText => GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: blazeGold,
        letterSpacing: 0.5,
      );

  /// Footer link text (muted, underlined)
  static TextStyle get footerLink => GoogleFonts.rajdhani(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: mutedText,
        decoration: TextDecoration.underline,
        decorationColor: mutedText,
      );

  /// SnackBar message — must include explicit white color
  static TextStyle get snackText => GoogleFonts.rajdhani(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: whiteText,
      );

  /// Solo game — current streak counter
  static TextStyle get streakText => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: blazeGold,
      );

  /// Solo game — difficulty badge label (color applied via copyWith at call site)
  static TextStyle get difficultyBadge => GoogleFonts.rajdhani(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: whiteText,
      );

  /// Solo game screen — question card text
  static TextStyle get questionText => GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: whiteText,
        height: 1.4,
      );

  /// Solo game screen — circular countdown timer number
  static TextStyle get timerText => GoogleFonts.rajdhani(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: whiteText,
      );

  /// Solo game screen — answer button label
  static TextStyle get answerText => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: whiteText,
      );

  /// Sign-in button label — color varies per provider
  static TextStyle signInLabel(Color color) => GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.3,
      );

  // ── ThemeData ────────────────────────────────────────────────────────────

  static ThemeData get theme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: arenaBlack,
      colorScheme: const ColorScheme.dark(
        primary: blazeGold,
        secondary: sparkPink,
        surface: cardSurface,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(base.textTheme).apply(
        bodyColor: whiteText,
        displayColor: whiteText,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.grey.shade400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? blazeGold : Colors.grey.shade700,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
