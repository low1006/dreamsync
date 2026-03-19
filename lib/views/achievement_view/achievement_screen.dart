import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/views/achievement_view/reward_store_screen.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<ProfileViewModel>().userProfile;
      if (user != null) {
        context.read<AchievementViewModel>().fetchUserAchievements(user.userId);
      }
      context.read<FriendViewModel>().loadLeaderboard();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: true,
        title: Text("Achievements", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: text.withOpacity(0.5),
          tabs: const [Tab(text: "Badges"), Tab(text: "Leaderboard")],
        ),
      ),

      // ✅ STICKY STORE BUTTON (Bottom-Left)
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RewardStoreScreen()),
        ),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.shopping_bag_outlined),
        label: const Text("Store", style: TextStyle(fontWeight: FontWeight.bold)),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBadgesTab(context, text, accent),
          _buildLeaderboardTab(context, text, accent),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────
  // BADGES TAB (WITH CLEAR SEPARATION)
  // ─────────────────────────────────────────────
  Widget _buildBadgesTab(BuildContext context, Color text, Color accent) {
    return Consumer<AchievementViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        if (vm.userAchievements.isEmpty) {
          return Center(
            child: Text(
              "No achievements yet!",
              style: TextStyle(color: text.withOpacity(0.5)),
            ),
          );
        }

        // ✅ 1. Separate the achievements based on their category
        final dailyTasks = vm.userAchievements
            .where((ua) => ua.achievement?.category == 'Daily')
            .toList();

        final permanentMilestones = vm.userAchievements
            .where((ua) => ua.achievement?.category != 'Daily')
            .toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ✅ 2. Build Daily Section
            if (dailyTasks.isNotEmpty) ...[
              _buildSectionHeader("Daily Tasks", Icons.today, text, accent),
              const SizedBox(height: 12),
              ...dailyTasks.map((ua) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBadgeCard(ua, context, text, accent),
              )),
              const SizedBox(height: 20),
            ],

            // ✅ 3. Build Permanent Milestones Section
            if (permanentMilestones.isNotEmpty) ...[
              _buildSectionHeader("Milestones", Icons.military_tech, text, accent),
              const SizedBox(height: 12),
              ...permanentMilestones.map((ua) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBadgeCard(ua, context, text, accent),
              )),
            ],
          ],
        );
      },
    );
  }

  // Helper Widget for Headers
  Widget _buildSectionHeader(String title, IconData icon, Color text, Color accent) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: text,
          ),
        ),
      ],
    );
  }

  // Extracted Badge Card Widget to keep the ListView clean
  Widget _buildBadgeCard(
      UserAchievementModel userAchievement, BuildContext context, Color text, Color accent) {
    final badge = userAchievement.achievement;
    if (badge == null) return const SizedBox.shrink();

    final progress =
    (userAchievement.currentProgress / badge.criteriaValue).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: userAchievement.isUnlocked
              ? Colors.amber.withOpacity(0.4)
              : text.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Badge icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: userAchievement.isUnlocked
                  ? Colors.amber.withOpacity(0.1)
                  : text.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: userAchievement.isUnlocked
                  ? Colors.amber
                  : text.withOpacity(0.3),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Title, description, progress bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: text),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  style: TextStyle(color: text.withOpacity(0.6), fontSize: 13),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: text.withOpacity(0.1),
                    color: userAchievement.isUnlocked ? Colors.green : accent,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${userAchievement.currentProgress.toInt()} / ${badge.criteriaValue.toInt()}",
                  style: TextStyle(
                      fontSize: 12,
                      color: text.withOpacity(0.5),
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Claim Button or Claimed Text
          if (userAchievement.isUnlocked)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: userAchievement.isClaimed
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 28),
                  const SizedBox(height: 4),
                  Text(
                    "Claimed",
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              )
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  final userVM = context.read<ProfileViewModel>();
                  context.read<AchievementViewModel>().claimReward(
                    userAchievement.userAchievementId,
                    userVM,
                  );
                },
                child: Text(
                  "Claim\n+${badge.xpReward.toInt()}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // LEADERBOARD TAB
  // ─────────────────────────────────────────────
  Widget _buildLeaderboardTab(
      BuildContext context, Color text, Color accent) {
    return Consumer2<FriendViewModel, ProfileViewModel>(
      builder: (context, friendVM, profileVM, child) {
        final currentUser = profileVM.userProfile;

        if (currentUser == null) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        if (friendVM.isLoading && friendVM.leaderboardUsers.isEmpty) {
          return Center(child: CircularProgressIndicator(color: accent));
        }

        final leaderboard = friendVM.leaderboardUsers;
        final noFriends = leaderboard.length <= 1;

        if (noFriends) {
          return _buildNoFriendsView(currentUser, text, accent, context);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: leaderboard.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = leaderboard[index];
            final rank = index + 1;
            final isMe = user.userId == currentUser.userId;

            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe
                    ? accent.withOpacity(0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: isMe
                    ? Border.all(color: accent, width: 1.5)
                    : Border.all(color: text.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank, accent),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      "#$rank",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? "${user.username} (You)" : user.username,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe ? accent : text,
                              fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              "${user.streak} Day Streak",
                              style: TextStyle(
                                  color: text.withOpacity(0.6),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isMe)
                    Icon(Icons.star,
                        color: Colors.amber.shade400, size: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoFriendsView(UserModel currentUser, Color text,
      Color accent, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: text.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  "Your Current Streak",
                  style: TextStyle(
                      fontSize: 14,
                      color: text.withOpacity(0.5),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 40),
                    const SizedBox(width: 8),
                    Text(
                      "${currentUser.streak}",
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: text),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              "You haven't added any friends yet.\nAdd friends to compete on the leaderboard!",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: text.withOpacity(0.6), height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            onPressed: () =>
                Navigator.pushNamed(context, '/friend_list'),
            icon: const Icon(Icons.person_add),
            label: const Text("Find Friends",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank, Color defaultColor) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return defaultColor.withOpacity(0.5);
  }
}