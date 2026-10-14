import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/auth_modal.dart';
import '../widgets/location_card.dart';
import '../widgets/report_upload_tile.dart';
import 'loading_screen.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _manualLocationController = TextEditingController();
  LocationResult? _locationResult;
  String _planType = 'day'; // 'day' or 'week'

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.profile;
    if (user != null && user.locationName.isNotEmpty) {
      if (!user.locationName.startsWith('Lat:')) {
        _manualLocationController.text = user.locationName;
        _locationResult = LocationResult(
          lat: user.lat,
          lng: user.lng,
          placeName: user.locationName,
        );
      } else {
        final lat = user.lat != 0.0 ? user.lat : 9.882;
        final lng = user.lng != 0.0 ? user.lng : 78.084;
        LocationService.reverseGeocode(lat, lng).then((res) {
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

  @override
  void dispose() {
    _manualLocationController.dispose();
    super.dispose();
  }

  void _onEditProfile() async {
    final updated = await AuthModal.show(
      context,
      title: 'Update Profile Details',
      actionLabel: 'Save Changes',
    );
    if (updated && mounted) {
      setState(() {});
    }
  }

  void _onSubmit() {
    final appState = Provider.of<AppState>(context, listen: false);
    final user = appState.profile;

    if (user == null || user.name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in or set up your profile first.'),
          backgroundColor: DrGutColors.error,
        ),
      );
      _onEditProfile();
      return;
    }

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

    if (appState.selectedReport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your blood report (PDF, JPG, or PNG).'),
          backgroundColor: DrGutColors.error,
        ),
      );
      return;
    }

    final profile = user.copyWith(
      locationName: locationName,
      lat: _locationResult?.lat ?? 0.0,
      lng: _locationResult?.lng ?? 0.0,
      planType: _planType,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoadingScreen(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final appState = Provider.of<AppState>(context);
    final user = appState.profile;

    return Scaffold(
      backgroundColor: DrGutColors.background,
      appBar: AppBar(
        title: const Text('Create Diet Plan'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                const EyebrowTag(label: 'Clinical Nutrition Flow'),
                const SizedBox(height: 8),
                Text(
                  "Let's build your plan.",
                  style: displaySerifStyle(fontSize: 28),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tailoring local ingredients to your biomarker panel & daily budget',
                  style: t.labelMedium?.copyWith(color: DrGutColors.textSecondary),
                ),
                const SizedBox(height: 18),

                // Profile header banner
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: DrGutColors.primary.withValues(alpha: 0.18),
                          child: Text(
                            user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                            style: const TextStyle(color: DrGutColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null && user.name.isNotEmpty ? user.name : 'Guest User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user != null
                                    ? '₹${user.budget}/day budget • ${user.allergies.isNotEmpty ? user.allergies : "No allergies"}'
                                    : 'Profile not configured',
                                style: const TextStyle(fontSize: 12, color: DrGutColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _onEditProfile,
                          icon: const Icon(Icons.edit_outlined, size: 16, color: DrGutColors.primary),
                          label: const Text('Edit', style: TextStyle(color: DrGutColors.primary, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Step 1: Location & Local Market
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: DrGutColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('1', style: TextStyle(color: DrGutColors.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Your Geographical Location',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dr. Gut uses GPS to find ingredients sold in your local sabzi mandi & regional markets.',
                  style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
                ),
                const SizedBox(height: 12),
                LocationCard(
                  initialPlaceName: _locationResult?.placeName,
                  manualLocationController: _manualLocationController,
                  onLocationChanged: (loc) {
                    setState(() => _locationResult = loc);
                  },
                ),
                const SizedBox(height: 24),

                // Step 2: Plan Length
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: DrGutColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('2', style: TextStyle(color: DrGutColors.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Plan Duration',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: DrGutColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: DrGutColors.surfaceBorder),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _segmentItem('1 Day Kickstart Plan', 'day'),
                      _segmentItem('7 Days Gut Reset Plan', 'week'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Step 3: Blood Report Upload
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: DrGutColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('3', style: TextStyle(color: DrGutColors.onPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Attach Blood Lab Report',
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Upload a CBC, Vitamin profile, Thyroid, or comprehensive panel (PDF or Photo).',
                  style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
                ),
                const SizedBox(height: 12),
                ReportUploadTile(
                  selectedReport: appState.selectedReport,
                  onReportSelected: (report) => appState.setSelectedReport(report),
                ),
                const SizedBox(height: 32),

                // Submit Button
                GradientPillButton(
                  label: 'Analyze Report & Generate Plan',
                  icon: Icons.auto_awesome,
                  onPressed: _onSubmit,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '🔒 Report is processed strictly in memory and never stored on disk.',
                    style: t.labelSmall?.copyWith(color: DrGutColors.textMuted),
                  ),
                ),
              ],
            ),
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
          curve: Curves.easeInOut,
          height: 44,
          decoration: BoxDecoration(
            color: selected ? DrGutColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? DrGutColors.onPrimary : DrGutColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
