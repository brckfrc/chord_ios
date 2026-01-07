import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../repositories/invite_repository.dart';
import '../../core/config/app_config.dart';

/// Invite modal for inviting friends to guild
class InviteModal extends ConsumerStatefulWidget {
  final bool open;
  final void Function(bool) onOpenChange;
  final String guildId;

  const InviteModal({
    super.key,
    required this.open,
    required this.onOpenChange,
    required this.guildId,
  });

  @override
  ConsumerState<InviteModal> createState() => _InviteModalState();
}

class _InviteModalState extends ConsumerState<InviteModal> {
  String? _inviteCode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchInviteCode();
  }

  Future<void> _fetchInviteCode() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final repository = InviteRepository();
      final inviteInfo = await repository.createInvite(widget.guildId);
      
      // Build invite link using base URL
      final baseUrl = AppConfig.signalRUrl; // e.g., http://10.0.2.2:5049 or https://chord.borak.dev
      final inviteLink = '$baseUrl/invite/${inviteInfo.code}';
      
      if (mounted) {
        setState(() {
          _inviteCode = inviteLink;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        AppToast.showError(
          context, 
          'Failed to generate invite link: ${e.toString().replaceAll('Exception: ', '')}'
        );
      }
    }
  }

  Future<void> _copyInviteLink() async {
    if (_inviteCode == null) return;

    await Clipboard.setData(ClipboardData(text: _inviteCode!));
    if (mounted) {
      // Use root navigator context to show toast outside dialog
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      AppToast.showSuccess(rootContext, 'Invite link copied to clipboard!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Friends',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Share this link to invite friends to your server',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_inviteCode != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF1F2023)), // Darker gray separator
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          _inviteCode!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: _copyInviteLink,
                        tooltip: 'Copy link',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: 'Copy Link',
                    onPressed: _copyInviteLink,
                    icon: Icons.copy,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      widget.onOpenChange(false);
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
