/// Stub for non-web platforms — these functions are no-ops.
String openFileInBrowser(String fileName, List<int> bytes) => '';
String createBlobUrl(String fileName, List<int> bytes) => '';
String getMimeType(String fileName) => 'application/octet-stream';
void registerIframeView(String viewType, String blobUrl, {String mimeType = ''}) {}
void revokeBlobUrl(String url) {}
