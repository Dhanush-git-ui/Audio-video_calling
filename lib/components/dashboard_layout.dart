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
      backgroundColor: const Color(0xFF0A1120),
      appBar: showAppBar
          ? PreferredSize(
              preferredSize: const Size.fromHeight(68),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111C33).withOpacity(0.95),
                  border: const Border(
                    bottom: BorderSide(color: Color(0x2A1554A6), width: 1),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // CallHealth Brand Logo
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1120),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x331554A6)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1554A6).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.health_and_safety, color: Color(0xFF78C02B), size: 20),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Call',
                                        style: TextStyle(
                                          color: Color(0xFF2563EB),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Health',
                                        style: TextStyle(
                                          color: Color(0xFF78C02B),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1554A6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 10),
                                ),
                              ],
                            ),
                            const Text(
                              'Everything about health',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOnline
                                      ? const Color(0xFF78C02B).withOpacity(0.15)
                                      : const Color(0xFFE11D48).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isOnline
                                        ? const Color(0xFF78C02B).withOpacity(0.4)
                                        : const Color(0xFFE11D48).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: isOnline ? const Color(0xFF78C02B) : const Color(0xFFE11D48),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isOnline ? const Color(0xFF78C02B) : const Color(0xFFE11D48))
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
                                        color: isOnline ? const Color(0xFF78C02B) : const Color(0xFFFB7185),
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
                                activeColor: const Color(0xFF78C02B),
                                activeTrackColor: const Color(0xFF2E5912),
                                inactiveThumbColor: const Color(0xFF64748B),
                                inactiveTrackColor: const Color(0xFF162544),
                                onChanged: (val) {
                                  sessionProvider.setOnlineStatus(val);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        val
                                            ? 'Doctor availability status: ONLINE.'
                                            : 'Doctor presence status: OFFLINE.',
                                      ),
                                      backgroundColor: val ? const Color(0xFF1554A6) : const Color(0xFFE11D48),
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
        color: const Color(0xFF0A1120),
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
