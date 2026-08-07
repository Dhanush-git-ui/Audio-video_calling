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
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1E38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon Pulse
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigoAccent.withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigoAccent.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.spa,
                  color: Colors.indigoAccent,
                  size: 48,
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(end: const Offset(1.1, 1.1), duration: 1200.ms, curve: Curves.easeInOut),
              const SizedBox(height: 28),
              
              // App Brand
              const Text(
                'AuraCare',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              
              // Subtitle
              const Text(
                'CHAV Telemedicine Suite',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  letterSpacing: 0.8,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 800.ms),
              const SizedBox(height: 48),
              
              // Loading Dots/Indicator
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }
}
