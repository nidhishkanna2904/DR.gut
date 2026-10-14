import 'package:flutter/material.dart';
import '../models/diet_plan.dart';
import '../theme.dart';

class MealCard extends StatelessWidget {
  final PlanDay planDay;

  const MealCard({
    super.key,
    required this.planDay,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconChip(icon: Icons.calendar_today_outlined, size: 34),
                const SizedBox(width: 12),
                Text(
                  planDay.day,
                  style: t.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DrGutColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...planDay.meals.asMap().entries.map((entry) {
              final idx = entry.key;
              final meal = entry.value;
              final isLast = idx == planDay.meals.length - 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MealRow(meal: meal),
                  if (!isLast) const Divider(height: 24),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// A single meal row that shows nutrients on tap / hover.
class _MealRow extends StatefulWidget {
  final Meal meal;
  const _MealRow({required this.meal});

  @override
  State<_MealRow> createState() => _MealRowState();
}

class _MealRowState extends State<_MealRow> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.meal.nutrients == null) return;
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasNutrients = widget.meal.nutrients != null;

    return MouseRegion(
      cursor: hasNutrients ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal time label
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DrGutColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.meal.time,
                    style: t.labelMedium?.copyWith(
                      color: DrGutColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (hasNutrients)
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 280),
                    child: const Icon(Icons.expand_more,
                        size: 18, color: DrGutColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Food items
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                widget.meal.items,
                style: t.bodyMedium?.copyWith(
                  color: DrGutColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),

            // Why chip
            if (widget.meal.why.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: DrGutColors.surfaceBorder.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '💡 ${widget.meal.why}',
                    style: t.bodySmall?.copyWith(
                      color: DrGutColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],

            // Nutrient tap hint (shown when nutrients available but collapsed)
            if (hasNutrients && !_expanded) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '👆 Tap to see nutrients & vitamins',
                  style: t.labelSmall?.copyWith(
                    color: DrGutColors.primary.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Expanded nutrient panel
            SizeTransition(
              sizeFactor: _expand,
              child: _NutrientPanel(nutrients: widget.meal.nutrients),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nutrient detail card shown when a meal is tapped.
class _NutrientPanel extends StatelessWidget {
  final MealNutrients? nutrients;
  const _NutrientPanel({this.nutrients});

  @override
  Widget build(BuildContext context) {
    final n = nutrients;
    if (n == null) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              DrGutColors.primary.withValues(alpha: 0.07),
              DrGutColors.primary.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: DrGutColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 16, color: DrGutColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Nutritional Breakdown',
                  style: t.labelMedium?.copyWith(
                    color: DrGutColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Macro row
            Row(
              children: [
                _MacroBubble(
                  label: 'Calories',
                  value: '${n.calories} kcal',
                  color: const Color(0xFFFF8C42),
                  icon: Icons.local_fire_department_outlined,
                ),
                const SizedBox(width: 8),
                _MacroBubble(
                  label: 'Protein',
                  value: '${n.proteinG.toStringAsFixed(1)}g',
                  color: const Color(0xFF5C9EFF),
                  icon: Icons.fitness_center_outlined,
                ),
                const SizedBox(width: 8),
                _MacroBubble(
                  label: 'Carbs',
                  value: '${n.carbsG.toStringAsFixed(1)}g',
                  color: const Color(0xFFFFB800),
                  icon: Icons.grain_outlined,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MacroBubble(
                  label: 'Fat',
                  value: '${n.fatG.toStringAsFixed(1)}g',
                  color: const Color(0xFFFF6B6B),
                  icon: Icons.water_drop_outlined,
                ),
                const SizedBox(width: 8),
                _MacroBubble(
                  label: 'Fiber',
                  value: '${n.fiberG.toStringAsFixed(1)}g',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.eco_outlined,
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ),
            // Vitamins & minerals
            if (n.keyVitamins.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.science_outlined,
                      size: 15, color: DrGutColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Vitamins & Minerals: ',
                            style: t.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DrGutColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: n.keyVitamins,
                            style: t.labelSmall?.copyWith(
                              color: DrGutColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MacroBubble extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MacroBubble({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 9, color: DrGutColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
