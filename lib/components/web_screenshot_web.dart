// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

html.DivElement? _nativeOverlay;

/// Hides the native DOM overlay when the user returns to consultation.
void hideNativeWebOverlay() {
  _nativeOverlay?.style.display = 'none';
}

/// Web implementation using native HTML window streams, Keyboard events, DOM overlay, and Page Visibility API.
void setupWebScreenshotProtection({
  required void Function() onBlur,
  required void Function() onFocus,
}) {
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

  void triggerBlur() {
    overlay?.style.display = 'flex';
    onBlur();
  }

  void triggerFocus() {
    overlay?.style.display = 'none';
    onFocus();
  }

  // 2. Native DOM window blur & focus listeners (instant trigger on OS window focus loss / Snipping tool)
  html.window.onBlur.listen((_) => triggerBlur());
  html.window.onFocus.listen((_) => triggerFocus());

  // 3. Native DOM Page Visibility API listener
  html.document.onVisibilityChange.listen((_) {
    if (html.document.hidden == true) {
      triggerBlur();
    }
  });

  // 4. Native DOM level keydown listener for 0ms latency hardware keystroke detection in Chrome
  html.window.onKeyDown.listen((event) {
    final code = event.code ?? '';
    final key = event.key ?? '';
    final isCmdOrCtrl = event.ctrlKey || event.metaKey;
    final isShift = event.shiftKey;

    // PrintScreen key
    if (key == 'PrintScreen' || code == 'PrintScreen') {
      triggerBlur();
    }
    // Win+Shift+S or Ctrl+Shift+S (Snipping Tool)
    else if (isCmdOrCtrl && isShift && (key.toLowerCase() == 's' || code == 'KeyS')) {
      triggerBlur();
    }
    // Mac Screenshot shortcuts: Cmd+Shift+3, 4, 5
    else if (isCmdOrCtrl && isShift && (key == '3' || key == '4' || key == '5')) {
      triggerBlur();
    }
    // Ctrl+P / Cmd+P (Print context)
    else if (isCmdOrCtrl && (key.toLowerCase() == 'p' || code == 'KeyP')) {
      triggerBlur();
    }
  });
}
