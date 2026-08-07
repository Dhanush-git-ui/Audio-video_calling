import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GuestExitScreen extends StatelessWidget {
  final String? roomName;

  const GuestExitScreen({
    super.key,
    this.roomName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.white12),
              ),
              elevation: 16,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.indigoAccent,
                        size: 56,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    const Text(
                      'Consultation Ended',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: 12),
                    Text(
                      roomName != null && roomName!.isNotEmpty
                          ? 'Your video session in room "$roomName" has concluded. Thank you for using AuraCare Telehealth.'
                          : 'Thank you for attending your telehealth appointment. Your video session has concluded securely.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.meeting_room, color: Colors.white),
                      label: const Text(
                        'Rejoin Session / Enter Guest Code',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(Icons.login_rounded, color: Colors.white70),
                      label: const Text(
                        'Doctor / Patient Portal Login',
                        style: TextStyle(color: Colors.white70),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
