import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/calorie_estimate.dart';
import '../services/api_service.dart';
import '../theme.dart';

class CalorieSnapScreen extends StatefulWidget {
  const CalorieSnapScreen({super.key});

  @override
  State<CalorieSnapScreen> createState() => _CalorieSnapScreenState();
}

class _CalorieSnapScreenState extends State<CalorieSnapScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoName;
  bool _isAnalyzing = false;
  CalorieEstimate? _result;
  String? _errorMessage;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? photo;
      if (source == ImageSource.camera) {
        photo = await _picker.pickImage(
            source: ImageSource.camera, imageQuality: 85);
      } else {
        photo = await _picker.pickImage(
            source: ImageSource.gallery, imageQuality: 90);
      }

      if (photo == null) return;
      final bytes = await photo.readAsBytes();

      setState(() {
        _photoBytes = bytes;
        _photoName = photo!.name.isNotEmpty ? photo.name : 'food_photo.jpg';
        _result = null;
        _errorMessage = null;
      });

      _analyzePhoto();
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e';
      });
    }
  }

  Future<void> _analyzePhoto() async {
    if (_photoBytes == null || _photoName == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ApiService.estimateCalories(_photoBytes!, _photoName!);
      if (mounted) {
        setState(() {
          _result = result;
          _isAnalyzing = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Analysis failed: $e';
          _isAnalyzing = false;
        });
      }
    }
  }

  void _reset() {
    setState(() {
      _photoBytes = null;
      _photoName = null;
      _result = null;
      _errorMessage = null;
      _isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      children: [
        // Title
        Text('Calorie Snap 📸',
            style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Photograph your meal and AI will estimate calories & macros instantly',
          style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Photo area
        if (_photoBytes == null) ...[
          _buildCaptureCard(t),
        ] else ...[
          // Show the captured photo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Image.memory(
                  _photoBytes!,
                  width: double.infinity,
                  height: 240,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _reset,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                if (_isAnalyzing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                DrGutColors.primary.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Identifying food items…',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Retake options
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: DrGutColors.surfaceBorder),
                  ),
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined,
                      size: 18, color: DrGutColors.primary),
                  label: const Text('Retake',
                      style: TextStyle(
                          color: DrGutColors.textPrimary, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: DrGutColors.surfaceBorder),
                  ),
                  onPressed: _isAnalyzing
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined,
                      size: 18, color: DrGutColors.primary),
                  label: const Text('Gallery',
                      style: TextStyle(
                          color: DrGutColors.textPrimary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],

        // Error state
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DrGutColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: DrGutColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: DrGutColors.error, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(color: DrGutColors.error, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Loading shimmer placeholder
        if (_isAnalyzing && _result == null) ...[
          const SizedBox(height: 20),
          _buildShimmerCards(),
        ],

        // Results
        if (_result != null) ...[
          const SizedBox(height: 20),
          _buildResultsSection(t, _result!),
        ],

        // Separator and info when idle
        if (_photoBytes == null && _result == null) ...[
          const SizedBox(height: 28),
          _buildHowItWorksCard(t),
        ],
      ],
    );
  }

  // ─── Capture Card ───
  Widget _buildCaptureCard(TextTheme t) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: DrGutColors.primary.withValues(alpha: 0.4), width: 1.5),
        gradient: const LinearGradient(
          colors: [Color(0xFF14241B), Color(0xFF101915)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: DrGutColors.primary.withValues(alpha: 0.15),
              border:
                  Border.all(color: DrGutColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.camera_alt_outlined,
                size: 44, color: DrGutColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Snap Your Meal',
            style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Take a quick photo and our AI nutritionist will\ninstantly break down calories & macros',
            textAlign: TextAlign.center,
            style: t.bodySmall
                ?.copyWith(color: DrGutColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GradientPillButton(
                  label: 'Use Camera',
                  icon: Icons.camera_alt,
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              side: const BorderSide(color: DrGutColors.surfaceBorder),
            ),
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined,
                size: 18, color: DrGutColors.primary),
            label: const Text('Choose from Gallery',
                style: TextStyle(
                    color: DrGutColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ─── Shimmer Loading Cards ───
  Widget _buildShimmerCards() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final shimmerValue = _shimmerController.value;
        return Column(
          children: List.generate(3, (i) {
            final alpha = (sin((shimmerValue + i * 0.3) * 3.14159) * 0.3 + 0.5)
                .clamp(0.2, 0.8);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 56,
              decoration: BoxDecoration(
                color: DrGutColors.surface.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: DrGutColors.surfaceBorder.withValues(alpha: alpha)),
              ),
            );
          }),
        );
      },
    );
  }

  // ─── Results Section ───
  Widget _buildResultsSection(TextTheme t, CalorieEstimate result) {
    // Determine ring color by calorie count
    Color calorieColor = DrGutColors.primary;
    String calorieLabel = 'Balanced Meal';
    if (result.totalCalories > 800) {
      calorieColor = const Color(0xFFFF6B6B);
      calorieLabel = 'High Calorie Meal';
    } else if (result.totalCalories > 500) {
      calorieColor = const Color(0xFFFFB800);
      calorieLabel = 'Moderate Calories';
    } else if (result.totalCalories < 200) {
      calorieColor = DrGutColors.textSecondary;
      calorieLabel = 'Light Snack';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grand Calorie Display Card
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF14241B), Color(0xFF0F1612)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: calorieColor.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: calorieColor.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Confidence badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _confidenceColor(result.confidence)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _confidenceColor(result.confidence)
                          .withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified,
                        size: 14, color: _confidenceColor(result.confidence)),
                    const SizedBox(width: 4),
                    Text(
                      '${result.confidence.toUpperCase()} CONFIDENCE',
                      style: TextStyle(
                        color: _confidenceColor(result.confidence),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Big calorie number
              Text(
                '${result.totalCalories}',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: calorieColor,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text('kcal estimated',
                  style:
                      t.bodyMedium?.copyWith(color: DrGutColors.textSecondary)),
              const SizedBox(height: 4),
              Text(calorieLabel,
                  style: TextStyle(
                      color: calorieColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              const SizedBox(height: 20),

              // Macro bars
              Row(
                children: [
                  _macroColumn(
                      'Protein',
                      '${result.proteinG.toStringAsFixed(1)}g',
                      const Color(0xFF5C9EFF)),
                  _macroColumn('Carbs', '${result.carbsG.toStringAsFixed(1)}g',
                      const Color(0xFFFFB800)),
                  _macroColumn('Fat', '${result.fatG.toStringAsFixed(1)}g',
                      const Color(0xFFFF6B6B)),
                  _macroColumn('Fiber', '${result.fiberG.toStringAsFixed(1)}g',
                      DrGutColors.primary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Food Items Breakdown
        Text('Identified Food Items',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...result.foodItems.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: DrGutColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DrGutColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const IconChip(icon: Icons.restaurant_outlined, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(item.portion,
                            style: const TextStyle(
                                fontSize: 12,
                                color: DrGutColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DrGutColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.calories} kcal',
                      style: const TextStyle(
                          color: DrGutColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),

        // Meal Summary
        if (result.mealSummary.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined,
                          size: 18, color: DrGutColors.primary),
                      const SizedBox(width: 8),
                      Text('Meal Analysis',
                          style: t.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.mealSummary,
                    style: const TextStyle(
                        fontSize: 13,
                        color: DrGutColors.textSecondary,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],

        // Health Tip
        if (result.healthTip.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DrGutColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: DrGutColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 18, color: DrGutColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nutrition Tip',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: DrGutColors.primary)),
                      const SizedBox(height: 4),
                      Text(
                        result.healthTip,
                        style: const TextStyle(
                            fontSize: 12,
                            color: DrGutColors.textPrimary,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Scan another
        GradientPillButton(
          label: 'Snap Another Meal',
          icon: Icons.camera_alt,
          onPressed: _reset,
        ),
      ],
    );
  }

  Widget _macroColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(value,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 10)),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: DrGutColors.textSecondary)),
        ],
      ),
    );
  }

  Color _confidenceColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return DrGutColors.primary;
      case 'medium':
        return const Color(0xFFFFB800);
      case 'low':
        return DrGutColors.error;
      default:
        return DrGutColors.textSecondary;
    }
  }

  // ─── How It Works Card ───
  Widget _buildHowItWorksCard(TextTheme t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconChip(icon: Icons.auto_awesome),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How Calorie Snap Works',
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Powered by AI vision analysis',
                          style: t.bodySmall
                              ?.copyWith(color: DrGutColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _howStep(
                '1',
                'Take a clear, well-lit photo of your meal from above',
                Icons.camera_alt_outlined),
            const SizedBox(height: 12),
            _howStep(
                '2',
                'AI identifies each food item and estimates portion sizes',
                Icons.search_outlined),
            const SizedBox(height: 12),
            _howStep(
                '3',
                'Get instant calorie count, protein, carbs, fat & fiber breakdown',
                Icons.bar_chart_outlined),
            const SizedBox(height: 12),
            _howStep(
                '4',
                'Receive a personalized health tip to optimize your plate',
                Icons.lightbulb_outline),
          ],
        ),
      ),
    );
  }

  Widget _howStep(String num, String desc, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: DrGutColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(num,
              style: const TextStyle(
                  color: DrGutColors.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 16, color: DrGutColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(desc,
              style: const TextStyle(
                  fontSize: 13, color: DrGutColors.textSecondary, height: 1.3)),
        ),
      ],
    );
  }
}
