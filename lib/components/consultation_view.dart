import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'consultation_room.dart';
import 'clinical_panel.dart';

class ConsultationView extends StatefulWidget {
  const ConsultationView({super.key});

  @override
  State<ConsultationView> createState() => _ConsultationViewState();
}

class _ConsultationViewState extends State<ConsultationView> {
  String viewMode = 'split'; // 'split', 'form', 'video'

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        // Calculate positions and sizes based on viewMode
        double videoLeft = 16;
        double videoTop = 16;
        double videoWidth = 0;
        double videoHeight = 0;

        double formLeft = 0;
        double formTop = 16;
        double formWidth = 0;
        double formHeight = 0;
        
        bool isVideoPip = false;
        bool isFormPip = false;

        if (viewMode == 'split') {
          videoWidth = (screenWidth * 0.72) - 24;
          videoHeight = screenHeight - 32;
          formLeft = (screenWidth * 0.72) + 8;
          formWidth = (screenWidth * 0.28) - 24;
          formHeight = screenHeight - 32;
        } else if (viewMode == 'form') {
          formLeft = 16;
          formWidth = screenWidth - 32;
          formHeight = screenHeight - 32;
          
          videoWidth = 400;
          videoHeight = 280;
          videoLeft = screenWidth - videoWidth - 32;
          videoTop = screenHeight - videoHeight - 32;
          isVideoPip = true;
        } else if (viewMode == 'video') {
          videoWidth = screenWidth - 32;
          videoHeight = screenHeight - 32;
          
          formWidth = 240;
          formHeight = 160;
          formLeft = screenWidth - formWidth - 32;
          formTop = screenHeight - formHeight - 32;
          isFormPip = true;
        }

        return Stack(
          children: [
            // Video Background/Pane
            AnimatedPositioned(
              duration: 500.ms,
              curve: Curves.easeInOutCubic,
              left: videoLeft,
              top: videoTop,
              width: videoWidth,
              height: videoHeight,
              child: AnimatedContainer(
                duration: 500.ms,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isVideoPip ? [const BoxShadow(color: Colors.black54, blurRadius: 20)] : [],
                ),
                clipBehavior: Clip.antiAlias,
                child: ConsultationRoom(isPip: isVideoPip, onExpand: () => setState(() => viewMode = 'video')),
              ),
            ),

            // Form Background/Pane
            AnimatedPositioned(
              duration: 500.ms,
              curve: Curves.easeInOutCubic,
              left: formLeft,
              top: formTop,
              width: formWidth,
              height: formHeight,
              child: AnimatedContainer(
                duration: 500.ms,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isFormPip ? [const BoxShadow(color: Colors.black54, blurRadius: 20)] : [],
                  color: isFormPip ? const Color(0xFF1E293B) : Colors.transparent,
                ),
                clipBehavior: Clip.antiAlias,
                child: isFormPip 
                  ? _buildMinimizedForm() 
                  : const ClinicalPanel(),
              ),
            ),

            // Toggle Bar (Top Left)
            Positioned(
              top: 24,
              left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    _buildToggleBtn(Icons.view_sidebar_outlined, 'split'),
                    _buildToggleBtn(Icons.description_outlined, 'form'),
                    _buildToggleBtn(Icons.videocam_outlined, 'video'),
                  ],
                ),
              ).animate().slideY(begin: -1, duration: 600.ms, curve: Curves.easeOutCubic),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToggleBtn(IconData icon, String mode) {
    final isActive = viewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => viewMode = mode),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? Colors.indigoAccent : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isActive ? Colors.white : Colors.white54, size: 18),
      ),
    );
  }

  Widget _buildMinimizedForm() {
    return GestureDetector(
      onTap: () => setState(() => viewMode = 'form'),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description, size: 40, color: Colors.indigoAccent),
                SizedBox(height: 8),
                Text('Form', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}
