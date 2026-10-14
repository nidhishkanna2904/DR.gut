import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/diet_plan.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/meal_card.dart';
import 'diet_bot_screen.dart';
import 'home_screen.dart';

class PlanScreen extends StatelessWidget {
  final DietPlan? plan;

  const PlanScreen({super.key, this.plan});

  void _sharePlan(BuildContext context, DietPlan activePlan) async {
    final text = activePlan.toShareableText();
    try {
      await Share.share(text, subject: 'My Dr. Gut Diet Plan');
    } catch (_) {
      // Fallback to Clipboard copy if system share fails
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan copied to clipboard!'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final appState = Provider.of<AppState>(context);
    final activePlan = plan ?? appState.currentPlan ?? appState.lastSavedPlan;

    if (activePlan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Plan')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 54, color: DrGutColors.textMuted),
              const SizedBox(height: 16),
              Text('No Diet Plan Found', style: t.titleMedium),
              const SizedBox(height: 8),
              const Text('Please submit your report first.', style: TextStyle(color: DrGutColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Personalized Plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Plan',
            onPressed: () => _sharePlan(context, activePlan),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Go to Home',
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      // ── Dr. Gut AI Chat Bot FAB ──────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'diet_bot_fab',
        backgroundColor: DrGutColors.primary,
        foregroundColor: DrGutColors.accent,
        elevation: 6,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text(
          'Ask Dr. Gut',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DietBotScreen(plan: activePlan),
            ),
          );
        },
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
          children: [
            // Overview Section
            const EyebrowTag(label: 'Overview'),
            const SizedBox(height: 6),
            Text('Clinical Overview', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  activePlan.summary,
                  style: t.bodyMedium?.copyWith(
                    color: DrGutColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Body Analysis Table (MUST show before diet plan) ─────────────
            if (activePlan.bodyAnalysis.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.science_outlined, size: 18, color: DrGutColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Body Biomarker Analysis',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'A full picture of every marker found in your blood report — what\'s perfect, what\'s low, and what needs attention.',
                style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _BodyAnalysisTable(markers: activePlan.bodyAnalysis),
              const SizedBox(height: 24),
            ],

            // Deficiencies / Findings Section
            if (activePlan.deficiencies.isNotEmpty) ...[
              Text(
                'Biomarker Findings from Report',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              ...activePlan.deficiencies.map((d) => _buildFindingCard(context, d)),
              const SizedBox(height: 24),
            ],

            // Daily Meal Plans
            Text(
              'Recommended Meal Schedule',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              '💡 Tap any meal to reveal full nutrients, vitamins & minerals',
              style: t.labelSmall?.copyWith(
                color: DrGutColors.primary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            ...activePlan.days.map((day) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: MealCard(planDay: day),
                )),
            const SizedBox(height: 12),

            // Local Tips Card
            if (activePlan.localNotes.isNotEmpty) ...[
              Text(
                'Local & Seasonal Guidance',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const IconChip(icon: Icons.storefront_outlined, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          activePlan.localNotes,
                          style: t.bodyMedium?.copyWith(
                            color: DrGutColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Pinned Medical Disclaimer
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: DrGutColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: DrGutColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: DrGutColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'General dietary guidance, not medical advice. Consult a doctor or registered dietitian.',
                        style: t.bodySmall?.copyWith(
                          color: DrGutColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom CTA to Return or Export
            GradientPillButton(
              label: 'Share / Copy Plan',
              icon: Icons.share,
              onPressed: () => _sharePlan(context, activePlan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFindingCard(BuildContext context, Deficiency deficiency) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const IconChip(
                icon: Icons.bloodtype_outlined,
                color: DrGutColors.error,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deficiency.name,
                      style: t.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: DrGutColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deficiency.finding,
                      style: t.bodySmall?.copyWith(
                        color: DrGutColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body Analysis Table ────────────────────────────────────────────────────────
class _BodyAnalysisTable extends StatelessWidget {
  final List<BodyMarker> markers;
  const _BodyAnalysisTable({required this.markers});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'deficient':
        return const Color(0xFFFF4444);
      case 'low':
        return const Color(0xFFFF8C42);
      case 'normal':
      case 'optimal':
        return const Color(0xFF4CAF50);
      case 'elevated':
        return const Color(0xFFFFB800);
      case 'high':
        return const Color(0xFFFF4444);
      default:
        return DrGutColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: DrGutColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DrGutColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row
          Container(
            color: DrGutColors.primary.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Marker',
                      style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DrGutColors.primary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Your Value',
                      style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DrGutColors.primary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Normal Range',
                      style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DrGutColors.primary)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Status',
                      style: t.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DrGutColors.primary)),
                ),
              ],
            ),
          ),
          // Data rows
          ...markers.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final statusColor = _statusColor(m.status);
            final isEven = i.isEven;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: isEven
                      ? Colors.transparent
                      : DrGutColors.primary.withValues(alpha: 0.03),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Marker name with emoji
                      Expanded(
                        flex: 3,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                m.marker,
                                style: t.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: DrGutColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Value
                      Expanded(
                        flex: 2,
                        child: Text(
                          m.value,
                          style: t.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Normal range
                      Expanded(
                        flex: 2,
                        child: Text(
                          m.normalRange,
                          style: t.labelSmall?.copyWith(
                            color: DrGutColors.textMuted,
                          ),
                        ),
                      ),
                      // Status badge
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            m.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Dietary tip row
                if (m.dietaryTip.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: isEven
                        ? Colors.transparent
                        : DrGutColors.primary.withValues(alpha: 0.03),
                    padding: const EdgeInsets.only(
                        left: 14, right: 14, bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(width: 22),
                        const Icon(Icons.lightbulb_outline,
                            size: 11, color: DrGutColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            m.dietaryTip,
                            style: t.labelSmall?.copyWith(
                              color: DrGutColors.textMuted,
                              fontStyle: FontStyle.italic,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (i < markers.length - 1)
                  const Divider(height: 1, indent: 14, endIndent: 14),
              ],
            );
          }),
        ],
      ),
    );
  }
}
