import 'package:flutter/material.dart';
import '../shared_state.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CaptionsOverlay extends StatelessWidget {
  const CaptionsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: MeetingController(),
      builder: (context, _) {
        final controller = MeetingController();
        if (!controller.isCaptionVisible) return const SizedBox.shrink();

        final originalText = controller.originalCaption;
        final translatedText = controller.translatedCaption;
        final selectedLanguage = controller.selectedCaptionLanguage;
        final errorText = controller.captionError;

        // Determine if we should show anything
        final hasText = (originalText != null && originalText.isNotEmpty) || (translatedText != null && translatedText.isNotEmpty);
        if (!hasText && errorText == null && !controller.isCapturing) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.7, // 70% width
                ),
                margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF080C14).withOpacity(0.88),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x3364748B), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Error Display
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFFB7185), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),

                    // Dropdowns (Minimal)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        const Text('Speak: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        DropdownButton<String>(
                          value: controller.selectedSpokenLanguage,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'en-US', child: Text('English')),
                            DropdownMenuItem(value: 'te-IN', child: Text('Telugu')),
                            DropdownMenuItem(value: 'hi-IN', child: Text('Hindi')),
                            DropdownMenuItem(value: 'ta-IN', child: Text('Tamil')),
                            DropdownMenuItem(value: 'kn-IN', child: Text('Kannada')),
                            DropdownMenuItem(value: 'ml-IN', child: Text('Malayalam')),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setSpokenLanguage(val);
                          },
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.g_translate, color: Colors.white54, size: 14),
                        const SizedBox(width: 4),
                        const Text('Translate: ', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        DropdownButton<String>(
                          value: selectedLanguage,
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English')),
                            DropdownMenuItem(value: 'te', child: Text('Telugu')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi')),
                            DropdownMenuItem(value: 'ta', child: Text('Tamil')),
                            DropdownMenuItem(value: 'kn', child: Text('Kannada')),
                            DropdownMenuItem(value: 'ml', child: Text('Malayalam')),
                          ],
                          onChanged: (val) {
                            if (val != null) controller.setCaptionLanguage(val);
                          },
                        ),
                      ],
                    ),

                    if (hasText) const SizedBox(height: 8),

                    // Caption Text Display
                    if (originalText != null && originalText.isNotEmpty)
                      Text(
                        originalText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    
                    if (translatedText != null && translatedText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        translatedText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],

                    if (!hasText && errorText == null && controller.isCapturing)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Listening...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2),
            );
          }
        );
      },
    );
  }
}
