import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/reward_store_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';

class RewardStorePage extends StatelessWidget {
  const RewardStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RewardStoreViewModel(
        inventoryRepository: InventoryRepository(),
        userRepository: UserRepository(),
      ),
      child: const RewardStoreScreen(),
    );
  }
}

class RewardStoreScreen extends StatefulWidget {
  const RewardStoreScreen({super.key});

  @override
  State<RewardStoreScreen> createState() => _RewardStoreScreenState();
}

class _RewardStoreScreenState extends State<RewardStoreScreen> {
  bool _initialized = false;
  RewardStoreViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _vm ??= context.read<RewardStoreViewModel>();

    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = context.read<ProfileViewModel>().userProfile;
      final vm = _vm;

      if (user != null && vm != null) {
        await vm.initialize(user.userId);

        if (!mounted) return;
        await _precacheAvatarImages(vm.visibleStoreItems);
      }
    });
  }

  Future<void> _precacheAvatarImages(List<StoreItem> items) async {
    final futures = <Future<void>>[];

    for (final item in items) {
      if (item.isAvatar && item.assetPath.isNotEmpty) {
        futures.add(
          precacheImage(AssetImage(item.assetPath), context).catchError((_) {}),
        );
      }
    }

    await Future.wait(futures);
  }

  @override
  void deactivate() {
    final vm = _vm;
    if (vm != null) {
      unawaited(vm.closeStoreSession());
    }
    super.deactivate();
  }

  @override
  void dispose() {
    final vm = _vm;
    if (vm != null) {
      unawaited(vm.closeStoreSession());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final cardColor = Theme.of(context).cardColor;

    return PopScope(
      onPopInvokedWithResult: (_, __) {
        final vm = _vm;
        if (vm != null) {
          unawaited(vm.closeStoreSession());
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            'Reward Store',
            style: TextStyle(color: text, fontWeight: FontWeight.bold),
          ),
          iconTheme: IconThemeData(color: text),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: text),
            onPressed: () async {
              final vm = _vm;
              if (vm != null) {
                await vm.closeStoreSession();
              }
              if (!mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Consumer<RewardStoreViewModel>(
          builder: (context, vm, child) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupedItems = _groupAndSortItems(vm.visibleStoreItems);

            return Column(
              children: [
                _buildBalanceHeader(vm.currentPoints, accent),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      final user = context.read<ProfileViewModel>().userProfile;
                      if (user != null) {
                        await vm.refresh(user.userId);
                        if (!mounted) return;
                        await _precacheAvatarImages(vm.visibleStoreItems);
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (groupedItems['Avatar']!.isNotEmpty) ...[
                          _buildCategoryHeader('Avatar', Icons.face, text, accent),
                          const SizedBox(height: 12),
                          ...groupedItems['Avatar']!.map(
                                (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildStoreItemCard(
                                context: context,
                                item: item,
                                isClaimed: vm.isClaimed(item),
                                isSelected: vm.isSelected(item),
                                cardColor: cardColor,
                                textColor: text,
                                accent: accent,
                                vm: vm,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (groupedItems['Audio']!.isNotEmpty) ...[
                          _buildCategoryHeader(
                            'Audio',
                            Icons.play_circle_outline,
                            text,
                            accent,
                          ),
                          const SizedBox(height: 12),
                          ...groupedItems['Audio']!.map(
                                (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildStoreItemCard(
                                context: context,
                                item: item,
                                isClaimed: vm.isClaimed(item),
                                isSelected: vm.isSelected(item),
                                cardColor: cardColor,
                                textColor: text,
                                accent: accent,
                                vm: vm,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (groupedItems['Items']!.isNotEmpty) ...[
                          _buildCategoryHeader(
                            'Items',
                            Icons.inventory_2_outlined,
                            text,
                            accent,
                          ),
                          const SizedBox(height: 12),
                          ...groupedItems['Items']!.map(
                                (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _buildStoreItemCard(
                                context: context,
                                item: item,
                                isClaimed: vm.isClaimed(item),
                                isSelected: vm.isSelected(item),
                                cardColor: cardColor,
                                textColor: text,
                                accent: accent,
                                vm: vm,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<StoreItem>> _groupAndSortItems(List<StoreItem> items) {
    final grouped = <String, List<StoreItem>>{
      'Avatar': [],
      'Audio': [],
      'Items': [],
    };

    for (final item in items) {
      switch (item.type) {
        case StoreItemType.AVATAR:
          grouped['Avatar']!.add(item);
          break;
        case StoreItemType.AUDIO:
          grouped['Audio']!.add(item);
          break;
        case StoreItemType.ITEM:
        case StoreItemType.UNKNOWN:
          grouped['Items']!.add(item);
          break;
      }
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final costCompare = a.cost.compareTo(b.cost);
        if (costCompare != 0) return costCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    return grouped;
  }

  Widget _buildBalanceHeader(int points, Color accent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF60A5FA),
            Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Available Balance',
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
                '$points',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'pts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(
      String title,
      IconData icon,
      Color text,
      Color accent,
      ) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreItemCard({
    required BuildContext context,
    required StoreItem item,
    required bool isClaimed,
    required bool isSelected,
    required Color cardColor,
    required Color textColor,
    required Color accent,
    required RewardStoreViewModel vm,
  }) {
    return GestureDetector(
      onTap: () => vm.selectItem(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : textColor.withOpacity(0.08),
            width: isSelected ? 2 : 1,
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
            _buildLeadingVisual(context, item, accent, vm),
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
                    '${item.cost} pts',
                    style: TextStyle(
                      color: textColor.withOpacity(0.65),
                      fontWeight: FontWeight.w600,
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
                  if (item.isConsumableShield && vm.getItemQuantity(item) > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Owned: ${vm.getItemQuantity(item)}',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildActionButton(
              context: context,
              item: item,
              isClaimed: isClaimed,
              vm: vm,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingVisual(
      BuildContext context,
      StoreItem item,
      Color accent,
      RewardStoreViewModel vm,
      ) {
    if (item.isAvatar && item.assetPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 62,
          height: 62,
          child: Image.asset(
            item.assetPath,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            cacheWidth: 124,
            errorBuilder: (_, __, ___) {
              return Container(
                color: accent.withOpacity(0.08),
                alignment: Alignment.center,
                child: Icon(Icons.person, color: accent, size: 28),
              );
            },
          ),
        ),
      );
    }

    if (item.type == StoreItemType.AUDIO) {
      final isPlaying = vm.isPreviewing(item);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await vm.toggleAudioPreview(item);

            if (!context.mounted) return;
            if (vm.errorMessage != null) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(vm.errorMessage!),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
              color: isPlaying ? Colors.redAccent : accent,
              size: 30,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        _iconForType(item.type),
        color: accent,
        size: 28,
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required StoreItem item,
    required bool isClaimed,
    required RewardStoreViewModel vm,
    required Color accent,
  }) {
    if (isClaimed) {
      return const Text(
        'Claimed',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: vm.isPurchasing
          ? null
          : () async {
        vm.selectItem(item);
        final success = await vm.purchaseSelectedItem();

        if (!context.mounted) return;

        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();

        if (success) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Reward Claimed Successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (vm.validationMessage != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(vm.validationMessage!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (vm.errorMessage != null) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(vm.errorMessage!),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: vm.isPurchasing && vm.isSelected(item)
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : const Text(
        'Redeem',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _iconForType(StoreItemType type) {
    switch (type) {
      case StoreItemType.AVATAR:
        return Icons.person;
      case StoreItemType.AUDIO:
        return Icons.play_circle_fill;
      case StoreItemType.ITEM:
        return Icons.inventory_2_outlined;
      case StoreItemType.UNKNOWN:
        return Icons.help_outline;
    }
  }

  String _subtitleForItem(StoreItem item) {
    switch (item.type) {
      case StoreItemType.AVATAR:
        return 'Avatar reward';
      case StoreItemType.AUDIO:
        return 'Audio reward';
      case StoreItemType.ITEM:
        if (item.protectDays > 0) {
          return 'Protects streak for ${item.protectDays} day(s)';
        }
        return 'Special reward item';
      case StoreItemType.UNKNOWN:
        return 'Reward item';
    }
  }
}