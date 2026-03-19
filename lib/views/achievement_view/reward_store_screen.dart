import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/reward_store_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<ProfileViewModel>().userProfile;
      print('🟡 [RewardStoreScreen] userProfile = ${user?.userId}');

      if (user != null) {
        await context.read<RewardStoreViewModel>().initialize(user.userId);
      } else {
        print('🔴 [RewardStoreScreen] userProfile is null, initialize skipped');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          "Reward Store",
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: text),
      ),
      body: Consumer<RewardStoreViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildBalanceHeader(vm.currentPoints),

              if (vm.debugMessage != null)
                _buildMessageCard(
                  vm.debugMessage!,
                  Colors.blue.shade100,
                  Colors.blue.shade800,
                ),

              if (vm.errorMessage != null)
                _buildMessageCard(
                  vm.errorMessage!,
                  Colors.red.shade100,
                  Colors.red.shade700,
                ),

              if (vm.successMessage != null)
                _buildMessageCard(
                  vm.successMessage!,
                  Colors.green.shade100,
                  Colors.green.shade700,
                ),

              if (vm.validationMessage != null && vm.hasSelection)
                _buildMessageCard(
                  vm.validationMessage!,
                  Colors.orange.shade100,
                  Colors.orange.shade700,
                ),

              Expanded(
                child: vm.storeItems.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 54,
                          color: text.withOpacity(0.35),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No items available to purchase.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text.withOpacity(0.65),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          vm.debugMessage ??
                              "Debug info not available.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: text.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final user =
                                context.read<ProfileViewModel>().userProfile;
                            if (user != null) {
                              await vm.refresh(user.userId);
                            }
                          },
                          child: const Text("Reload Store"),
                        ),
                      ],
                    ),
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () async {
                    final user = context.read<ProfileViewModel>().userProfile;
                    if (user != null) {
                      await vm.refresh(user.userId);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: vm.storeItems.length,
                    itemBuilder: (context, index) {
                      final item = vm.storeItems[index];
                      final isOwned = vm.isOwned(item);
                      final isSelected = vm.isSelected(item);
                      final canAfford = vm.canAfford(item);

                      return _buildStoreItemCard(
                        context: context,
                        item: item,
                        isOwned: isOwned,
                        isSelected: isSelected,
                        canAfford: canAfford,
                        cardColor: cardColor,
                        textColor: text,
                        vm: vm,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceHeader(int points) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text(
            "Available Balance",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$points",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.stars, color: Colors.white, size: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(
      String message,
      Color bgColor,
      Color textColor,
      ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStoreItemCard({
    required BuildContext context,
    required StoreItem item,
    required bool isOwned,
    required bool isSelected,
    required bool canAfford,
    required Color cardColor,
    required Color textColor,
    required RewardStoreViewModel vm,
  }) {
    return GestureDetector(
      onTap: () => vm.selectItem(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber : textColor.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : [],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.withOpacity(0.12),
              child: Icon(
                _iconForType(item.type),
                color: Colors.blue,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${item.cost} XP",
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _subtitleForItem(item),
                    style: TextStyle(
                      color: textColor.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              context: context,
              item: item,
              isOwned: isOwned,
              canAfford: canAfford,
              vm: vm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required StoreItem item,
    required bool isOwned,
    required bool canAfford,
    required RewardStoreViewModel vm,
  }) {
    if (isOwned) {
      return const Text(
        "Owned",
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? Colors.amber : Colors.grey,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: vm.isPurchasing
          ? null
          : () async {
        vm.selectItem(item);

        final success = await vm.purchaseSelectedItem();

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Unlocked ${item.name}!")),
          );
        } else if (vm.validationMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.validationMessage!)),
          );
        } else if (vm.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.errorMessage!)),
          );
        }
      },
      child: vm.isPurchasing && vm.isSelected(item)
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Text(canAfford ? "Unlock" : "Locked"),
    );
  }

  IconData _iconForType(StoreItemType type) {
    switch (type) {
      case StoreItemType.AUDIO:
        return Icons.music_note;
      case StoreItemType.VIDEO:
        return Icons.video_library_outlined;
      case StoreItemType.ITEM:
        return Icons.inventory_2_outlined;
      case StoreItemType.UNKNOWN:
        return Icons.help_outline;
    }
  }

  String _subtitleForItem(StoreItem item) {
    switch (item.type) {
      case StoreItemType.AUDIO:
        return "Audio reward";
      case StoreItemType.VIDEO:
        return "Video reward";
      case StoreItemType.ITEM:
        if (item.freezeDays > 0) {
          return "Protects streak for ${item.freezeDays} day(s)";
        }
        return "Special store item";
      case StoreItemType.UNKNOWN:
        return "Reward item";
    }
  }
}