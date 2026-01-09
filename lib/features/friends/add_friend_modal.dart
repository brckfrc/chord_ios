import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/friends_provider.dart';
import '../../shared/widgets/app_input.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';

/// Add Friend modal
class AddFriendModal extends ConsumerStatefulWidget {
  final bool open;
  final void Function(bool) onOpenChange;

  const AddFriendModal({
    super.key,
    required this.open,
    required this.onOpenChange,
  });

  @override
  ConsumerState<AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends ConsumerState<AddFriendModal> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _sendFriendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Note: Backend expects userId, but we're sending username
      // We'll need to search for user by username first, or backend should handle it
      // For now, assuming backend accepts username in the request
      final success = await ref.read(friendsProvider.notifier).sendFriendRequest(username);
      
      if (mounted) {
        if (success) {
          AppToast.showSuccess(context, 'Friend request sent to $username');
          _usernameController.clear();
          widget.onOpenChange(false);
        } else {
          final error = ref.read(friendsProvider).error;
          AppToast.showError(context, error ?? 'Failed to send friend request');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'Failed to send friend request: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.open) {
      return const SizedBox.shrink();
    }

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Add Friend',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => widget.onOpenChange(false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Username input
              AppInput(
                controller: _usernameController,
                label: 'Username',
                hint: 'Enter username',
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  return null;
                },
                onSubmitted: (_) => _sendFriendRequest(),
              ),
              const SizedBox(height: 24),
              // Send button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: 'Send Friend Request',
                  onPressed: _isLoading ? null : _sendFriendRequest,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
