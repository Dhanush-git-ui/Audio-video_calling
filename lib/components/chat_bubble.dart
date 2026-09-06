import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
<<<<<<< HEAD
import 'dart:convert';
import '../shared_state.dart';
=======
import 'dart:math';
import '../shared_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
>>>>>>> origin/main

/// Formats a file size in bytes to a human-readable string.
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Returns icon and accent color for a given file type.
(IconData, Color) _fileIconAndColor(ChatFileType type) {
  switch (type) {
    case ChatFileType.pdf:
      return (Icons.picture_as_pdf_rounded, const Color(0xFFEF4444));
<<<<<<< HEAD
    case ChatFileType.textDoc:
      return (Icons.article_outlined, const Color(0xFF818CF8));
=======
>>>>>>> origin/main
    case ChatFileType.word:
      return (Icons.description_rounded, const Color(0xFF3B82F6));
    case ChatFileType.excel:
      return (Icons.table_chart_rounded, const Color(0xFF22C55E));
    case ChatFileType.powerpoint:
      return (Icons.slideshow_rounded, const Color(0xFFF97316));
    case ChatFileType.audio:
      return (Icons.audio_file_rounded, const Color(0xFFA855F7));
    case ChatFileType.video:
      return (Icons.video_file_rounded, const Color(0xFF06B6D4));
    case ChatFileType.medical:
      return (Icons.medical_information_rounded, const Color(0xFF10B981));
    case ChatFileType.zip:
      return (Icons.folder_zip_rounded, const Color(0xFFF59E0B));
    default:
      return (Icons.attach_file_rounded, const Color(0xFF94A3B8));
  }
}

<<<<<<< HEAD
/// Opens a view-only full-screen image viewer dialog (NO download option).
=======
/// Downloads a file using the browser anchor trick (web only).
void _downloadFile(String fileName, Uint8List bytes) {
  if (!kIsWeb) return;
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Opens a full-screen image viewer dialog.
>>>>>>> origin/main
void _showFullScreenImage(BuildContext context, Uint8List bytes, String? fileName) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
<<<<<<< HEAD
    builder: (dialogContext) => Dialog(
=======
    builder: (_) => Dialog(
>>>>>>> origin/main
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
<<<<<<< HEAD
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          if (fileName != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Opens a view-only text document viewer dialog (NO download option).
void _showTextDocViewer(BuildContext context, String fileName, Uint8List bytes) {
  final content = utf8.decode(bytes, allowMalformed: true);
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: const Color(0xFF1E293B),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.article_outlined, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(dialogContext).pop(),
=======
            top: 8, right: 8,
            child: Row(
              children: [
                if (fileName != null)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Download',
                    onPressed: () => _downloadFile(fileName, bytes),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
>>>>>>> origin/main
                ),
              ],
            ),
          ),
<<<<<<< HEAD
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: const TextStyle(color: Color(0xFFE2E8F0), fontFamily: 'monospace', fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
=======
>>>>>>> origin/main
        ],
      ),
    ),
  );
}

<<<<<<< HEAD
/// A rich chat bubble that renders text, images, and file attachments appropriately (Strictly View-Only).
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onOpenFile;

  const ChatBubble({super.key, required this.message, this.onOpenFile});
=======
/// A rich chat bubble that renders text, images, and file attachments appropriately.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const ChatBubble({super.key, required this.message});
>>>>>>> origin/main

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? const Color(0xFF4F46E5) : const Color(0xFF1E293B);
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
<<<<<<< HEAD
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
=======
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name (only for received messages in a group)
>>>>>>> origin/main
            if (!isMe && message.senderName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
<<<<<<< HEAD
                    color: Color(0xFF818CF8),
=======
                    color: Color(0xFF6366F1),
>>>>>>> origin/main
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
<<<<<<< HEAD
=======
            // Bubble
>>>>>>> origin/main
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
<<<<<<< HEAD
                    color: Colors.black.withOpacity(0.2),
=======
                    color: Colors.black.withValues(alpha: 0.2),
>>>>>>> origin/main
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.fileType) {
      case ChatFileType.image:
        return _buildImageContent(context);
<<<<<<< HEAD
      case ChatFileType.textDoc:
        return _buildTextDocContent(context);
=======
>>>>>>> origin/main
      case ChatFileType.text:
        return _buildTextContent();
      default:
        return _buildFileContent(context);
    }
  }

  /// Plain text message bubble.
  Widget _buildTextContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
<<<<<<< HEAD
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
=======
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
>>>>>>> origin/main
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  /// Image bubble with in-app preview and tap-to-fullscreen zoom.
=======
  /// Image bubble with tap-to-fullscreen.
>>>>>>> origin/main
  Widget _buildImageContent(BuildContext context) {
    final bytes = message.fileBytes;
    if (bytes == null) return _buildTextContent();
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _showFullScreenImage(context, bytes, message.fileName),
<<<<<<< HEAD
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: 240,
                    height: 160,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
=======
            child: Hero(
              tag: message.id,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      width: 240,
                      height: 180,
                      gaplessPlayback: true,
                    ),
                    Positioned(
                      bottom: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
>>>>>>> origin/main
              ),
            ),
          ),
          if (message.fileName != null && message.fileName != 'whiteboard.png')
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text(
                message.fileName!,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
<<<<<<< HEAD
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
                  ),
                const Spacer(),
                Text(
                  message.time,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
=======
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _downloadFile(message.fileName ?? 'image.png', bytes),
                  child: const Tooltip(
                    message: 'Download',
                    child: Icon(Icons.download_rounded, color: Colors.white54, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  message.time,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
>>>>>>> origin/main
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

<<<<<<< HEAD
  /// Text Document snippet inline preview with tap-to-expand full viewer.
  Widget _buildTextDocContent(BuildContext context) {
    final bytes = message.fileBytes;
    final snippet = bytes != null
        ? utf8.decode(bytes.take(300).toList(), allowMalformed: true)
        : '';

    return GestureDetector(
      onTap: () {
        if (bytes != null) {
          _showTextDocViewer(context, message.fileName ?? 'Text Document', bytes);
        } else if (onOpenFile != null) {
          onOpenFile!();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF818CF8).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article_outlined, color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.fileName ?? message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (snippet.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: 220,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  snippet,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontFamily: 'monospace', height: 1.3),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
                  ),
                const SizedBox(width: 8),
                const Text(
                  'Tap to view preview',
                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  message.time,
                  style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Generic file attachment bubble (PDF, Word, Audio, etc.) with in-app preview on tap.
  Widget _buildFileContent(BuildContext context) {
    final (icon, color) = _fileIconAndColor(message.fileType);

    return GestureDetector(
      onTap: onOpenFile,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (message.fileSize != null)
                        Text(
                          _formatFileSize(message.fileSize!),
                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                        ),
                      const SizedBox(width: 8),
                      const Text(
                        'View Preview',
                        style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        message.time,
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
=======
  /// Generic file attachment bubble (PDF, Word, Audio, etc.).
  Widget _buildFileContent(BuildContext context) {
    final (icon, color) = _fileIconAndColor(message.fileType);
    final bytes = message.fileBytes;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (message.fileSize != null)
                      Text(
                        _formatFileSize(message.fileSize!),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                      ),
                    const Spacer(),
                    Text(
                      message.time,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (bytes != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _downloadFile(message.fileName ?? 'file', bytes),
              child: Tooltip(
                message: 'Download',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.download_rounded, color: Colors.white70, size: 16),
                ),
              ),
            ),
          ],
        ],
>>>>>>> origin/main
      ),
    );
  }
}
<<<<<<< HEAD

=======
>>>>>>> origin/main
