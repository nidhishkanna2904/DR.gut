import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme.dart';
import '../widgets/auth_modal.dart';
import 'calorie_snap_screen.dart';
import 'create_plan_screen.dart';
import 'plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Mini quiz state for Gut Vitality Score
  int _bloatingAnswer = 1; // 0: Rarely, 1: Occasionally, 2: Frequently
  int _fiberAnswer = 1; // 0: High/Daily, 1: Moderate, 2: Low
  int _energyAnswer = 1; // 0: Great, 1: Afternoon dip, 2: Sluggish

  // Sample meal tab index
  int _sampleMealIndex = 0;

  // Completed daily meals tracker (0: Breakfast, 1: Lunch, 2: Snack, 3: Dinner)
  final Set<int> _completedMealIndices = {0};

  void _onStartPlanFlow() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (!appState.hasSavedProfile) {
      // User is not logged in / no profile -> prompt AuthModal first!
      final loggedIn = await AuthModal.show(
        context,
        title: 'Sign In & Set Up Profile',
        subtitle:
            'Enter your basic details so Dr. Gut can tailor meals to your allergies and daily budget.',
        actionLabel: 'Continue to Upload Report',
      );
      if (!loggedIn || !mounted) return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
    );
  }

  int _calculateGutScore() {
    int score = 88;
    if (_bloatingAnswer == 1) score -= 12;
    if (_bloatingAnswer == 2) score -= 26;

    if (_fiberAnswer == 1) score -= 8;
    if (_fiberAnswer == 2) score -= 22;

    if (_energyAnswer == 1) score -= 6;
    if (_energyAnswer == 2) score -= 18;

    return score.clamp(35, 96);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.profile;

    return Scaffold(
      backgroundColor: DrGutColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: DrGutColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/logo_app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.biotech,
                      color: DrGutColors.primary, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Dr. Gut',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: DrGutColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: DrGutColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Text('AI CLINICAL',
                  style: TextStyle(
                      color: DrGutColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          if (user != null && user.name.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 3),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DrGutColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DrGutColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: DrGutColors.primary,
                      child: Text(
                        user.name[0].toUpperCase(),
                        style: const TextStyle(
                            color: DrGutColors.onPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.name.split(' ').first,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DrGutColors.textPrimary),
                    ),
                  ],
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: () async {
                await AuthModal.show(context,
                    title: 'Sign In / Register', actionLabel: 'Save Profile');
              },
              icon:
                  const Icon(Icons.login, size: 16, color: DrGutColors.primary),
              label: const Text('Sign In',
                  style: TextStyle(
                      color: DrGutColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildExploreTab(context, appState),
                _buildMyPlanTab(context, appState),
                const CalorieSnapScreen(),
                _buildProfileTab(context, appState),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: DrGutColors.surfaceBorder, width: 0.8)),
          color: DrGutColors.surface,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: DrGutColors.primary,
          unselectedItemColor: DrGutColors.textMuted,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt_outlined),
              activeIcon: Icon(Icons.task_alt),
              label: 'Daily Diet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt),
              label: 'Calorie Snap',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: EXPLORE / DASHBOARD
  // ==========================================
  // Helper: time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildExploreTab(BuildContext context, AppState appState) {
    final t = Theme.of(context).textTheme;
    final user = appState.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      children: [
        // Greeting header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user != null && user.name.isNotEmpty
                        ? '${_getGreeting()}, ${user.name.split(' ').first} 👋'
                        : '${_getGreeting()}! 👋',
                    style: t.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI-powered gut health & blood biomarker nutrition',
                    style:
                        t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // === STATS STRIP ===
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: DrGutColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: DrGutColors.surfaceBorder),
          ),
          child: Row(
            children: [
              _statPill('12K+', 'Users', Icons.people_outline),
              _vertDivider(),
              _statPill('6', 'Biomarkers', Icons.biotech_outlined),
              _vertDivider(),
              _statPill('94%', 'Accuracy', Icons.verified_outlined),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // === GRAND HERO CARD ===
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: DrGutColors.primary.withValues(alpha: 0.45), width: 1.2),
            gradient: const LinearGradient(
              colors: [Color(0xFF142518), Color(0xFF0D1A12), Color(0xFF0A1510)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: DrGutColors.primary.withValues(alpha: 0.18),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: DrGutColors.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: DrGutColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 11, color: DrGutColors.primary),
                        SizedBox(width: 5),
                        Text(
                          'AI CLINICAL • GEO-DIET ENGINE',
                          style: TextStyle(
                              color: DrGutColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Logo
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: DrGutColors.primary.withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/logo_app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: DrGutColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.biotech,
                              color: DrGutColors.primary, size: 24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Headline
              Text(
                'Your Personalized\nGut Diet Plan',
                style: t.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a blood report — our AI identifies exact nutrient deficiencies and pairs them with fresh, budget-friendly local foods.',
                style: t.bodySmall
                    ?.copyWith(color: DrGutColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 20),
              // CTA
              GradientPillButton(
                label: 'Create My Diet Plan',
                icon: Icons.auto_awesome,
                onPressed: _onStartPlanFlow,
              ),
              const SizedBox(height: 14),
              // Trust chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _trustChip(Icons.lock_outline, 'Private & Secure'),
                  _trustChip(Icons.location_on_outlined, 'GPS-Powered'),
                  _trustChip(Icons.flash_on_outlined, '< 2 min Results'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // === HOW IT WORKS ===
        _buildSectionHeader('How It Works', 'Simple 3-step clinical protocol'),
        const SizedBox(height: 12),
        _buildHowItWorksSteps(t),
        const SizedBox(height: 28),

        // === GUT HEALTH SCORE QUIZ ===
        _buildSectionHeader(
            'Gut Vitality Check', 'Instant 30-second microbiome estimate'),
        const SizedBox(height: 12),
        _buildGutScoreCard(t),
        const SizedBox(height: 28),

        // === SAMPLE AI DIET PLAN ===
        _buildSectionHeader(
            'Sample AI Diet Plan', 'Real example of a targeted gut & blood plan'),
        const SizedBox(height: 12),
        _buildSamplePlanPreview(t),
        const SizedBox(height: 28),

        // === BIOMARKERS ===
        _buildSectionHeader(
            'Biomarkers We Analyze', '6 key blood markers decoded'),
        const SizedBox(height: 12),
        _buildBiomarkerQuickGrid(t),
        const SizedBox(height: 28),

        // === LOCAL FOOD ENGINE ===
        _buildLocalFoodEngineCard(t),
        const SizedBox(height: 28),

        // === SCIENCE TIP ===
        _buildDailyTipsCard(t),
      ],
    );
  }

  // ---- Explore Tab helpers ----

  Widget _statPill(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: DrGutColors.primary),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: DrGutColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: DrGutColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        height: 40,
        color: DrGutColors.surfaceBorder,
      );

  Widget _trustChip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: DrGutColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DrGutColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: DrGutColors.primary),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: DrGutColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _buildSectionHeader(String title, String subtitle) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: DrGutColors.textPrimary)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: DrGutColors.textSecondary)),
            ],
          ),
          const Spacer(),
          Container(
            width: 28,
            height: 3,
            decoration: BoxDecoration(
              color: DrGutColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );

  Widget _buildHowItWorksSteps(TextTheme t) {
    final steps = [
      (
        Icons.upload_file_outlined,
        'Upload Blood Report',
        'PDF or image of your CBC, thyroid, lipid or vitamin panel'
      ),
      (
        Icons.psychology_outlined,
        'AI Analyses Deficiencies',
        'Detects iron, B12, D3, folate and 6+ gut-linked biomarkers'
      ),
      (
        Icons.restaurant_menu_outlined,
        'Get Local Meal Plan',
        'Budget-friendly foods from your nearest market, matched to deficiencies'
      ),
    ];

    return Column(
      children: steps.asMap().entries.map((entry) {
        final idx = entry.key;
        final (icon, title, desc) = entry.value;
        final isLast = idx == steps.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator column
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DrGutColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: DrGutColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Center(
                    child: Icon(icon, color: DrGutColors.primary, size: 18),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          DrGutColors.primary.withValues(alpha: 0.4),
                          DrGutColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // Step text
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: DrGutColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Step ${idx + 1}',
                            style: const TextStyle(
                                color: DrGutColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: DrGutColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: t.bodySmall
                          ?.copyWith(color: DrGutColors.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // Mini Quiz Card
  Widget _buildGutScoreCard(TextTheme t) {
    final score = _calculateGutScore();
    Color scoreColor = DrGutColors.primary;
    String status = 'Optimal Gut Diversity';
    if (score < 60) {
      scoreColor = DrGutColors.error;
      status = 'Potential Imbalance';
    } else if (score < 75) {
      scoreColor = const Color(0xFFFFB800);
      status = 'Moderate Diversity';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconChip(icon: Icons.speed_outlined, color: scoreColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gut Vitality Quick Check',
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('Instant 30-second microbiome estimate',
                          style: t.bodySmall
                              ?.copyWith(color: DrGutColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: scoreColor.withValues(alpha: 0.4)),
                  ),
                  child: Text('$score / 100',
                      style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Status: $status',
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            const Divider(height: 22),

            // Question 1: Bloating
            const Text('1. How frequently do you experience bloating or gas?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _quizChip('Rarely', 0, _bloatingAnswer,
                    (v) => setState(() => _bloatingAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('Occasionally', 1, _bloatingAnswer,
                    (v) => setState(() => _bloatingAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('Frequently', 2, _bloatingAnswer,
                    (v) => setState(() => _bloatingAnswer = v)),
              ],
            ),
            const SizedBox(height: 14),

            // Question 2: Fiber & Fermented Foods
            const Text(
                '2. Intake of fermented foods (chaas, curd, idli) & fiber?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _quizChip('Daily', 0, _fiberAnswer,
                    (v) => setState(() => _fiberAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('2-3x / week', 1, _fiberAnswer,
                    (v) => setState(() => _fiberAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('Rarely', 2, _fiberAnswer,
                    (v) => setState(() => _fiberAnswer = v)),
              ],
            ),
            const SizedBox(height: 14),

            // Question 3: Post-Meal Energy & Fatigue
            const Text('3. Post-meal energy crashes or brain fog?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _quizChip('Rarely', 0, _energyAnswer,
                    (v) => setState(() => _energyAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('Afternoon dip', 1, _energyAnswer,
                    (v) => setState(() => _energyAnswer = v)),
                const SizedBox(width: 8),
                _quizChip('Frequent', 2, _energyAnswer,
                    (v) => setState(() => _energyAnswer = v)),
              ],
            ),
            const SizedBox(height: 16),

            // CTA inside quiz
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DrGutColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: DrGutColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: DrGutColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A blood test reveals the exact missing micronutrients behind your symptoms.',
                      style: t.bodySmall?.copyWith(
                          color: DrGutColors.textSecondary, fontSize: 11),
                    ),
                  ),
                  TextButton(
                    onPressed: _onStartPlanFlow,
                    child: const Text('Test Blood',
                        style: TextStyle(
                            color: DrGutColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quizChip(
      String label, int val, int currentVal, ValueChanged<int> onSelect) {
    final selected = val == currentVal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? DrGutColors.primary.withValues(alpha: 0.2)
                : DrGutColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    selected ? DrGutColors.primary : DrGutColors.surfaceBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? DrGutColors.primary : DrGutColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // Sample Plan Interactive Preview
  Widget _buildSamplePlanPreview(TextTheme t) {
    final sampleMeals = [
      {
        'title': 'Breakfast (8:30 AM)',
        'items':
            'Sprouted Ragi & Oats Porridge with Roasted Almonds + Amla Ginger Juice',
        'why':
            'Ragi provides calcium and resistant starch; Amla supplies 300mg Vitamin C to dramatically enhance non-heme iron absorption.',
        'calories': '~340 kcal',
      },
      {
        'title': 'Lunch (1:00 PM)',
        'items':
            'Brown Rice with Moringa Drumstick Dal, Methi Sabzi & Fresh Cumin Chaas',
        'why':
            'Moringa leaves provide bioavailable ferritin; curd/chaas delivers live Lactobacillus cultures to heal intestinal lining.',
        'calories': '~520 kcal',
      },
      {
        'title': 'Snack (5:00 PM)',
        'items':
            'Roasted Makhana (Foxnuts) with Pumpkin Seeds & Jeera Green Tea',
        'why':
            'Zinc from pumpkin seeds supports gut mucosal integrity and prevents evening glucose spikes.',
        'calories': '~180 kcal',
      },
      {
        'title': 'Dinner (8:30 PM)',
        'items':
            'Steamed Moong Dal Khichdi with Ghee & Lauki (Bottle Gourd) Soup',
        'why':
            'Light, high-solubility fiber allows full resting digestion; butyrate from ghee feeds colonocytes overnight.',
        'calories': '~390 kcal',
      },
    ];

    final current = sampleMeals[_sampleMealIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target badge
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: DrGutColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: DrGutColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Text('Target: Iron & B12',
                style: TextStyle(
                    color: DrGutColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),

        // Meal Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _mealTab('Breakfast', 0),
              const SizedBox(width: 8),
              _mealTab('Lunch', 1),
              const SizedBox(width: 8),
              _mealTab('Snack', 2),
              const SizedBox(width: 8),
              _mealTab('Dinner', 3),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Meal Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(current['title']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: DrGutColors.primary)),
                    Text(current['calories']!,
                        style: const TextStyle(
                            fontSize: 12, color: DrGutColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(current['items']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DrGutColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.biotech,
                          size: 16, color: DrGutColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          current['why']!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: DrGutColors.textSecondary,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealTab(String title, int idx) {
    final active = _sampleMealIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _sampleMealIndex = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? DrGutColors.primary : DrGutColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? DrGutColors.primary : DrGutColors.surfaceBorder),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? DrGutColors.onPrimary : DrGutColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // Biomarker Quick Grid
  Widget _buildBiomarkerQuickGrid(TextTheme t) {
    final markers = [
      {
        'name': 'Iron / Ferritin',
        'desc': 'Oxygenation & cellular fatigue',
        'icon': Icons.bloodtype_outlined
      },
      {
        'name': 'Vitamin B12',
        'desc': 'Nerve sheath & microbial balance',
        'icon': Icons.psychology_outlined
      },
      {
        'name': 'Vitamin D3',
        'desc': 'Gut epithelial tight junctions',
        'icon': Icons.wb_sunny_outlined
      },
      {
        'name': 'HbA1c / Sugar',
        'desc': 'Insulin spikes & dysbiosis',
        'icon': Icons.show_chart_outlined
      },
      {
        'name': 'Lipid Profile',
        'desc': 'Bile acid synthesis & liver health',
        'icon': Icons.favorite_border_outlined
      },
      {
        'name': 'Thyroid Panel',
        'desc': 'Digestive transit time & motility',
        'icon': Icons.medication_outlined
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: markers.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.8,
          ),
          itemBuilder: (ctx, i) {
            final m = markers[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DrGutColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DrGutColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(m['icon'] as IconData,
                          size: 16, color: DrGutColors.primary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          m['name'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m['desc'] as String,
                    style: const TextStyle(
                        fontSize: 10, color: DrGutColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Hyper-Local Food Engine Card
  Widget _buildLocalFoodEngineCard(TextTheme t) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconChip(icon: Icons.my_location_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hyper-Local Food Intelligence',
                          style: t.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                          'GPS coordinates power our regional nutrition engine',
                          style: t.bodySmall
                              ?.copyWith(color: DrGutColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Expensive imported supplements often fail. Dr. Gut uses your exact location to suggest fresh, budget-friendly foods available at your local mandi — like curry leaves, sprouted moong, sattu, and home-fermented buttermilk.',
              style: t.bodySmall
                  ?.copyWith(color: DrGutColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // Daily Tips Card
  Widget _buildDailyTipsCard(TextTheme t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DrGutColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DrGutColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: DrGutColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Science Tip of the Day',
                  style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: DrGutColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The 30-Plants Challenge: Studies show people who eat 30+ diverse plant varieties a week have vastly more diverse gut microbiomes than those consuming fewer than 10, drastically lowering systemic inflammation.',
            style: TextStyle(
                fontSize: 12, color: DrGutColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: DAILY DIET & COMPLETED MEALS
  // ==========================================
  Widget _buildMyPlanTab(BuildContext context, AppState appState) {
    final t = Theme.of(context).textTheme;
    final plan = appState.currentPlan ?? appState.lastSavedPlan;

    // Define today's meals list (either from active plan or baseline protocol)
    final List<Map<String, String>> meals;
    if (plan != null &&
        plan.days.isNotEmpty &&
        plan.days.first.meals.isNotEmpty) {
      meals = plan.days.first.meals
          .map((m) => {
                'time': m.time,
                'items': m.items,
                'why': m.why,
                'calories': '~380 kcal',
              })
          .toList();
    } else {
      meals = [
        {
          'time': 'Breakfast (8:30 AM)',
          'items':
              'Sprouted Ragi & Oats Porridge with Crushed Flaxseeds & Amla Ginger Juice',
          'why': 'Bioavailable Iron, Vitamin C & Beta-Glucan prebiotic fiber',
          'calories': '~340 kcal',
        },
        {
          'time': 'Lunch (1:00 PM)',
          'items':
              'Methi Moong Dal Khichdi + Fresh Mint Chaas (Cultured Buttermilk)',
          'why': 'Live Lactobacillus probiotics & gut lining restoration',
          'calories': '~480 kcal',
        },
        {
          'time': 'Evening Snack (4:30 PM)',
          'items':
              'Roasted Makhana (Fox Nuts) & Walnuts + Warm Digestive Infusion',
          'why':
              'Polyphenols to nourish beneficial Akkermansia muciniphila bacteria',
          'calories': '~180 kcal',
        },
        {
          'time': 'Dinner (8:00 PM)',
          'items':
              'Steamed Lauki (Bottle Gourd) & Tofu Sabzi with 2 Multigrain Rotis',
          'why':
              'Low glycemic, high soluble fiber supporting nocturnal gut motility',
          'calories': '~410 kcal',
        },
      ];
    }

    final totalMeals = meals.length;
    final completedCount =
        _completedMealIndices.where((idx) => idx < totalMeals).length;
    final progress = totalMeals > 0 ? (completedCount / totalMeals) : 0.0;
    final isAllCompleted = completedCount == totalMeals && totalMeals > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
      children: [
        // Title & Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Diet Tracker',
                    style:
                        t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Completed diet of daily & meal compliance',
                    style: t.bodySmall
                        ?.copyWith(color: DrGutColors.textSecondary)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: DrGutColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: DrGutColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today,
                      size: 12, color: DrGutColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    plan != null ? 'Custom Protocol' : 'Standard Protocol',
                    style: const TextStyle(
                        color: DrGutColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Daily Progress Completion Hero Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isAllCompleted
                  ? [const Color(0xFF0F3820), const Color(0xFF14241B)]
                  : [const Color(0xFF1A2A20), const Color(0xFF121915)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: isAllCompleted
                  ? DrGutColors.primary
                  : DrGutColors.primary.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: DrGutColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: DrGutColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isAllCompleted ? Icons.verified : Icons.task_alt,
                          color: DrGutColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAllCompleted
                            ? 'Daily Diet Complete! 🎉'
                            : 'Daily Diet Progress',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: DrGutColors.textPrimary),
                      ),
                    ],
                  ),
                  Text(
                    '$completedCount of $totalMeals Eaten',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: DrGutColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: DrGutColors.background,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(DrGutColors.primary),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _dailyMetric(Icons.local_fire_department, '~1,410 kcal',
                      'Target Energy'),
                  _dailyMetric(Icons.spa, '30+ Plants', 'Microbiome Diversity'),
                  _dailyMetric(Icons.bolt, '3-Day', 'Active Streak 🔥'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Quick Calorie Snap Food Photo Banner
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 2),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: DrGutColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: DrGutColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: DrGutColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: DrGutColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimate Food Calories by Camera',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: DrGutColors.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Snap a food photo to estimate calories & track nutrition',
                        style: TextStyle(
                            fontSize: 11, color: DrGutColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: DrGutColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Meals Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s Prescribed Meals',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text('${(progress * 100).toInt()}% Done',
                style: const TextStyle(
                    color: DrGutColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),

        // Meals List
        ...List.generate(totalMeals, (index) {
          final meal = meals[index];
          final isCompleted = _completedMealIndices.contains(index);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isCompleted
                  ? DrGutColors.surface.withValues(alpha: 0.7)
                  : DrGutColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isCompleted
                    ? DrGutColors.primary.withValues(alpha: 0.6)
                    : DrGutColors.surfaceBorder,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getMealIcon(meal['time'] ?? ''),
                            color: isCompleted
                                ? DrGutColors.primary
                                : DrGutColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            meal['time'] ?? 'Meal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isCompleted
                                  ? DrGutColors.primary
                                  : DrGutColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? DrGutColors.primary.withValues(alpha: 0.2)
                              : DrGutColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCompleted
                                ? DrGutColors.primary.withValues(alpha: 0.4)
                                : DrGutColors.surfaceBorder,
                          ),
                        ),
                        child: Text(
                          meal['calories'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? DrGutColors.primary
                                : DrGutColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    meal['items'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted
                          ? DrGutColors.textSecondary
                          : DrGutColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: DrGutColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.biotech_outlined,
                            size: 14, color: DrGutColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            meal['why'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, color: DrGutColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted
                              ? DrGutColors.primary
                              : DrGutColors.surface,
                          foregroundColor: isCompleted
                              ? DrGutColors.onPrimary
                              : DrGutColors.primary,
                          elevation: 0,
                          side: BorderSide(
                            color: isCompleted
                                ? DrGutColors.primary
                                : DrGutColors.primary.withValues(alpha: 0.4),
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_completedMealIndices.contains(index)) {
                              _completedMealIndices.remove(index);
                            } else {
                              _completedMealIndices.add(index);
                            }
                          });
                        },
                        icon: Icon(
                          isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                        ),
                        label: Text(
                          isCompleted ? 'Completed ✓' : 'Mark as Eaten',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // Personalized Plan Actions
        if (plan != null) ...[
          GradientPillButton(
            label: 'View Full Multi-Day Protocol',
            icon: Icons.visibility_outlined,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlanScreen(plan: plan)),
              );
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              side: const BorderSide(color: DrGutColors.surfaceBorder),
            ),
            onPressed: _onStartPlanFlow,
            icon:
                const Icon(Icons.refresh, size: 16, color: DrGutColors.primary),
            label: const Text('Generate a New Plan',
                style: TextStyle(
                    color: DrGutColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DrGutColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: DrGutColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: DrGutColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Want 100% Personalization?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Upload your CBC / Vitamin blood report to get a clinical diet targeting your exact nutrient gaps and local seasonal foods.',
                  style: TextStyle(
                      fontSize: 12,
                      color: DrGutColors.textSecondary,
                      height: 1.4),
                ),
                const SizedBox(height: 12),
                GradientPillButton(
                  label: 'Upload Blood Report & Personalize',
                  icon: Icons.upload_file,
                  onPressed: _onStartPlanFlow,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dailyMetric(IconData icon, String val, String lbl) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: DrGutColors.primary),
            const SizedBox(width: 4),
            Text(val,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: DrGutColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(lbl,
            style: const TextStyle(
                fontSize: 10, color: DrGutColors.textSecondary)),
      ],
    );
  }

  IconData _getMealIcon(String mealTime) {
    final lower = mealTime.toLowerCase();
    if (lower.contains('breakfast')) return Icons.free_breakfast_outlined;
    if (lower.contains('lunch')) return Icons.lunch_dining_outlined;
    if (lower.contains('snack')) return Icons.cookie_outlined;
    if (lower.contains('dinner')) return Icons.dinner_dining_outlined;
    return Icons.restaurant_outlined;
  }

  // ==========================================
  // TAB 3: ACCOUNT & PROFILE
  // ==========================================
  Widget _buildProfileTab(BuildContext context, AppState appState) {
    final t = Theme.of(context).textTheme;
    final user = appState.profile;

    if (user != null && user.name.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
        children: [
          Text('My Nutrition Profile',
              style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Your stored personal preferences and clinical constraints',
              style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary)),
          const SizedBox(height: 20),

          // User Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        DrGutColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      user.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: DrGutColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                      style:
                          t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user.phone,
                      style: const TextStyle(
                          color: DrGutColors.textSecondary, fontSize: 13)),
                  const Divider(height: 28),
                  _profileRow('Daily Budget', '₹${user.budget} / day',
                      Icons.currency_rupee),
                  const Divider(height: 16),
                  _profileRow(
                      'Detected Location',
                      user.locationName.isNotEmpty
                          ? user.locationName
                          : 'Auto GPS',
                      Icons.location_on_outlined),
                  const Divider(height: 16),
                  _profileRow(
                      'Allergies',
                      user.allergies.isNotEmpty
                          ? user.allergies
                          : 'None recorded',
                      Icons.warning_amber_outlined),
                  const Divider(height: 16),
                  _profileRow(
                      'Disliked Foods',
                      user.dislikes.isNotEmpty ? user.dislikes : 'None',
                      Icons.thumb_down_alt_outlined),
                  const Divider(height: 16),
                  _profileRow(
                      'Health Conditions',
                      user.disease.isNotEmpty ? user.disease : 'None noted',
                      Icons.medical_information_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          GradientPillButton(
            label: 'Edit Profile & Budget',
            icon: Icons.edit_outlined,
            onPressed: () async {
              await AuthModal.show(context,
                  title: 'Edit Profile Details', actionLabel: 'Save Changes');
              setState(() {});
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
              side: const BorderSide(color: DrGutColors.surfaceBorder),
            ),
            onPressed: () async {
              await appState.logout();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logged out of Dr. Gut.')),
                );
              }
            },
            icon: const Icon(Icons.logout, size: 18, color: DrGutColors.error),
            label: const Text('Sign Out / Reset Profile',
                style: TextStyle(
                    color: DrGutColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    // Guest Profile
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DrGutColors.surface,
                border: Border.all(color: DrGutColors.surfaceBorder),
              ),
              child: const Icon(Icons.person_outline,
                  size: 48, color: DrGutColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Text('Browsing as Guest',
                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Sign in or set up your profile to save your dietary restrictions, track biomarker changes, and generate plans.',
              textAlign: TextAlign.center,
              style: t.bodyMedium
                  ?.copyWith(color: DrGutColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            GradientPillButton(
              label: 'Sign In / Set Up Profile',
              icon: Icons.login,
              onPressed: () async {
                await AuthModal.show(context,
                    title: 'Welcome to Dr. Gut', actionLabel: 'Save Profile');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DrGutColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: DrGutColors.textSecondary)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: DrGutColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
