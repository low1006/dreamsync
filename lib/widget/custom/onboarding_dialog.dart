import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/util/app_theme.dart';

/// Full-screen onboarding / help guide.
///
/// Shows a series of images pages with back/next navigation and page dots.
/// Tracks first-launch via SharedPreferences so it auto-shows only once.
class OnboardingDialog {
  static const String _prefKey = 'has_seen_onboarding';

  /// Returns true if the user has never seen the onboarding.
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefKey) ?? false);
  }

  /// Marks onboarding as seen so it won't auto-show again.
  static Future<void> markAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// Shows the onboarding dialog. Call from anywhere.
  static void show(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return const _OnboardingContent();
      },
    );
  }

  /// Auto-show on first launch. Call once in your main screen's initState.
  /// The caller (a State method) should check `mounted` before and after.
  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final shouldDisplay = await shouldShow();
    if (!shouldDisplay) return;

    await Future.delayed(const Duration(milliseconds: 500));

    // The caller is responsible for checking mounted before calling this.
    OnboardingDialog.show(context);
    await markAsSeen();
  }
}

class _OnboardingContent extends StatefulWidget {
  const _OnboardingContent();

  @override
  State<_OnboardingContent> createState() => _OnboardingContentState();
}

class _OnboardingContentState extends State<_OnboardingContent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ─── Configure your onboarding pages here ──────────────────────────────
  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      image: 'assets/images/onboarding/step1.jpg',
      title: 'Track Your Sleep & Behavioural Data',
      description: 'Automatically sync your sleep data from Health Connect '
          'and input your behavioural data into the app. Scroll down to sync your data.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step2.jpg',
      title: 'History Data',
      description: 'View your last 7 days of sleep and behavioural data from Health Connect, '
          'and explore detailed sleep stages for every day.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step3.jpg',
      title: 'Complete Daily Tasks',
      description: 'Build healthy sleep habits by completing daily tasks to earn points and badges.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step4.jpg',
      title: 'Claim Rewards',
      description: 'Use your earned points in the Reward Store to unlock exclusive avatars, '
          'new alarm audio, and streak shields to protect your progress.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step5.jpg',
      title: 'Climb the Leaderboard',
      description: 'Track your sleep streaks and compete with your friends to see who has the best sleep habits.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step6.jpg',
      title: 'Profile',
      description: 'View your profile and use the edit button on the top right to update your information.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step7.jpg',
      title: 'Account Settings',
      description: 'Manage your account settings, easily add friends, or safely log out.',
    ),
    _OnboardingPage(
        image: 'assets/images/onboarding/step8.jpg',
        title: 'My Friends',
        description: 'Add your friends using their UID to share your progress and join the competition.'
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step9.jpg',
      title: 'Schedule Recommendation',
      description: 'View personalized recommendations for tonight\'s sleep to help you achieve better rest and recovery.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step10.jpg',
      title: 'Smart Alarm',
      description: 'Set smart alarms that wake you gently with changing '
          'tones and adjustable snooze duration.',
    ),
    _OnboardingPage(
      image: 'assets/images/onboarding/step11.jpg',
      title: 'AI Sleep Advisor',
      description: 'Get personalized sleep advice powered by AI based on '
          'your sleep patterns and daily habits.',
    ),
  ];

  bool get _isFirstPage => _currentPage == 0;
  bool get _isLastPage => _currentPage == _pages.length - 1;

  void _goNext() {
    if (_isLastPage) {
      Navigator.of(context).pop();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final text = AppTheme.text(context);
    final subText = AppTheme.subText(context);
    final accent = AppTheme.accent;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Center(
        // The Material widget here fixes the yellow underline text issue
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Skip button ──
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: subText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Page content ──
                Flexible(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Image placeholder
                            Flexible(
                              flex: 3,
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 280),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.asset(
                                    page.image,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: accent.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 64,
                                          color: accent.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Title
                            Text(
                              page.title,
                              style: TextStyle(
                                color: text,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            // Description
                            Text(
                              page.description,
                              style: TextStyle(
                                color: subText,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // ── Page indicators ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? accent : subText.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Back / Next buttons ──
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + bottomPadding),
                  child: Row(
                    children: [
                      // Back button
                      Expanded(
                        child: _isFirstPage
                            ? const SizedBox.shrink()
                            : OutlinedButton(
                          onPressed: _goBack,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: subText.withOpacity(0.3),
                            ),
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      if (!_isFirstPage) const SizedBox(width: 12),
                      // Next / Get Started button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _goNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isLastPage ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
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
    );
  }
}

class _OnboardingPage {
  final String image;
  final String title;
  final String description;

  const _OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
  });
}