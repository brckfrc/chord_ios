import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/channel_provider.dart';
import '../../models/guild/create_channel_dto.dart';
import '../../models/guild/channel_type.dart';
import '../../shared/widgets/app_input.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';

/// Create channel modal
class CreateChannelModal extends ConsumerStatefulWidget {
  final bool open;
  final void Function(bool) onOpenChange;
  final String guildId;
  final ChannelType defaultChannelType;

  const CreateChannelModal({
    super.key,
    required this.open,
    required this.onOpenChange,
    required this.guildId,
    this.defaultChannelType = ChannelType.text,
  });

  @override
  ConsumerState<CreateChannelModal> createState() => _CreateChannelModalState();
}

class _CreateChannelModalState extends ConsumerState<CreateChannelModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _topicController = TextEditingController();
  late ChannelType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.defaultChannelType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
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
      final dto = CreateChannelDto(
        name: _nameController.text.trim(),
        type: _selectedType,
        topic: _topicController.text.trim().isEmpty
            ? null
            : _topicController.text.trim(),
      );

      final channel = await ref
          .read(channelProvider.notifier)
          .createChannel(widget.guildId, dto);

      if (channel != null && mounted) {
        AppToast.showSuccess(context, 'Channel created successfully');
        _nameController.clear();
        _topicController.clear();
        widget.onOpenChange(false);
      } else {
        if (mounted) {
          AppToast.showError(context, 'Failed to create channel');
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
          maxWidth: 400,
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
                'Create Channel',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              AppInput(
                controller: _nameController,
                label: 'Channel Name',
                hint: 'Enter channel name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Channel name is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Channel name must be at least 3 characters';
                  }
                  if (value.trim().length > 100) {
                    return 'Channel name must be less than 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Channel Type Selection
              Text(
                'Channel Type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<ChannelType>(
                      title: const Text('Text'),
                      value: ChannelType.text,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<ChannelType>(
                      title: const Text('Announcement'),
                      value: ChannelType.announcement,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<ChannelType>(
                      title: const Text('Voice'),
                      value: ChannelType.voice,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                          });
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppInput(
                controller: _topicController,
                label: 'Topic (Optional)',
                hint: 'Enter channel topic',
                maxLines: 2,
                validator: (value) {
                  if (value != null && value.trim().length > 500) {
                    return 'Topic must be less than 500 characters';
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

