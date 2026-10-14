import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import 'plan_screen.dart';

class LoadingScreen extends StatefulWidget {
  final UserProfile profile;

  const LoadingScreen({super.key, required this.profile});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  Timer? _statusTimer;
  int _statusIndex = 0;
  bool _hasStarted = false;

  static const List<String> _statusMessages = [
    'Reading your report…',
    'Checking nutrient levels & out-of-range markers…',
    'Finding foods available near your location…',
    'Building your personalized diet plan…',
  ];

  @override
  void initState() {
    super.initState();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasStarted) {
        _hasStarted = true;
        _startAnalysis();
      }
    });
  }

  Future<void> _startAnalysis() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final plan = await appState.submitDietPlanRequest(widget.profile);

    if (!mounted) return;

    if (plan != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, __, ___) => PlanScreen(plan: plan),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final appState = Provider.of<AppState>(context);
    final hasError = appState.status == AppStatus.error;

    return PopScope(
      canPop: !appState.isLoading,
      child: Scaffold(
        backgroundColor: DrGutColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: hasError
                  ? _buildErrorView(t, appState)
                  : _buildLoadingView(t),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(TextTheme t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Simple primary spinner — no glow (per light theme spec)
        const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: DrGutColors.primary,
          ),
        ),
        const SizedBox(height: 36),

        Text(
          'Analyzing Biomarkers',
          style: displaySerifStyle(fontSize: 28),
        ),
        const SizedBox(height: 12),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _statusMessages[_statusIndex],
            key: ValueKey<int>(_statusIndex),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(
              color: DrGutColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 48),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: DrGutColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: DrGutColors.surfaceBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: DrGutColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI Model: Claude Sonnet 5',
                style: t.bodySmall?.copyWith(color: DrGutColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(TextTheme t, AppState appState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: DrGutColors.error.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline,
            size: 44,
            color: DrGutColors.error,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Analysis Failed',
          style: t.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: DrGutColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          appState.errorMessage ?? 'An error occurred while analyzing your report. Please check your network and retry.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(
            color: DrGutColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),
        GradientPillButton(
          label: 'Try Again',
          icon: Icons.refresh,
          onPressed: () {
            appState.clearError();
            _startAnalysis();
          },
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            appState.clearError();
            Navigator.pop(context);
          },
          child: const Text(
            'Back to Form',
            style: TextStyle(color: DrGutColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
