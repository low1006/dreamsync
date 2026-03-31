import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';
import 'package:dreamsync/widget/custom/custom_bottom_sheet.dart';

class AddFriendDialog extends StatelessWidget {
  final Color bg;
  final Color surface;
  final Color text;
  final Color accent;

  const AddFriendDialog({
    super.key,
    required this.bg,
    required this.surface,
    required this.text,
    required this.accent,
  });

  static void show(
      BuildContext context, {
        required FriendViewModel viewModel,
        required Color bg,
        required Color surface,
        required Color text,
        required Color accent,
      }) {
    viewModel.searchedUser = null;
    viewModel.errorMessage = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: const _AddFriendSheetContent(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _AddFriendSheetContent extends StatefulWidget {
  const _AddFriendSheetContent();

  @override
  State<_AddFriendSheetContent> createState() => _AddFriendSheetContentState();
}

class _AddFriendSheetContentState extends State<_AddFriendSheetContent> {
  final _uidController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _uidController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      final model = context.read<FriendViewModel>();
      model.searchedUser = null;
      model.errorMessage = null;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 800), () async {
      final hasInternet = await NetworkHelper.hasInternet();
      NetworkHelper.isOffline.value = !hasInternet;

      if (!hasInternet) {
        if (mounted) {
          NetworkHelper.showOfflineSnackBar(
            context,
            message: 'User search is unavailable while offline.',
          );
        }
        return;
      }

      if (mounted) {
        context.read<FriendViewModel>().searchUserByUid("User#$cleanQuery");
      }
    });
  }

  void _clearSelection() {
    final model = context.read<FriendViewModel>();
    model.searchedUser = null;
    model.errorMessage = null;
    _uidController.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<FriendViewModel>();
    final themeText = AppTheme.text(context);
    final themeSubText = AppTheme.subText(context);
    final themeSurface = AppTheme.surface(context);
    final themeBorder = AppTheme.border(context);

    return CustomBottomSheet(
      title: 'Add Friend',
      icon: Icons.person_add,
      showBottomButton: false, // <-- This completely hides the generic Save button!
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ──
          TextField(
            controller: _uidController,
            focusNode: _searchFocus,
            autofocus: true,
            keyboardType: TextInputType.text,
            style: TextStyle(color: themeText),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Enter UID (e.g. 01B23C)',
              hintStyle: TextStyle(color: themeSubText),
              filled: true,
              fillColor: themeText.withOpacity(0.05),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "User#",
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              suffixIcon: model.isLoading
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              )
                  : _uidController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close, color: themeSubText),
                onPressed: _clearSelection,
              )
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          // ── Error Banner ──
          if (model.errorMessage != null && !model.isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.errorMessage!,
                      style:
                      const TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // ── Selected / Found User Chip with Inline Button ──
          if (model.searchedUser != null && !model.isLoading)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        avatarPath: model.searchedUser!.avatarAssetPath,
                        size: 48,
                        fallbackIconColor: AppTheme.accent,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.searchedUser!.username,
                              style: TextStyle(
                                color: themeText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              "UID: ${model.searchedUser!.uidText}",
                              style: TextStyle(
                                color: themeSubText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Inline Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getButtonColor(model.friendshipStatus),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: model.friendshipStatus == 'none'
                          ? () async {
                        final ok = await NetworkHelper.ensureInternet(
                          context,
                          message:
                          'You cannot send a friend request while offline.',
                        );
                        if (!ok) return;

                        await model.sendFriendRequestToSearchedUser();

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend request sent!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                          : null,
                      child: Text(
                        _getButtonText(model.friendshipStatus),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getButtonColor(String? status) {
    switch (status) {
      case 'accepted':
        return AppTheme.success;
      case 'pending':
        return AppTheme.warning;
      default:
        return AppTheme.accent;
    }
  }

  String _getButtonText(String? status) {
    switch (status) {
      case 'accepted':
        return "Already Friends";
      case 'pending':
        return "Request Sent";
      default:
        return "Add Friend";
    }
  }
}