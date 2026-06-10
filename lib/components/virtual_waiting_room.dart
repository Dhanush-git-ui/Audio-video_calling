import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class VirtualWaitingRoom extends StatelessWidget {
  const VirtualWaitingRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Waiting Room'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.meeting_room, size: 80, color: Colors.indigoAccent)
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(end: 1.1, duration: 1500.ms, curve: Curves.easeInOut)
                .boxShadow(end: const BoxShadow(color: Colors.indigoAccent, blurRadius: 40, spreadRadius: -10)),
            const SizedBox(height: 20),
            const Text(
              'Welcome to CHAV',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 10),
            const Text(
              'Your consultation will begin shortly.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => context.go('/consultation'),
              icon: const Icon(Icons.video_call),
              label: const Text('Join Consultation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.indigoAccent,
              ),
            ).animate().fadeIn(delay: 700.ms).scaleXY(begin: 0.9, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}
