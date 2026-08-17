import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/user_session_provider.dart';

class DashboardLayout extends StatefulWidget {
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<UserSessionProvider>(context);
    final isOnline = sessionProvider.isOnline;
    
    // Determine if we should show the top status navbar (e.g. not in active consultation)
    final showAppBar = widget.child.toString().contains('ConsultationView') == false;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.9),
                  border: const Border(
                    bottom: BorderSide(color: Color(0x2264748B), width: 1),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Brand Logo
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.monitor_heart, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AuraCare CHAV',
                              style: TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Clinical Telemedicine & Biometrics',
                              style: TextStyle(
                                color: const Color(0xFF94A3B8).withOpacity(0.8),
                                fontSize: 10,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Status & Role Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (sessionProvider.userRole.toLowerCase() == 'doctor') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF10B981).withOpacity(0.12)
                                      : const Color(0xFFF43F5E).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isOnline
                                        ? const Color(0xFF10B981).withOpacity(0.3)
                                        : const Color(0xFFF43F5E).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFF43F5E))
                                                .withOpacity(0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? 'DOCTOR ONLINE' : 'DOCTOR OFFLINE',
                                      style: TextStyle(
                                        color: isOnline ? const Color(0xFF34D399) : const Color(0xFFFB7185),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: isOnline,
                                activeColor: const Color(0xFF10B981),
                                activeTrackColor: const Color(0xFF065F46),
                                inactiveThumbColor: const Color(0xFF64748B),
                                inactiveTrackColor: const Color(0xFF1E293B),
                                onChanged: (val) {
                                  sessionProvider.setOnlineStatus(val);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        val
                                            ? 'Doctor availability status: ONLINE.'
                                            : 'Doctor presence status: OFFLINE.',
                                      ),
                                      backgroundColor: val ? const Color(0xFF4F46E5) : const Color(0xFFE11D48),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080C14),
          image: DecorationGradient(),
        ),
        child: widget.child,
      ).animate().fadeIn(duration: 250.ms, curve: Curves.easeOutCubic),
    );
  }
}

class DecorationGradient extends DecorationImage {
  const DecorationGradient()
      : super(
          image: const AssetImage('assets/empty.png'), // Fallback safe
          onError: _emptyError,
        );

  static void _emptyError(Object _, StackTrace? __) {}
}
