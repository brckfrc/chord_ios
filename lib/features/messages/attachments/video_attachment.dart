import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'attachment_viewer.dart';
import '../../../utils/file_utils.dart';

/// Video attachment widget with thumbnail and player
class VideoAttachment extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final int? duration; // Duration in seconds
  final double? maxWidth;
  final double? maxHeight;

  const VideoAttachment({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.fileName,
    this.duration,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  State<VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<VideoAttachment> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _thumbnailUrl;
  double? _aspectRatio;

  @override
  void initState() {
    super.initState();
    _initializeThumbnail();
  }

  Future<void> _initializeThumbnail() async {
    // If thumbnail URL is provided, use it and get aspect ratio
    if (widget.thumbnailUrl != null) {
      setState(() {
        _thumbnailUrl = widget.thumbnailUrl;
        _isLoading = false;
      });
      
      // Get aspect ratio from thumbnail image
      final aspectRatio = await _getImageAspectRatio(widget.thumbnailUrl!);
      if (mounted) {
        setState(() {
          _aspectRatio = aspectRatio;
        });
      }
      return;
    }

    // Otherwise, try to get first frame from video
    try {
      final transformedUrl = FileUtils.transformMinioUrl(widget.videoUrl);
      _controller = VideoPlayerController.networkUrl(Uri.parse(transformedUrl));
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Get aspect ratio from video controller
          if (_controller!.value.isInitialized) {
            _aspectRatio = _controller!.value.aspectRatio;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Get aspect ratio from thumbnail image URL
  Future<double?> _getImageAspectRatio(String imageUrl) async {
    try {
      final transformedUrl = FileUtils.transformMinioUrl(imageUrl);
      final imageProvider = CachedNetworkImageProvider(transformedUrl);
      
      // Resolve image to get dimensions
      final imageStream = imageProvider.resolve(const ImageConfiguration());
      final completer = Completer<double?>();
      
      ImageStreamListener? listener;
      listener = ImageStreamListener((ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (width > 0 && height > 0) {
          completer.complete(width / height);
        } else {
          completer.complete(null);
        }
        imageStream.removeListener(listener!);
      }, onError: (exception, stackTrace) {
        completer.complete(null);
        imageStream.removeListener(listener!);
      });
      
      imageStream.addListener(listener);
      
      // Timeout after 5 seconds
      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          imageStream.removeListener(listener!);
          return null;
        },
      );
    } catch (e) {
      return null;
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build thumbnail content
    Widget thumbnailContent = _buildThumbnailContent(context);
    
    // Wrap in container with decoration
    Widget container = Container(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth ?? 400,
        maxHeight: widget.maxHeight ?? 300,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: thumbnailContent,
      ),
    );
    
    // Wrap in AspectRatio if we have aspect ratio information
    if (_aspectRatio != null && _aspectRatio! > 0) {
      container = AspectRatio(
        aspectRatio: _aspectRatio!,
        child: container,
      );
    }
    
    return GestureDetector(
      onTap: () {
        final transformedUrl = FileUtils.transformMinioUrl(widget.videoUrl);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AttachmentViewer(
              videoUrl: transformedUrl,
              fileName: widget.fileName,
            ),
          ),
        );
      },
      child: container,
    );
  }

  Widget _buildThumbnailContent(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail or video preview
        if (_isLoading)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          )
        else if (_thumbnailUrl != null)
          CachedNetworkImage(
            imageUrl: FileUtils.transformMinioUrl(_thumbnailUrl!),
            fit: BoxFit.contain,
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.videocam),
            ),
          )
        else if (_controller != null && _controller!.value.isInitialized)
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          )
        else
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.videocam),
          ),
        // Play button overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        // Duration badge
        if (widget.duration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(widget.duration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
