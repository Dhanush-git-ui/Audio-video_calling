/// Stub for non-web platforms — no-op window blur listener setup.
void setupWebScreenshotProtection({
  required void Function() onBlur,
  required void Function() onFocus,
  void Function()? onScreenshotShortcut,
}) {}

void hideNativeWebOverlay() {}
