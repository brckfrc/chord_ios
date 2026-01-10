import 'package:flutter/material.dart';
import '../../../utils/file_utils.dart';

/// Document attachment widget
class DocumentAttachment extends StatelessWidget {
  final String fileName;
  final int? fileSize;
  final String? contentType;
  final String? url;

  const DocumentAttachment({
    super.key,
    required this.fileName,
    this.fileSize,
    this.contentType,
    this.url,
  });

  IconData _getFileIcon(String? contentType) {
    if (contentType == null) return Icons.insert_drive_file;

    if (contentType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (contentType.contains('word') || contentType.contains('document')) {
      return Icons.description;
    } else if (contentType.contains('excel') || contentType.contains('spreadsheet')) {
      return Icons.table_chart;
    } else if (contentType.contains('zip') || contentType.contains('rar')) {
      return Icons.folder_zip;
    } else if (contentType.contains('text')) {
      return Icons.text_snippet;
    } else {
      return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(contentType),
            size: 32,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (fileSize != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    FileUtils.formatFileSize(fileSize!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (url != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () {
                // TODO: Implement download functionality
                // For now, just show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Download: $fileName'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
