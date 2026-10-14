import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/location_card.dart';
import '../widgets/report_upload_tile.dart';
import 'loading_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _dislikesController = TextEditingController();
  final _budgetController = TextEditingController(text: '300');
  final _manualLocationController = TextEditingController();

  LocationResult? _locationResult;
  String _planType = 'day'; // 'day' or 'week'

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() {
    final appState = Provider.of<AppState>(context, listen: false);
    final saved = appState.profile;
    if (saved != null) {
      _nameController.text = saved.name;
      _phoneController.text = saved.phone;
      _diseaseController.text = saved.disease;
      _allergiesController.text = saved.allergies;
      _dislikesController.text = saved.dislikes;
      _budgetController.text = saved.budget > 0 ? saved.budget.toString() : '300';
      _planType = saved.planType;
      if (saved.locationName.isNotEmpty) {
        if (!saved.locationName.startsWith('Lat:')) {
          _manualLocationController.text = saved.locationName;
          _locationResult = LocationResult(
            lat: saved.lat,
            lng: saved.lng,
            placeName: saved.locationName,
          );
        } else if (saved.lat != 0.0 && saved.lng != 0.0) {
          LocationService.reverseGeocode(saved.lat, saved.lng).then((res) {
            if (mounted) {
              setState(() {
                _locationResult = res;
                _manualLocationController.text = res.placeName;
              });
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _diseaseController.dispose();
    _allergiesController.dispose();
    _dislikesController.dispose();
    _budgetController.dispose();
    _manualLocationController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final appState = Provider.of<AppState>(context, listen: false);

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate location
    final locationName = _locationResult?.placeName ?? _manualLocationController.text.trim();
    if (locationName.isEmpty || locationName == 'Location unavailable') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allow GPS location or enter your location manually.'),
          backgroundColor: DrGutColors.error,
        ),
      );
      return;
    }

    // Validate report upload
    if (appState.selectedReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your blood report (PDF, JPG, or PNG).'),
          backgroundColor: DrGutColors.error,
        ),
      );
      return;
    }

    final budget = int.tryParse(_budgetController.text.trim()) ?? 300;

    final profile = UserProfile(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      locationName: locationName,
      lat: _locationResult?.lat ?? 0.0,
      lng: _locationResult?.lng ?? 0.0,
      disease: _diseaseController.text.trim(),
      allergies: _allergiesController.text.trim(),
      dislikes: _dislikesController.text.trim(),
      budget: budget,
      planType: _planType,
    );

    // Navigate to loading screen which triggers the API
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(profile: profile),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dr. Gut'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              const EyebrowTag(label: 'Your Profile'),
              const SizedBox(height: 8),
              Text(
                "Let's build your plan.",
                style: displaySerifStyle(fontSize: 30),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us a bit about you and your nutrition goals',
                style: t.labelMedium?.copyWith(color: DrGutColors.textSecondary),
              ),
              const SizedBox(height: 24),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration('Full Name', Icons.person_outline),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Full name is required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Phone Number (10 digits)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration('Phone Number', Icons.call_outlined, hint: '10-digit mobile number'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number is required';
                  if (v.trim().length != 10) return 'Please enter a valid 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Location Card (Auto-GPS + Manual Fallback)
              LocationCard(
                initialPlaceName: _locationResult?.placeName,
                manualLocationController: _manualLocationController,
                onLocationChanged: (loc) {
                  setState(() => _locationResult = loc);
                },
              ),
              const SizedBox(height: 14),

              // Disease / Medical conditions (Optional)
              TextFormField(
                controller: _diseaseController,
                decoration: _fieldDecoration('Known conditions / disease (optional)', Icons.medical_information_outlined, hint: 'e.g. Thyroid, Diabetes, Fatty Liver'),
              ),
              const SizedBox(height: 14),

              // Allergies (Optional)
              TextFormField(
                controller: _allergiesController,
                decoration: _fieldDecoration('Any food allergies (optional)', Icons.warning_amber_outlined, hint: 'e.g. Peanuts, Dairy, Gluten'),
              ),
              const SizedBox(height: 14),

              // Disliked foods (Optional)
              TextFormField(
                controller: _dislikesController,
                decoration: _fieldDecoration('Foods you dislike (optional)', Icons.thumb_down_alt_outlined, hint: 'e.g. Bitter gourd, Mushrooms'),
              ),
              const SizedBox(height: 14),

              // Daily budget in INR
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration('Budget per day (₹)', Icons.currency_rupee, hint: 'e.g. 250'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Budget is required';
                  final b = int.tryParse(v.trim());
                  if (b == null || b <= 0) return 'Please enter a valid amount greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Plan Length Segmented Toggle (1-day vs 7-days)
              Text(
                'Plan Duration',
                style: t.labelMedium?.copyWith(color: DrGutColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: DrGutColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: DrGutColors.surfaceBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _segmentItem('1 Day Plan', 'day'),
                    _segmentItem('7 Days Plan', 'week'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Report Upload Tile
              ReportUploadTile(
                selectedReport: appState.selectedReport,
                onReportSelected: (report) {
                  appState.setSelectedReport(report);
                },
              ),
              const SizedBox(height: 28),

              // Primary Gradient Pill CTA Button
              GradientPillButton(
                label: 'Analyze & create my diet plan',
                icon: Icons.auto_awesome,
                onPressed: _onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentItem(String label, String value) {
    final selected = _planType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _planType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? DrGutColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? DrGutColors.onPrimary : DrGutColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
