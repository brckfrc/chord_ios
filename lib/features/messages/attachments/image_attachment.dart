import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'attachment_viewer.dart';
import '../../../utils/file_utils.dart';

/// Image attachment widget with thumbnail and full screen viewer
class ImageAttachment extends StatelessWidget {
  final String imageUrl;
  final String? fileName;
  final double? maxWidth;
  final double? maxHeight;

  const ImageAttachment({
    super.key,
    required this.imageUrl,
    this.fileName,
    this.maxWidth,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final transformedUrl = FileUtils.transformMinioUrl(imageUrl);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AttachmentViewer(
              imageUrl: transformedUrl,
              fileName: fileName,
            ),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 400,
          maxHeight: maxHeight ?? 300,
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
          child: CachedNetworkImage(
            imageUrl: FileUtils.transformMinioUrl(imageUrl),
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
