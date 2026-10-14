import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dr Gut design tokens — light, editorial "studio" palette.
/// Warm off-white base, deep olive primary, lime accent.
class DrGutColors {
  // ── Backgrounds ──────────────────────────────────────────
  static const background     = Color(0xFFF4F2EA); // warm cream page
  static const surface        = Color(0xFFFFFFFF); // card / field background
  static const surfaceBorder  = Color(0xFFDAD6C8); // 1px border on cards/fields
  static const footerDark     = Color(0xFF1C2012); // dark olive footer / dark section bg

  // ── Brand ────────────────────────────────────────────────
  static const primary        = Color(0xFF262B1C); // deep olive – buttons, headings, dark sections
  static const accent         = Color(0xFFC9F031); // lime – text/icon on primary, callout fill
  static const onPrimary      = Color(0xFFC9F031); // lime label on dark olive button/section
  static const onAccent       = Color(0xFF1C2012); // near-black text on lime callout block

  // ── Text ─────────────────────────────────────────────────
  static const textPrimary    = Color(0xFF1C1C16); // headings, body on cream
  static const textOnDark     = Color(0xFFEDEBDD); // body text on dark olive section
  static const textSecondary  = Color(0xFF6B6A5E); // labels, captions
  static const textMuted      = Color(0xFF9C9A8C); // disabled, placeholders

  // ── Utility ──────────────────────────────────────────────
  static const error          = Color(0xFFC1443A);
  static const divider        = Color(0xFFE4E1D4);

  // ── Legacy compat (kept to avoid breaking any callers) ────
  static const primaryGradientEnd = primary;
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
  );
}

/// Builds the Material 3 light theme for Dr Gut.
/// Typography: Fraunces (display serif) + Inter (body sans).
ThemeData buildDrGutTheme() {
  final base = ThemeData.light(useMaterial3: true);

  // Inter as the base UI text theme
  final interTextTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: DrGutColors.textPrimary,
    displayColor: DrGutColors.textPrimary,
  );

  const colorScheme = ColorScheme.light(
    surface: DrGutColors.background,
    surfaceContainer: DrGutColors.surface,
    primary: DrGutColors.primary,
    onPrimary: DrGutColors.onPrimary,  // #C9F031 lime
    secondary: DrGutColors.accent,
    onSecondary: DrGutColors.onAccent,
    onSurface: DrGutColors.textPrimary,
    outline: DrGutColors.surfaceBorder,
    error: DrGutColors.error,
    onError: DrGutColors.surface,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: DrGutColors.background,
    textTheme: interTextTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: DrGutColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: DrGutColors.textPrimary,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: GoogleFonts.inter(
        color: DrGutColors.textPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w600,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DrGutColors.surface,
      labelStyle: GoogleFonts.inter(
        color: DrGutColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: GoogleFonts.inter(
        color: DrGutColors.textMuted,
        fontSize: 15,
      ),
      prefixIconColor: DrGutColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DrGutColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DrGutColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DrGutColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    cardTheme: CardThemeData(
      color: DrGutColors.surface,
      elevation: 1, // elevation=1 renders the shadowColor below
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
    ),

    dividerTheme: const DividerThemeData(
      color: DrGutColors.divider,
      thickness: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: DrGutColors.primary,
      contentTextStyle: GoogleFonts.inter(color: DrGutColors.onPrimary),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: DrGutColors.primary,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: DrGutColors.primary,
        foregroundColor: DrGutColors.onPrimary,
        minimumSize: const Size(64, 48),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    iconTheme: const IconThemeData(
      color: DrGutColors.textPrimary,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DrGutColors.primary,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DrGutColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the Display serif style (Fraunces) — used for the one big headline
/// per screen. Apply explicitly per widget.
TextStyle displaySerifStyle({
  double fontSize = 30,
  FontStyle fontStyle = FontStyle.normal,
  Color color = DrGutColors.textPrimary,
}) {
  return GoogleFonts.fraunces(
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    fontStyle: fontStyle,
    color: color,
    height: 1.1,
  );
}

/// Eyebrow/tag label: Inter, 12sp, medium, letter-spaced, uppercase.
TextStyle eyebrowStyle({Color color = DrGutColors.textSecondary}) {
  return GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    color: color,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Components
// ─────────────────────────────────────────────────────────────────────────────

/// Primary pill button — solid deep olive fill, lime label.
/// Replaces the previous gradient/glow button.
class GradientPillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  State<GradientPillButton> createState() => _GradientPillButtonState();
}

class _GradientPillButtonState extends State<GradientPillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.loading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: disabled ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: disabled && !widget.loading ? 0.45 : 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: DrGutColors.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                splashColor: DrGutColors.onPrimary.withValues(alpha: 0.15),
                highlightColor: Colors.transparent,
                onTap: disabled ? null : widget.onPressed,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: DrGutColors.onPrimary,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.icon != null) ...[
                                Icon(widget.icon,
                                    color: DrGutColors.onPrimary, size: 20),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                widget.label,
                                style: GoogleFonts.inter(
                                  color: DrGutColors.onPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary outline pill button — transparent fill, 1.5px olive border.
class OutlinePillButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const OutlinePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  State<OutlinePillButton> createState() => _OutlinePillButtonState();
}

class _OutlinePillButtonState extends State<OutlinePillButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: disabled ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: DrGutColors.primary,
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: disabled ? null : widget.onPressed,
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              color: DrGutColors.textPrimary, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            color: DrGutColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon badge with a 10% tinted background — used in cards.
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;

  const IconChip({
    super.key,
    required this.icon,
    this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? DrGutColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: c, size: size * 0.48),
    );
  }
}

/// Small eyebrow / tag row: ✦ glyph + uppercase tracked label.
class EyebrowTag extends StatelessWidget {
  final String label;
  final IconData icon;

  const EyebrowTag({
    super.key,
    required this.label,
    this.icon = Icons.auto_awesome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: DrGutColors.primary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: eyebrowStyle(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout blocks
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width dark olive section block — used sparingly (at most once per
/// screen) to break up the cream page, e.g. a short statement on the Landing
/// page. Text inside should use [DrGutColors.textOnDark] / [DrGutColors.onPrimary].
class DarkSectionBlock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DarkSectionBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: DrGutColors.primary,
      padding: padding,
      child: child,
    );
  }
}

/// Full-width lime (accent) callout block — one bold standout message per flow.
/// Text inside should use [DrGutColors.onAccent] (near-black).
class LimeCalloutBlock extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const LimeCalloutBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: DrGutColors.accent,
      padding: padding,
      child: child,
    );
  }
}
