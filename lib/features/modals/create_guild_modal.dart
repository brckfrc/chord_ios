import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/guild_provider.dart';
import '../../models/guild/create_guild_dto.dart';
import '../../models/invite/invite_info_dto.dart';
import '../../repositories/invite_repository.dart';
import '../../utils/invite_parser.dart';
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

class _CreateGuildModalState extends ConsumerState<CreateGuildModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  
  // Create tab controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconUrlController = TextEditingController();
  bool _isLoading = false;

  // Join tab controllers
  final _inviteCodeController = TextEditingController();
  InviteInfoDto? _inviteInfo;
  bool _isLoadingInfo = false;
  bool _isJoining = false;
  String? _joinError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging || _tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    _inviteCodeController.addListener(_onInviteCodeChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    _inviteCodeController.removeListener(_onInviteCodeChanged);
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _onInviteCodeChanged() {
    // Clear invite info when code changes
    if (_inviteInfo != null) {
      setState(() {
        _inviteInfo = null;
        _joinError = null;
      });
    }
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

  Future<void> _handleGetInviteInfo() async {
    final code = InviteParser.parseInviteCode(_inviteCodeController.text);
    
    if (code == null || !InviteParser.isValidInviteCode(code)) {
      setState(() {
        _joinError = 'Please enter a valid invite code or link';
        _inviteInfo = null;
      });
      return;
    }

    setState(() {
      _isLoadingInfo = true;
      _joinError = null;
      _inviteInfo = null;
    });

    try {
      final repository = InviteRepository();
      final info = await repository.getInviteInfo(code);

      if (mounted) {
        setState(() {
          _inviteInfo = info;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInfo = false;
          _joinError = e.toString().replaceAll('Exception: ', '');
          _inviteInfo = null;
        });
      }
    }
  }

  Future<void> _handleJoinGuild() async {
    final code = InviteParser.parseInviteCode(_inviteCodeController.text);
    if (code == null || !InviteParser.isValidInviteCode(code)) {
      setState(() {
        _joinError = 'Please enter a valid invite code or link';
      });
      return;
    }

    // If we don't have invite info, fetch it first
    if (_inviteInfo == null) {
      await _handleGetInviteInfo();
      if (_inviteInfo == null) {
        return; // Error already set
      }
    }

    setState(() {
      _isJoining = true;
      _joinError = null;
    });

    try {
      final guild = await ref.read(guildProvider.notifier).joinGuildByInvite(code);

      if (guild != null && mounted) {
        AppToast.showSuccess(context, 'Joined guild successfully');
        _inviteCodeController.clear();
        setState(() {
          _inviteInfo = null;
          _isJoining = false;
        });
        widget.onOpenChange(false);
      } else {
        if (mounted) {
          setState(() {
            _isJoining = false;
            _joinError = 'Failed to join guild';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _joinError = e.toString().replaceAll('Exception: ', '');
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
        child: IntrinsicHeight(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guild',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                // Tab Bar
                TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {
                      _selectedTabIndex = index;
                    });
                  },
                  tabs: const [
                    Tab(text: 'Create'),
                    Tab(text: 'Join'),
                  ],
                ),
                const SizedBox(height: 16),
                // Tab content - show/hide based on selected tab
                if (_selectedTabIndex == 0)
                  _buildCreateTab()
                else
                  _buildJoinTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            const SizedBox(height: 8), // Son objeden sonra hafif boşluk
          ],
        ),
    );
  }

  Widget _buildJoinTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            controller: _inviteCodeController,
            label: 'Invite Code or Link',
            hint: 'Enter invite code or link',
            onSubmitted: (_) => _handleGetInviteInfo(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isLoadingInfo
                    ? null
                    : () {
                        widget.onOpenChange(false);
                      },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: AppButton(
                  text: 'Get Info',
                  onPressed: _isLoadingInfo ? null : _handleGetInviteInfo,
                  isLoading: _isLoadingInfo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Error message
          if (_joinError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _joinError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Invite preview card
          if (_inviteInfo != null) ...[
            const SizedBox(height: 16),
            _buildInvitePreviewCard(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: 'Join Guild',
                onPressed: _isJoining ? null : _handleJoinGuild,
                isLoading: _isJoining,
              ),
            ),
            const SizedBox(height: 8), // Son objeden sonra hafif boşluk
          ],
        ],
      ),
    );
  }

  Widget _buildInvitePreviewCard() {
    if (_inviteInfo == null) return const SizedBox.shrink();

    final info = _inviteInfo!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Guild icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: info.guildIconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(
                          info.guildIconUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              info.guildName.isNotEmpty
                                  ? info.guildName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          info.guildName.isNotEmpty
                              ? info.guildName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.guildName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${info.memberCount} member${info.memberCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.createdBy != null) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Created by ${info.createdBy!.displayName ?? info.createdBy!.username}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ],
          if (info.isExpired || info.hasReachedMaxUses) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info.isExpired
                          ? 'This invite has expired'
                          : 'This invite has reached maximum uses',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
