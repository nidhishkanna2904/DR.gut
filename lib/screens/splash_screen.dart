import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _entranceController;
  late final AnimationController _rotateController;

  late final Animation<double> _scaleAnim;
  late final Animation<double> _glowAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _rotateAnim;

  Timer? _navTimer;
  bool _navigated = false;
  bool _appLoading = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateController);

    _scaleAnim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnim = Tween<double>(begin: 0.2, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _entranceController.forward();
    _initApp();
  }

  void _initApp() async {
    final appState = Provider.of<AppState>(context, listen: false);
    await appState.initialize();
    if (mounted) setState(() => _appLoading = false);

    _navTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && !_navigated) _enterApp();
    });
  }

  void _enterApp() async {
    if (_navigated) return;
    _navigated = true;
    _navTimer?.cancel();

    // Check if user is already logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    final Widget destination =
        isLoggedIn ? const HomeScreen() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _pulseController.dispose();
    _entranceController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DrGutColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient bg orbs — very subtle on the cream background
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.2,
            child: _orb(size.width * 0.75, DrGutColors.primary, 0.05),
          ),
          Positioned(
            bottom: -size.height * 0.12,
            left: -size.width * 0.15,
            child: _orb(size.width * 0.65, DrGutColors.accent, 0.06),
          ),
          Positioned(
            top: size.height * 0.38,
            left: -size.width * 0.1,
            child: _orb(size.width * 0.4, DrGutColors.primary, 0.03),
          ),

          // Slow rotating ring 1
          Center(
            child: AnimatedBuilder(
              animation: _rotateAnim,
              builder: (_, __) => Transform.rotate(
                angle: _rotateAnim.value * 3.14159 * 2,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DrGutColors.primary.withValues(alpha: 0.07),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Counter-rotating ring 2
          Center(
            child: AnimatedBuilder(
              animation: _rotateAnim,
              builder: (_, __) => Transform.rotate(
                angle: -_rotateAnim.value * 3.14159 * 2 * 0.6,
                child: Container(
                  width: 390,
                  height: 390,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DrGutColors.primary.withValues(alpha: 0.04),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 1),

                          // Big animated hero logo
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) => Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        DrGutColors.accent.withValues(
                                            alpha: _glowAnim.value * 0.18),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 238,
                                  height: 238,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: DrGutColors.surfaceBorder
                                        .withValues(alpha: _glowAnim.value * 0.20),
                                    border: Border.all(
                                      color: DrGutColors.surfaceBorder.withValues(
                                          alpha: _glowAnim.value * 0.60),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                Transform.scale(
                                  scale: _scaleAnim.value,
                                  child: Container(
                                    width: 195,
                                    height: 195,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(52),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: _glowAnim.value * 0.08),
                                          blurRadius: 40,
                                          spreadRadius: 4,
                                        ),
                                        BoxShadow(
                                          color:
                                              Colors.black.withValues(alpha: 0.10),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(52),
                                      child: Image.asset(
                                        'assets/logo_app_icon.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(52),
                                            color: DrGutColors.surface,
                                            border: Border.all(
                                              color: DrGutColors.surfaceBorder,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.eco_outlined,
                                            size: 82,
                                            color: DrGutColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Eyebrow brand badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: DrGutColors.surface,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: DrGutColors.surfaceBorder,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: DrGutColors.primary, size: 12),
                                SizedBox(width: 7),
                                Text(
                                  'AI-POWERED CLINICAL NUTRITION',
                                  style: TextStyle(
                                    color: DrGutColors.textSecondary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Dr. Gut',
                            style: t.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: DrGutColors.textPrimary,
                              fontSize: 48,
                              letterSpacing: 0.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            'Decode your gut microbiome with blood\nbiomarker intelligence & local food pairing.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium?.copyWith(
                              color: DrGutColors.textSecondary,
                              height: 1.6,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 28),

                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _featurePill(
                                  Icons.bloodtype_outlined, 'Blood Biomarkers'),
                              _featurePill(
                                  Icons.place_outlined, 'Geo-Sourced Diet'),
                              _featurePill(
                                  Icons.shield_outlined, 'Allergen Safe'),
                              _featurePill(
                                  Icons.camera_alt_outlined, 'Calorie Snap AI'),
                            ],
                          ),

                          const Spacer(flex: 2),

                          SizedBox(
                            width: double.infinity,
                            child: GradientPillButton(
                              label: 'Enter Dr. Gut',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _enterApp,
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'No account needed · Sign in only to create a diet plan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: DrGutColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          AnimatedOpacity(
                            opacity: _appLoading ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 400),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      DrGutColors.primary
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Initialising microbiome engine...',
                                  style: TextStyle(
                                    color: DrGutColors.textMuted,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double sz, Color color, double opacity) => Container(
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ]),
        ),
      );

  Widget _featurePill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: DrGutColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DrGutColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: DrGutColors.primary),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: DrGutColors.textSecondary,
              ),
            ),
          ],
        ),
      );
}
