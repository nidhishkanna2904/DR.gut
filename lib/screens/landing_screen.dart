import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import 'profile_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _onGetStarted(BuildContext context) async {
    await StorageService.setSeenLanding(true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DrGutColors.background,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Hero section ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo — clean squircle, no glow on light background
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: DrGutColors.surfaceBorder),
                      color: DrGutColors.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/logo_app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.eco_outlined,
                          size: 48,
                          color: DrGutColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Eyebrow tag
                  const EyebrowTag(
                      label: 'Personalised Nutrition, from your own report'),
                  const SizedBox(height: 14),

                  // Display serif headline — two-toned, two lines
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Your diet plan,\n',
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: DrGutColors.textPrimary,
                            height: 1.15,
                          ),
                        ),
                        TextSpan(
                          text: 'built around you.',
                          style: displaySerifStyle(
                            fontSize: 30,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload your blood report and share your location\n— Dr. Gut builds a diet plan using local, seasonal foods.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: DrGutColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Feature Highlights Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _featureRow(
                            icon: Icons.biotech_outlined,
                            title: 'Lab Report Precision',
                            subtitle:
                                'Extracts biomarker deficiencies directly from your blood test',
                          ),
                          const Divider(height: 24),
                          _featureRow(
                            icon: Icons.my_location_outlined,
                            title: 'Hyper-Local Ingredients',
                            subtitle:
                                'Recommends fresh items sold in your local area and season',
                          ),
                          const Divider(height: 24),
                          _featureRow(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Budget & Allergy Guard',
                            subtitle:
                                'Strictly stays within budget and excludes all allergens',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),

            // ── Lime callout block — full-width, edge-to-edge ─────
            LimeCalloutBlock(
              child: Text(
                'Not a diet fad.\nA plan built from your own numbers.',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DrGutColors.onAccent,
                  height: 1.3,
                ),
              ),
            ),

            // ── CTA buttons ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                children: [
                  GradientPillButton(
                    label: 'Get Started',
                    icon: Icons.arrow_forward,
                    onPressed: () => _onGetStarted(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinePillButton(
                    label: 'Learn more',
                    onPressed: () {
                      // Scrolls or shows features — no-op for now
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconChip(icon: icon, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: DrGutColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: DrGutColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
