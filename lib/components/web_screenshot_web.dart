// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

html.DivElement? _nativeOverlay;

/// Hides the native DOM overlay when the user returns to consultation.
void hideNativeWebOverlay() {
  _nativeOverlay?.style.display = 'none';
}

/// Injects a `<style>` element that blanks the entire page when browser
/// print is triggered (`Ctrl + P` / `Cmd + P`).  This is a last-resort
/// safeguard — even if the Flutter overlay is bypassed, the printed output
/// will be empty.
void _injectPrintProtectionCss() {
  const styleId = 'screenshot-protector-print-css';
  if (html.document.getElementById(styleId) != null) return;
  final style = html.StyleElement()
    ..id = styleId
    ..innerText =
        '@media print { html, body { display: none !important; visibility: hidden !important; } }';
  html.document.head?.append(style);
}

/// Web implementation using native HTML window streams, Keyboard events, DOM overlay, and Page Visibility API.
///
/// [onBlur] / [onFocus] are called for window focus changes (tab switch,
/// Alt+Tab, OS Snipping Tool activation, etc.).
///
/// [onScreenshotShortcut] is called when a screenshot/print keyboard shortcut
/// is detected (PrintScreen, Ctrl+P, Win+Shift+S, Cmd+Shift+3/4/5).  This
/// separate callback allows the caller to bypass preview-open guards so that
/// shortcut-based protection ALWAYS fires.
void setupWebScreenshotProtection({
  required void Function() onBlur,
  required void Function() onFocus,
  void Function()? onScreenshotShortcut,
}) {
  // 0. Inject CSS @media print rule so browser print outputs a blank page
  _injectPrintProtectionCss();

  // 1. Create or retrieve top-level native DOM overlay (0ms render overhead)
  var overlay = html.document.getElementById('native-security-overlay') as html.DivElement?;
  if (overlay == null) {
    overlay = html.DivElement()
      ..id = 'native-security-overlay'
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.98)'
      ..style.zIndex = '2147483647' // Maximum CSS z-index above all canvases
      ..style.display = 'none'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.color = '#ffffff'
      ..style.fontFamily = 'system-ui, -apple-system, sans-serif'
      ..style.fontSize = '24px'
      ..style.fontWeight = 'bold'
      ..innerText = 'SECURITY BLOCK ACTIVE';
    html.document.body?.append(overlay);
  }
  _nativeOverlay = overlay;

  // --- Trigger helpers ---------------------------------------------------

  /// Called on genuine window focus loss (tab switch, Alt+Tab, snipping tool).
  void triggerBlur() {
    overlay?.style.display = 'flex';
    onBlur();
  }

  void triggerFocus() {
    overlay?.style.display = 'none';
    onFocus();
  }

  /// Called when a screenshot/print keyboard shortcut is detected.
  /// Uses [onScreenshotShortcut] if provided, otherwise falls back to [onBlur].
  ///
  /// Unlike [triggerBlur] (window focus loss), keyboard shortcuts don't
  /// always cause a window blur→focus cycle, so the native overlay must
  /// auto-hide after a brief delay.  The 150 ms window is enough to
  /// block the captured frame, but then yields to Flutter's own overlay
  /// and warning dialog so the user can interact with the "Return to
  /// Consultation" button.
  void triggerScreenshotShortcut() {
    overlay?.style.display = 'flex';
    (onScreenshotShortcut ?? onBlur)();
    // Auto-hide native overlay so Flutter's warning dialog is accessible.
    // The Flutter-level _shouldBlurScreen overlay continues to protect
    // the content until the user explicitly dismisses the warning.
    Future.delayed(const Duration(milliseconds: 150), () {
      overlay?.style.display = 'none';
    });
  }

  // 2. Native DOM window blur & focus listeners (instant trigger on OS window focus loss / Snipping tool)
  //    IMPORTANT: When an in-app <iframe> (e.g. PDF preview via HtmlElementView)
  //    receives focus, the browser fires window.onBlur because focus moves into
  //    the iframe's separate browsing context. This is NOT a genuine tab/window
  //    switch — the user is still viewing our page. We detect this by checking
  //    document.activeElement after a microtask (it becomes the <iframe> element).
  html.window.onBlur.listen((_) {
    // Delay to let browser update activeElement before we inspect it.
    Future.delayed(const Duration(milliseconds: 50), () {
      final active = html.document.activeElement;
      // If the focused element is an iframe inside our page, this is an
      // internal focus shift (PDF viewer, embedded doc), NOT a security event.
      if (active != null && active.tagName.toLowerCase() == 'iframe') {
        return; // Suppress false positive — user is still on our page.
      }
      triggerBlur();
    });
  });
  html.window.onFocus.listen((_) => triggerFocus());

  // 3. Native DOM Page Visibility API listener
  html.document.onVisibilityChange.listen((_) {
    if (html.document.hidden == true) {
      triggerBlur();
    }
  });

  // 4. Native DOM level keydown listener for 0ms latency hardware keystroke detection in Chrome
  //    These ALWAYS use triggerScreenshotShortcut() so they bypass any
  //    "document preview is open" suppression logic in the Flutter layer.
  html.window.onKeyDown.listen((event) {
    final code = event.code ?? '';
    final key = event.key ?? '';
    final isCmdOrCtrl = event.ctrlKey || event.metaKey;
    final isShift = event.shiftKey;

    // PrintScreen key
    if (key == 'PrintScreen' || code == 'PrintScreen') {
      triggerScreenshotShortcut();
    }
    // Win+Shift+S or Ctrl+Shift+S (Snipping Tool)
    else if (isCmdOrCtrl && isShift && (key.toLowerCase() == 's' || code == 'KeyS')) {
      triggerScreenshotShortcut();
    }
    // Mac Screenshot shortcuts: Cmd+Shift+3, 4, 5
    else if (isCmdOrCtrl && isShift && (key == '3' || key == '4' || key == '5')) {
      triggerScreenshotShortcut();
    }
    // Ctrl+P / Cmd+P (Print context)
    else if (isCmdOrCtrl && (key.toLowerCase() == 'p' || code == 'KeyP')) {
      triggerScreenshotShortcut();
    }
  });
}

