import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/guild_provider.dart';
import '../../models/guild/create_guild_dto.dart';
import '../../shared/widgets/app_input.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';

/// Create guild modal
class CreateGuildModal extends ConsumerStatefulWidget {
  final bool open;
  final void Function(bool) onOpenChange;

  const CreateGuildModal({
    super.key,
    required this.open,
    required this.onOpenChange,
  });

  @override
  ConsumerState<CreateGuildModal> createState() => _CreateGuildModalState();
}

class _CreateGuildModalState extends ConsumerState<CreateGuildModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconUrlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dto = CreateGuildDto(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        iconUrl: _iconUrlController.text.trim().isEmpty
            ? null
            : _iconUrlController.text.trim(),
      );

      final guild = await ref.read(guildProvider.notifier).createGuild(dto);

      if (guild != null && mounted) {
        AppToast.showSuccess(context, 'Guild created successfully');
        _nameController.clear();
        _descriptionController.clear();
        _iconUrlController.clear();
        widget.onOpenChange(false);
      } else {
        if (mounted) {
          AppToast.showError(context, 'Failed to create guild');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString().replaceAll('Exception: ', ''));
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
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 320,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Guild',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                AppInput(
                  controller: _nameController,
                  label: 'Guild Name',
                  hint: 'Enter guild name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Guild name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Guild name must be at least 3 characters';
                    }
                    if (value.trim().length > 100) {
                      return 'Guild name must be less than 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _descriptionController,
                  label: 'Description (Optional)',
                  hint: 'Enter guild description',
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.trim().length > 500) {
                      return 'Description must be less than 500 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppInput(
                  controller: _iconUrlController,
                  label: 'Icon URL (Optional)',
                  hint: 'Enter icon URL',
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final uri = Uri.tryParse(value.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'Please enter a valid URL';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              widget.onOpenChange(false);
                            },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: AppButton(
                        text: 'Create',
                        onPressed: _isLoading ? null : _handleCreate,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
