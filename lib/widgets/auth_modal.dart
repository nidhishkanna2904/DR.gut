import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'location_card.dart';

/// Modal bottom sheet for quick login and nutrition profile setup.
/// Only prompted when the user attempts to generate a diet plan or visits profile.
class AuthModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String actionLabel;

  const AuthModal({
    super.key,
    this.title = "Let's personalize your plan",
    this.subtitle = 'Enter your details once so Dr. Gut can filter out allergens and stick to your daily budget.',
    this.actionLabel = 'Continue to Plan Creation',
  });

  /// Displays the modal and returns true if user saved/logged in successfully.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    String? actionLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DrGutColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: AuthModal(
          title: title ?? "Let's personalize your plan",
          subtitle: subtitle ?? 'Enter your details once so Dr. Gut can filter out allergens and stick to your daily budget.',
          actionLabel: actionLabel ?? 'Continue to Plan Creation',
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _manualLocationController = TextEditingController();
  LocationResult? _locationResult;
  final _diseaseController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _budgetController = TextEditingController(text: '300');
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _weightUnit = 'kg'; // 'kg' or 'lbs'

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final existing = appState.profile;
    if (existing != null) {
      _nameController.text = existing.name;
      _phoneController.text = existing.phone;
      _diseaseController.text = existing.disease;
      _allergiesController.text = existing.allergies;
      _dislikesController.text = existing.dislikes;
      _budgetController.text = existing.budget > 0 ? existing.budget.toString() : '300';
      if (existing.locationName.isNotEmpty && !existing.locationName.startsWith('Lat:')) {
        _manualLocationController.text = existing.locationName;
        _locationResult = LocationResult(
          lat: existing.lat,
          lng: existing.lng,
          placeName: existing.locationName,
        );
      }
      // Height & weight
      if (existing.heightCm != null) {
        _heightController.text = existing.heightCm!.toStringAsFixed(0);
      }
      _weightUnit = existing.weightUnit;
      if (existing.weightKg != null) {
        final display = _weightUnit == 'lbs'
            ? (existing.weightKg! * 2.20462).toStringAsFixed(1)
            : existing.weightKg!.toStringAsFixed(1);
        _weightController.text = display;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _manualLocationController.dispose();
    _diseaseController.dispose();
    _allergiesController.dispose();
    _dislikesController.dispose();
    _budgetController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  /// Convert weight display value → kg for storage.
  double? _weightToKg(String raw) {
    final val = double.tryParse(raw.trim());
    if (val == null) return null;
    return _weightUnit == 'lbs' ? val / 2.20462 : val;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final currentProfile = appState.profile;

      final budget = int.tryParse(_budgetController.text.trim()) ?? 300;
      final locationName = _locationResult?.placeName ?? _manualLocationController.text.trim();
      final heightCm = double.tryParse(_heightController.text.trim());
      final weightKg = _weightToKg(_weightController.text);

      final newProfile = UserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        locationName: locationName.isNotEmpty
            ? locationName
            : (currentProfile != null && currentProfile.locationName.isNotEmpty && !currentProfile.locationName.startsWith('Lat:')
                ? currentProfile.locationName
                : 'Thiruparankundram, Madurai, Tamil Nadu, India'),
        lat: _locationResult?.lat ?? (currentProfile?.lat != 0.0 ? currentProfile?.lat ?? 9.882 : 9.882),
        lng: _locationResult?.lng ?? (currentProfile?.lng != 0.0 ? currentProfile?.lng ?? 78.084 : 78.084),
        disease: _diseaseController.text.trim(),
        allergies: _allergiesController.text.trim(),
        dislikes: _dislikesController.text.trim(),
        budget: budget,
        planType: currentProfile?.planType ?? 'day',
        heightCm: heightCm,
        weightKg: weightKg,
        weightUnit: _weightUnit,
      );

      await appState.saveProfile(newProfile);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _fieldDeco(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: DrGutColors.surfaceBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: DrGutColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, color: DrGutColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: t.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: DrGutColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Quick Sign In & Preferences',
                            style: t.labelSmall?.copyWith(color: DrGutColors.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: DrGutColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subtitle,
                  style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Full Name
                TextFormField(
                  controller: _nameController,
                  decoration: _fieldDeco('Your Name *', Icons.badge_outlined, hint: 'e.g. Rahul Sharma'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter your name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDeco('Phone Number *', Icons.phone_outlined, hint: '10-digit mobile number'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    if (v.trim().length != 10) return 'Please enter a valid 10-digit number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Geographical Location & Mandi with Map Logo
                Text(
                  'Your Location & Local Mandi',
                  style: t.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: DrGutColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. Gut uses GPS to find fresh ingredients in your local sabzi mandi & regional markets.',
                  style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 8),
                LocationCard(
                  initialPlaceName: _locationResult?.placeName,
                  manualLocationController: _manualLocationController,
                  onLocationChanged: (loc) {
                    setState(() => _locationResult = loc);
                  },
                ),
                const SizedBox(height: 14),

                // Budget
                TextFormField(
                  controller: _budgetController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDeco('Daily Diet Budget (₹) *', Icons.currency_rupee, hint: 'e.g. 250 - 400'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Budget is required';
                    final num = int.tryParse(v.trim());
                    if (num == null || num <= 0) return 'Please enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Height & Weight row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Height – cm only
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: _fieldDeco('Height (cm)', Icons.height, hint: 'e.g. 170'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null; // optional
                          final val = double.tryParse(v.trim());
                          if (val == null || val < 50 || val > 280) return 'Enter 50–280 cm';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Weight with kg / lbs toggle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            decoration: InputDecoration(
                              labelText: 'Weight',
                              hintText: _weightUnit == 'kg' ? 'e.g. 65' : 'e.g. 143',
                              prefixIcon: const Icon(Icons.monitor_weight_outlined, size: 20),
                              suffixText: _weightUnit,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null; // optional
                              final val = double.tryParse(v.trim());
                              if (val == null) return 'Invalid';
                              final kg = _weightUnit == 'lbs' ? val / 2.20462 : val;
                              if (kg < 20 || kg > 300) return 'Out of range';
                              return null;
                            },
                          ),
                          const SizedBox(height: 6),
                          // Unit toggle chips
                          Row(
                            children: [
                              _UnitChip(
                                label: 'kg',
                                selected: _weightUnit == 'kg',
                                onTap: () {
                                  if (_weightUnit == 'lbs') {
                                    final val = double.tryParse(_weightController.text.trim());
                                    if (val != null) {
                                      _weightController.text =
                                          (val / 2.20462).toStringAsFixed(1);
                                    }
                                  }
                                  setState(() => _weightUnit = 'kg');
                                },
                              ),
                              const SizedBox(width: 8),
                              _UnitChip(
                                label: 'lbs',
                                selected: _weightUnit == 'lbs',
                                onTap: () {
                                  if (_weightUnit == 'kg') {
                                    final val = double.tryParse(_weightController.text.trim());
                                    if (val != null) {
                                      _weightController.text =
                                          (val * 2.20462).toStringAsFixed(1);
                                    }
                                  }
                                  setState(() => _weightUnit = 'lbs');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Food Allergies
                TextFormField(
                  controller: _allergiesController,
                  decoration: _fieldDeco(
                    'Food Allergies (optional)',
                    Icons.warning_amber_outlined,
                    hint: 'e.g. Peanuts, Dairy, Gluten, Shellfish',
                  ),
                ),
                const SizedBox(height: 14),

                // Disliked Foods
                TextFormField(
                  controller: _dislikesController,
                  decoration: _fieldDeco(
                    'Disliked Foods (optional)',
                    Icons.thumb_down_alt_outlined,
                    hint: 'e.g. Bitter gourd, Mushrooms, Eggplant',
                  ),
                ),
                const SizedBox(height: 14),

                // Medical conditions
                TextFormField(
                  controller: _diseaseController,
                  decoration: _fieldDeco(
                    'Health Conditions (optional)',
                    Icons.medical_information_outlined,
                    hint: 'e.g. Thyroid, Diabetes, Fatty Liver, IBS',
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                GradientPillButton(
                  label: widget.actionLabel,
                  icon: Icons.arrow_forward,
                  loading: _isSaving,
                  onPressed: _submit,
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '🔒 Your medical and personal data is kept strictly confidential.',
                    style: t.labelSmall?.copyWith(color: DrGutColors.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small toggle chip for unit selection (kg / lbs).
class _UnitChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? DrGutColors.primary
              : DrGutColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? DrGutColors.primary
                : DrGutColors.surfaceBorder,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : DrGutColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
