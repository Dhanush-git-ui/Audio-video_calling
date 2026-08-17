import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  void _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Stack(
        children: [
          // Ambient Aura Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withOpacity(0.1),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Telemetry Badge
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.monitor_heart,
                      color: Color(0xFF6366F1),
                      size: 46,
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(end: const Offset(1.04, 1.04), duration: 1500.ms, curve: Curves.easeInOut),
                const SizedBox(height: 32),

                // Main Title
                const Text(
                  'AuraCare CHAV',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF8FAFC),
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15, curve: Curves.easeOutCubic),
                const SizedBox(height: 10),

                // Telemetry Tagline Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x3364748B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'SECURE CLINICAL TELEMEDICINE & BIOMETRICS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 600.ms),

                const SizedBox(height: 48),

                // Snappy Loading Line
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Color(0xFF1E293B),
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                    ),
                  ),
                ).animate().fadeIn(delay: 450.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
