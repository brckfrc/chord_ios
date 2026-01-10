import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/message_provider.dart';
import '../../providers/signalr/chat_hub_provider.dart';
import '../../models/message/create_message_dto.dart';
import '../../providers/auth_provider.dart';
import '../../models/auth/user_dto.dart';
import '../../models/guild/guild_member_dto.dart';
import '../../repositories/guild_repository.dart';
import '../../repositories/upload_repository.dart';
import '../../models/upload/upload_response_dto.dart';
import '../../utils/file_utils.dart';
import 'attachments/upload_progress_indicator.dart';

/// Message composer widget with typing indicator and @ mention autocomplete
class MessageComposer extends ConsumerStatefulWidget {
  final String channelId;
  final String? guildId; // Optional for DM support

  const MessageComposer({
    super.key,
    required this.channelId,
    this.guildId, // Optional - null for DMs
  });

  @override
  ConsumerState<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends ConsumerState<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  Timer? _typingTimer;
  final ImagePicker _imagePicker = ImagePicker();
  final UploadRepository _uploadRepository = UploadRepository();

  // Mention autocomplete state
  List<GuildMemberDto> _guildMembers = [];
  bool _isLoadingMembers = false;
  String? _mentionQuery;
  int? _mentionStartIndex;
  int _selectedMentionIndex = 0;
  final LayerLink _mentionLayerLink = LayerLink();
  OverlayEntry? _overlayEntry; // Overlay entry'yi state'te tut

  // File upload state
  List<XFile> _selectedFiles = [];
  List<UploadResponseDto> _uploadedAttachments = [];
  Map<String, double> _uploadProgress =
      {}; // file path -> progress (0.0 to 1.0)
  Map<String, bool> _uploadErrors = {}; // file path -> has error

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Only load guild members if guildId is provided (not a DM)
    if (widget.guildId != null) {
      _loadGuildMembers();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _removeOverlay(); // Overlay'i temizle
    super.dispose();
  }

  /// Load guild members for mention autocomplete
  Future<void> _loadGuildMembers() async {
    if (_isLoadingMembers || widget.guildId == null) return;

    setState(() {
      _isLoadingMembers = true;
    });

    try {
      final repository = GuildRepository();
      final members = await repository.getGuildMembers(widget.guildId!);

      if (mounted) {
        setState(() {
          _guildMembers = members;
          _isLoadingMembers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMembers = false;
        });
      }
    }
  }

  /// Remove overlay entry
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  /// Show overlay entry
  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            child: CompositedTransformFollower(
              link: _mentionLayerLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.bottomLeft,
              targetAnchor: Alignment.topLeft,
              offset: const Offset(0, -4), // Boşluğu azalttık
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 200, // Minimum genişlik
                    maxWidth:
                        MediaQuery.of(context).size.width *
                        0.75, // Genişliği biraz azalttık
                    maxHeight: 200,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 200,
                    ),
                    width: double.infinity,
                    child: _getFilteredMembers().isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ), // Padding'leri azalttık
                            child: Text(
                              'No members found',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _getFilteredMembers().length,
                            itemBuilder: (context, index) {
                              final member = _getFilteredMembers()[index];
                              final isSelected = index == _selectedMentionIndex;
                              return InkWell(
                                onTap: () => _insertMention(member),
                                child: Container(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest
                                      : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, // Padding'leri azalttık
                                    vertical: 8, // Padding'leri azalttık
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize
                                        .min, // İçeriğe göre genişlik
                                    children: [
                                      CircleAvatar(
                                        radius:
                                            14, // Avatar boyutunu biraz küçülttük
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer,
                                        backgroundImage:
                                            member.user?.avatarUrl != null
                                            ? NetworkImage(
                                                member.user!.avatarUrl!,
                                              )
                                            : null,
                                        child: member.user?.avatarUrl == null
                                            ? Text(
                                                member.displayName.isNotEmpty
                                                    ? member.displayName[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
                                                  fontSize:
                                                      11, // Font boyutunu küçülttük
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ), // Boşluğu azalttık
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              member.displayName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize:
                                                    14, // Font boyutunu küçülttük
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '@${member.username}',
                                              style: TextStyle(
                                                fontSize:
                                                    11, // Font boyutunu küçülttük
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String _formatTypingIndicator(List<UserDto> users) {
    if (users.isEmpty) return '';

    final names = users
        .map((user) => user.displayName ?? user.username)
        .toList();

    if (names.length == 1) {
      return '${names[0]} is typing...';
    } else if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing...';
    } else {
      return '${names[0]}, ${names[1]} and ${names.length - 2} others are typing...';
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPosition = selection.baseOffset;

    // Send typing indicator
    _sendTypingIndicator();

    // Cancel previous timer
    _typingTimer?.cancel();

    // Set timer to stop typing indicator after 3 seconds
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _stopTypingIndicator();
    });

    // Check for @ mention pattern (only if guildId is provided, not for DMs)
    if (widget.guildId != null && cursorPosition > 0) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final mentionMatch = RegExp(r'@(\w*)$').firstMatch(textBeforeCursor);

      if (mentionMatch != null) {
        final matchIndex = textBeforeCursor.lastIndexOf('@');
        setState(() {
          _mentionStartIndex = matchIndex;
          _mentionQuery = mentionMatch.group(1) ?? '';
          _selectedMentionIndex = 0;
        });
        // Overlay'i göster
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showOverlay();
        });
      } else {
        setState(() {
          _mentionStartIndex = null;
          _mentionQuery = null;
        });
        // Overlay'i kaldır
        _removeOverlay();
      }
    } else {
      setState(() {
        _mentionStartIndex = null;
        _mentionQuery = null;
      });
      // Overlay'i kaldır
      _removeOverlay();
    }
  }

  Future<void> _sendTypingIndicator() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      final chatHubState = ref.read(chatHubProvider);

      // Connection yoksa başlatmayı dene
      if (!chatHubState.isConnected) {
        await chatHub.start();
        // Tekrar kontrol et
        final newState = ref.read(chatHubProvider);
        if (!newState.isConnected) {
          return;
        }
      }

      // Use DM typing methods if guildId is null (DM), otherwise use channel typing
      if (widget.guildId == null) {
        await chatHub.typingInDM(widget.channelId);
      } else {
        // Backend'deki method ismi: Typing (SendTyping değil)
        await chatHub.invoke('Typing', args: [widget.channelId]);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _stopTypingIndicator() async {
    try {
      final chatHub = ref.read(chatHubProvider.notifier);
      final chatHubState = ref.read(chatHubProvider);

      // Connection yoksa başlatmayı dene
      if (!chatHubState.isConnected) {
        await chatHub.start();
        // Tekrar kontrol et
        final newState = ref.read(chatHubProvider);
        if (!newState.isConnected) {
          return;
        }
      }

      // Use DM typing methods if guildId is null (DM), otherwise use channel typing
      if (widget.guildId == null) {
        await chatHub.stopTypingInDM(widget.channelId);
      } else {
        await chatHub.invoke('StopTyping', args: [widget.channelId]);
      }
    } catch (e) {
      // Ignore errors
    }
  }

  /// Insert mention into text
  void _insertMention(GuildMemberDto member) {
    if (_mentionStartIndex == null) return;

    final username = member.username;
    final beforeMention = _controller.text.substring(0, _mentionStartIndex!);
    final afterMention = _controller.text.substring(
      _controller.selection.baseOffset,
    );
    final newContent = '$beforeMention@$username $afterMention';

    _controller.value = TextEditingValue(
      text: newContent,
      selection: TextSelection.collapsed(
        offset:
            beforeMention.length + username.length + 2, // +2 for @ and space
      ),
    );

    setState(() {
      _mentionStartIndex = null;
      _mentionQuery = null;
    });
    // Overlay'i kaldır
    _removeOverlay();
  }

  /// Get filtered members for autocomplete
  List<GuildMemberDto> _getFilteredMembers() {
    // Get current user ID to filter out self
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id;

    // Filter out current user from members
    final filteredMembers = _guildMembers.where((member) {
      return member.user?.id != currentUserId;
    }).toList();

    if (_mentionQuery == null || _mentionQuery!.isEmpty) {
      return filteredMembers.take(10).toList();
    }

    final query = _mentionQuery!.toLowerCase();
    return filteredMembers
        .where((member) {
          final username = member.username.toLowerCase();
          final displayName = member.displayName.toLowerCase();
          return username.startsWith(query) || displayName.startsWith(query);
        })
        .take(10)
        .toList();
  }

  /// Pick files from gallery or camera
  Future<void> _pickFiles() async {
    try {
      // Show bottom sheet for selection
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick multiple files (for gallery) or single file (for camera)
      final List<XFile> pickedFiles;
      if (source == ImageSource.gallery) {
        pickedFiles = await _imagePicker.pickMultipleMedia();
      } else {
        final file = await _imagePicker.pickImage(source: source);
        pickedFiles = file != null ? [file] : [];
      }

      if (pickedFiles.isEmpty) return;

      // Validate file sizes
      final validFiles = <XFile>[];
      for (final file in pickedFiles) {
        final fileSize = await file.length();
        if (fileSize > 25 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${file.name} exceeds 25MB limit'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        } else {
          validFiles.add(file);
        }
      }

      if (validFiles.isEmpty) return;

      setState(() {
        _selectedFiles.addAll(validFiles);
        // Initialize progress for new files
        for (final file in validFiles) {
          _uploadProgress[file.path] = 0.0;
          _uploadErrors[file.path] = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick files: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Build file preview widget based on file type
  Widget _buildFilePreview(XFile file) {
    final fileType = FileUtils.getFileType(file.mimeType);
    
    switch (fileType) {
      case 'image':
        return Image.file(
          File(file.path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image),
        );
      case 'video':
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.videocam),
        );
      case 'document':
      default:
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.insert_drive_file),
        );
    }
  }

  /// Remove selected file
  void _removeFile(XFile file) {
    setState(() {
      _selectedFiles.remove(file);
      _uploadProgress.remove(file.path);
      _uploadErrors.remove(file.path);
    });
  }

  /// Upload all selected files
  /// Returns list of uploaded attachments (not IDs, since backend doesn't use IDs)
  Future<void> _uploadFiles() async {
    for (final file in _selectedFiles) {
      if (_uploadErrors[file.path] == true) continue; // Skip files with errors

      try {
        final uploadResponse = await _uploadRepository.uploadFile(
          File(file.path),
          onProgress: (sent, total) {
            if (mounted) {
              setState(() {
                _uploadProgress[file.path] = sent / total;
              });
            }
          },
        );

        setState(() {
          _uploadedAttachments.add(uploadResponse);
          _uploadProgress[file.path] = 1.0;
        });
      } catch (e) {
        setState(() {
          _uploadErrors[file.path] = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload ${file.name}: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    // If mention autocomplete is open, close it first
    if (_mentionStartIndex != null) {
      setState(() {
        _mentionStartIndex = null;
        _mentionQuery = null;
      });
      _removeOverlay();
      return;
    }

    final content = _controller.text.trim();
    if (content.isEmpty && _selectedFiles.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      // Upload files first if any
      if (_selectedFiles.isNotEmpty) {
        await _uploadFiles();
      }

      // Create attachments JSON string from uploaded files
      String? attachmentsJson;
      if (_uploadedAttachments.isNotEmpty) {
        print(
          '📎 [MessageComposer] Creating attachments JSON from ${_uploadedAttachments.length} uploaded files',
        );
        final attachmentsList = _uploadedAttachments.map((upload) {
          final attachmentData = {
            'url': upload.url,
            'type': upload.type ?? 'document',
            'size': upload.size ?? 0,
            'name': upload.name ?? '',
            if (upload.duration != null) 'duration': upload.duration,
          };
          print('📎 [MessageComposer] Attachment data: $attachmentData');
          return attachmentData;
        }).toList();
        attachmentsJson = jsonEncode(attachmentsList);
        print('📎 [MessageComposer] Attachments JSON string: $attachmentsJson');
      } else {
        print('📎 [MessageComposer] No uploaded attachments');
      }

      // Ensure content has at least 1 character when attachments are present
      // Backend requires MinimumLength = 1 even with attachments
      // Use zero-width space (\u200B) instead of regular space because ASP.NET Core
      // model validation may trim or reject regular spaces
      String finalContent = content;
      if (finalContent.isEmpty && _uploadedAttachments.isNotEmpty) {
        finalContent =
            "\u200B"; // Zero-width space: invisible but satisfies backend validation
        print(
          '📝 [MessageComposer] Content was empty, using zero-width space for attachment-only message',
        );
      }

      final dto = CreateMessageDto(
        content: finalContent,
        attachments: attachmentsJson,
      );

      print('📤 [MessageComposer] Sending message with DTO: ${dto.toJson()}');

      // Use DM message methods if guildId is null (DM), otherwise use channel message
      if (widget.guildId == null) {
        await ref
            .read(messageProvider.notifier)
            .createDMMessage(widget.channelId, dto);
      } else {
        await ref
            .read(messageProvider.notifier)
            .createMessage(widget.channelId, dto);
      }

      // Clear state after successful send
      _controller.clear();
      setState(() {
        _selectedFiles.clear();
        _uploadedAttachments.clear();
        _uploadProgress.clear();
        _uploadErrors.clear();
      });
      _stopTypingIndicator();
    } catch (e) {
      // Show error toast or handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageState = ref.watch(messageProvider);
    final typingUsers = messageState.getTypingUsers(widget.channelId);
    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?.id;

    // Filter out current user from typing users
    final otherTypingUsers = typingUsers
        .where((user) => user.id != currentUserId)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Typing indicator
        if (otherTypingUsers.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatTypingIndicator(otherTypingUsers),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          ),
        // File previews and upload progress
        if (_selectedFiles.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preview grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedFiles.map((file) {
                    final progress = _uploadProgress[file.path] ?? 0.0;
                    final hasError = _uploadErrors[file.path] ?? false;
                    return Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasError
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(
                                      context,
                                    ).colorScheme.outline.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildFilePreview(file),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeFile(file),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Progress indicator
                        if (progress > 0.0 && progress < 1.0 && !hasError)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.black.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        // Error indicator
                        if (hasError)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.error,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
                // Upload progress indicators
                if (_uploadProgress.values.any((p) => p > 0.0 && p < 1.0))
                  ..._selectedFiles
                      .where(
                        (file) =>
                            (_uploadProgress[file.path] ?? 0.0) > 0.0 &&
                            (_uploadProgress[file.path] ?? 0.0) < 1.0,
                      )
                      .map(
                        (file) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: UploadProgressIndicator(
                            progress: _uploadProgress[file.path] ?? 0.0,
                            fileName: file.name,
                            onCancel: () => _removeFile(file),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Color(0xFF1F2023), // Darker gray separator
                width: 1,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Upload button
              IconButton(
                onPressed: _isSending ? null : _pickFiles,
                icon: const Icon(Icons.attach_file),
                tooltip: 'Attach file',
              ),
              const SizedBox(width: 4),
              // Text input
              Expanded(
                child: CompositedTransformTarget(
                  link: _mentionLayerLink,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      // If mention autocomplete is open, select first mention
                      if (_mentionStartIndex != null) {
                        final filtered = _getFilteredMembers();
                        if (filtered.isNotEmpty) {
                          _insertMention(filtered[_selectedMentionIndex]);
                          return;
                        }
                      }
                      _sendMessage();
                    },
                    decoration: InputDecoration(
                      hintText: widget.guildId == null
                          ? 'Message...'
                          : 'Message #channel',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send button
              IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
