// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// MIME types that all major browsers can render natively in a tab.
/// Any type NOT in this set would trigger a download dialog — which we
/// want to avoid, so we block those and surface a "can't preview" message.
const _browserRenderableMimeTypes = {
  // Documents
  'application/pdf',
  // Images
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
  'image/svg+xml',
  'image/bmp',
  'image/x-icon',
  // Text
  'text/plain',
  'text/html',
  'text/csv',
  'application/json',
  // Audio
  'audio/mpeg',
  'audio/wav',
  'audio/ogg',
  // Video
  'video/mp4',
  'video/webm',
  'video/quicktime',
};

/// Maps common file extensions to their MIME types.
String _mimeTypeForFileName(String fileName) {
  final ext =
      fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  const map = {
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
    'bmp': 'image/bmp',
    'ico': 'image/x-icon',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'html': 'text/html',
    'htm': 'text/html',
    'json': 'application/json',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
    // Non-renderable — listed so MIME is known but tab will NOT be opened
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'rar': 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
  };
  return map[ext] ?? 'application/octet-stream';
}

/// Opens [bytes] in a new browser tab **only if the browser can render it**.
///
/// - Renderable types (PDF, images, audio, video, plain text): opens a new
///   tab with the correct MIME type so the browser displays it inline.
/// - Non-renderable types (DOCX, XLSX, ZIP, …): returns an empty string
///   without opening any tab or triggering a download.
///
/// Returns the Blob URL on success (caller must revoke it later),
/// or an empty string if the file type cannot be previewed.
String openFileInBrowser(String fileName, List<int> bytes) {
  final mimeType = _mimeTypeForFileName(fileName);

  // Block non-renderable types — opening them would trigger a download dialog.
  if (!_browserRenderableMimeTypes.contains(mimeType)) {
    return ''; // signal to caller: "can't preview this type"
  }

  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  return url; // caller must call revokeBlobUrl(url) to free memory
}

/// Creates a Blob URL from [bytes] **without** opening a new browser tab.
///
/// Returns the Blob URL string (caller must revoke it later via
/// [revokeBlobUrl]), or an empty string if the file type is not
/// browser-renderable.
String createBlobUrl(String fileName, List<int> bytes) {
  final mimeType = _mimeTypeForFileName(fileName);
  if (!_browserRenderableMimeTypes.contains(mimeType)) {
    return '';
  }
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Returns the MIME type string for the given [fileName].
String getMimeType(String fileName) => _mimeTypeForFileName(fileName);

/// Registers a platform view factory that creates an `<iframe>` pointing to
/// [blobUrl]. The iframe fills its parent container and has no border.
///
/// [viewType] must be unique per preview instance (e.g. include a timestamp).
/// [mimeType] is used to apply type-specific tweaks (e.g. hiding Chrome's
/// built-in PDF toolbar by appending `#toolbar=0&navpanes=0`).
void registerIframeView(String viewType, String blobUrl, {String mimeType = ''}) {
  // For PDFs, append fragment to hide Chrome's built-in PDF viewer toolbar
  // (download, print, rotate buttons). This does not affect other file types.
  final src = mimeType == 'application/pdf'
      ? '$blobUrl#toolbar=0&navpanes=0'
      : blobUrl;

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen';
    // Block right-click context menu on the iframe element itself
    iframe.onContextMenu.listen((e) => e.preventDefault());
    return iframe;
  });
}

/// Revokes [url], freeing the in-memory blob data.
void revokeBlobUrl(String url) {
  html.Url.revokeObjectUrl(url);
}
