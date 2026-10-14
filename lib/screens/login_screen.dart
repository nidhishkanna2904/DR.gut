import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Mode toggle: false = Sign In, true = Create Account
  bool _isSignUp = false;

  // Controllers for Sign In
  final _signInIdentifierController = TextEditingController();
  final _signInFormKey = GlobalKey<FormState>();

  // Controllers for Create Account
  final _signUpNameController = TextEditingController();
  final _signUpPhoneController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpFormKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _accountNotFoundIdentifier;

  // Animations
  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideLogoAnim;
  late final Animation<Offset> _slideFormAnim;
  late final Animation<Offset> _slideGoogleAnim;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideLogoAnim = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _slideFormAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
    ));

    _slideGoogleAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _signInIdentifierController.dispose();
    _signUpNameController.dispose();
    _signUpPhoneController.dispose();
    _signUpEmailController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  void _switchToSignUp([String? prefilled]) {
    setState(() {
      _isSignUp = true;
      _accountNotFoundIdentifier = null;
      if (prefilled != null && prefilled.trim().isNotEmpty) {
        final val = prefilled.trim();
        if (val.contains('@')) {
          _signUpEmailController.text = val;
        } else {
          _signUpPhoneController.text = val;
        }
      }
    });
  }

  void _switchToSignIn() {
    setState(() {
      _isSignUp = false;
      _accountNotFoundIdentifier = null;
    });
  }

  // ── Handle Sign In with Database ─────────────────────────────────────────
  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    final identifier = _signInIdentifierController.text.trim();
    setState(() {
      _isLoading = true;
      _accountNotFoundIdentifier = null;
    });

    try {
      final user = await AuthService.loginWithDatabase(identifier);
      if (!mounted) return;

      final appState = Provider.of<AppState>(context, listen: false);
      await appState.syncUserSession(user.name, user.phone);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user.name}!'),
          backgroundColor: DrGutColors.primary,
        ),
      );

      _navigateToHome();
    } on AccountNotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _accountNotFoundIdentifier = e.identifier;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No account found in database for "$identifier".'),
          backgroundColor: DrGutColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: DrGutColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Handle Create Account in Database ─────────────────────────────────────
  Future<void> _handleCreateAccount() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    final name = _signUpNameController.text.trim();
    final phone = _signUpPhoneController.text.trim();
    final email = _signUpEmailController.text.trim();

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.registerAccount(
        name: name,
        phone: phone,
        email: email.isNotEmpty ? email : null,
      );

      if (!mounted) return;

      final appState = Provider.of<AppState>(context, listen: false);
      await appState.syncUserSession(user.name, user.phone);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created in database! Welcome, ${user.name}.'),
          backgroundColor: DrGutColors.primary,
        ),
      );

      _navigateToHome();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
          backgroundColor: DrGutColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Handle Google Sign-In ────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (!mounted) return;

      if (user != null) {
        if (user.phone.isNotEmpty) {
          // Existing database user
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.syncUserSession(user.name, user.phone);
          _navigateToHome();
          return;
        } else {
          // Google authenticated, but needs phone number to complete account in DB
          _signUpNameController.text = user.name;
          _signUpEmailController.text = user.email ?? '';
          _switchToSignUp();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your phone number to complete your registration.'),
              backgroundColor: DrGutColors.primary,
            ),
          );
        }
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: DrGutColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background orbs
          Positioned(
            top: -size.height * 0.12,
            right: -size.width * 0.18,
            child: _orb(size.width * 0.7, DrGutColors.primary, 0.05),
          ),
          Positioned(
            bottom: -size.height * 0.1,
            left: -size.width * 0.12,
            child: _orb(size.width * 0.6, DrGutColors.accent, 0.07),
          ),

          // Main scrollable content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),

                        // ── Logo + Brand ──────────────────────────
                        SlideTransition(
                          position: _slideLogoAnim,
                          child: Column(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: DrGutColors.surfaceBorder),
                                  color: DrGutColors.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Image.asset(
                                    'assets/logo_app_icon.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.eco_outlined,
                                      size: 44,
                                      color: DrGutColors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Dr. Gut',
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: DrGutColors.textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Clinical precision nutrition from your blood report',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: DrGutColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Segmented Mode Selector (Sign In vs Create Account) ──
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: DrGutColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: DrGutColors.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _switchToSignIn,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isSignUp ? DrGutColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: !_isSignUp ? DrGutColors.onPrimary : DrGutColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _switchToSignUp(),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isSignUp ? DrGutColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Create Account',
                                      style: TextStyle(
                                        color: _isSignUp ? DrGutColors.onPrimary : DrGutColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── "No Account Found" Alert Card (When DB returns 404) ──
                        if (_accountNotFoundIdentifier != null && !_isSignUp)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF9E6), // warm soft alert yellow
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5B537), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.person_search_rounded, color: Color(0xFF996B00), size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'No Account Found in Database',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A3400),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'We could not find an account for "$_accountNotFoundIdentifier" in our PostgreSQL database.',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF664D00), height: 1.35),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _switchToSignUp(_accountNotFoundIdentifier),
                                    icon: const Icon(Icons.person_add_rounded, size: 16),
                                    label: const Text('Create a New Account Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DrGutColors.primary,
                                      foregroundColor: DrGutColors.onPrimary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Main Form Card ────────────────────────
                        SlideTransition(
                          position: _slideFormAnim,
                          child: Container(
                            decoration: BoxDecoration(
                              color: DrGutColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: DrGutColors.surfaceBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(22),
                            child: !_isSignUp ? _buildSignInForm() : _buildCreateAccountForm(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Google Sign In & Footer ───────────────
                        SlideTransition(
                          position: _slideGoogleAnim,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Divider(color: DrGutColors.surfaceBorder)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'or continue with',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: DrGutColors.textMuted,
                                      ),
                                    ),
                                  ),
                                  const Expanded(child: Divider(color: DrGutColors.surfaceBorder)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _GoogleSignInButton(
                                isLoading: _isGoogleLoading,
                                onPressed: _handleGoogleSignIn,
                              ),

                              const SizedBox(height: 24),

                              Text(
                                "By continuing, you agree to Dr. Gut's\nTerms of Clinical Service & Health Privacy Policy",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: DrGutColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  // ─────────────────────────────────────────────────────────────────────────
  // Sign In Form View
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSignInForm() {
    return Form(
      key: _signInFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowTag(label: 'SIGN IN'),
          const SizedBox(height: 8),
          Text(
            'Welcome back',
            style: displaySerifStyle(fontSize: 24, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your registered phone number or email to log in.',
            style: TextStyle(color: DrGutColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _signInIdentifierController,
            keyboardType: TextInputType.text,
            style: GoogleFonts.inter(fontSize: 15, color: DrGutColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Phone or Email',
              hintText: 'e.g. +919876543210 or name@domain.com',
              prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your phone number or email';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: GradientPillButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              loading: _isLoading,
              onPressed: _handleSignIn,
            ),
          ),

          const SizedBox(height: 14),

          // Action to switch to Create Account
          Center(
            child: TextButton(
              onPressed: () => _switchToSignUp(),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13, color: DrGutColors.textSecondary),
                  children: const [
                    TextSpan(text: "No account in database? "),
                    TextSpan(
                      text: 'Create an Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DrGutColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Create Account Form View
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCreateAccountForm() {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EyebrowTag(label: 'NEW PATIENT REGISTRATION'),
          const SizedBox(height: 8),
          Text(
            'Create your account',
            style: displaySerifStyle(fontSize: 24, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          const Text(
            'Register in the database to generate and save your clinical plans.',
            style: TextStyle(color: DrGutColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Name field
          TextFormField(
            controller: _signUpNameController,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.inter(fontSize: 15, color: DrGutColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g. John Doe or Dr. Sarah',
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (v.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Phone field
          TextFormField(
            controller: _signUpPhoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(fontSize: 15, color: DrGutColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Phone Number (Required)',
              hintText: 'e.g. +919876543210 or 9876543210',
              prefixIcon: Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter your phone number';
              }
              final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
              if (digitsOnly.length < 8) {
                return 'Enter a valid phone number (at least 8 digits)';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Email field (Optional)
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.inter(fontSize: 15, color: DrGutColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email Address (Optional)',
              hintText: 'e.g. user@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            ),
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: GradientPillButton(
              label: 'Create Account & Continue',
              icon: Icons.person_add_alt_1_rounded,
              loading: _isLoading,
              onPressed: _handleCreateAccount,
            ),
          ),

          const SizedBox(height: 14),

          // Switch back to Sign In
          Center(
            child: TextButton(
              onPressed: _switchToSignIn,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.inter(fontSize: 13, color: DrGutColors.textSecondary),
                  children: const [
                    TextSpan(text: 'Already registered? '),
                    TextSpan(
                      text: 'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: DrGutColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Sign-In Button
// ─────────────────────────────────────────────────────────────────────────────
class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isLoading ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: widget.isLoading ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: DrGutColors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: DrGutColors.surfaceBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: DrGutColors.primary,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: DrGutColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DrGutColors.divider,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'G',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF4285F4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Continue with Google',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DrGutColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
