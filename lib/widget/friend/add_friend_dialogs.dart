import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';

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

    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: viewModel,
        child: AddFriendDialog(
          bg: bg,
          surface: surface,
          text: text,
          accent: accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FriendViewModel>(
      builder: (context, model, child) {
        return _AddFriendDialogContent(
          model: model,
          bg: bg,
          surface: surface,
          text: text,
          accent: accent,
        );
      },
    );
  }
}

class _AddFriendDialogContent extends StatefulWidget {
  final FriendViewModel model;
  final Color bg;
  final Color surface;
  final Color text;
  final Color accent;

  const _AddFriendDialogContent({
    required this.model,
    required this.bg,
    required this.surface,
    required this.text,
    required this.accent,
  });

  @override
  State<_AddFriendDialogContent> createState() =>
      _AddFriendDialogContentState();
}

class _AddFriendDialogContentState extends State<_AddFriendDialogContent> {
  final _uidController = TextEditingController();

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final bg = widget.bg;
    final surface = widget.surface;
    final text = widget.text;
    final accent = widget.accent;

    return AlertDialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        "Add Friend",
        style: TextStyle(color: text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: text.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _uidController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: "Enter UID (e.g. 1234)",
                hintStyle: TextStyle(color: text.withOpacity(0.4)),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    "User#",
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
                border: InputBorder.none,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (model.isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: accent),
            ),

          if (model.errorMessage != null && !model.isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                model.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),

          if (model.searchedUser != null && !model.isLoading)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(
                      avatarPath: model.searchedUser!.avatarAssetPath,
                      size: 44,
                      fallbackIconColor: accent,
                    ),
                    title: Text(
                      model.searchedUser!.username,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "UID: ${model.searchedUser!.uidText}",
                      style: TextStyle(
                        color: text.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        _getButtonColor(model.friendshipStatus, accent),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                      }
                          : null,
                      child: Text(_getButtonText(model.friendshipStatus)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            "Close",
            style: TextStyle(color: text.withOpacity(0.6)),
          ),
        ),
        if (model.searchedUser == null)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final input = _uidController.text.trim();
              if (input.isEmpty) return;

              final ok = await NetworkHelper.ensureInternet(
                context,
                message: 'You cannot search for friends while offline.',
              );
              if (!ok) return;

              model.searchUserByUid("User#$input");
            },
            child: const Text("Search"),
          ),
      ],
    );
  }

  Color _getButtonColor(String? status, Color accent) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return accent;
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