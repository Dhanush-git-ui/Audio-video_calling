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
      backgroundColor: const Color(0xFF0B1120),
      appBar: showAppBar
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.indigoAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.spa, color: Colors.indigoAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'AuraCare CHAV',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sessionProvider.userRole.toLowerCase() == 'doctor') ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.greenAccent : Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: isOnline
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'DOCTOR ONLINE' : 'DOCTOR OFFLINE',
                        style: TextStyle(
                          color: isOnline ? Colors.greenAccent : Colors.white30,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: isOnline,
                        activeColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.white30,
                        onChanged: (val) {
                          sessionProvider.setOnlineStatus(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val
                                    ? 'Doctor availability status: ONLINE. Queue notifications active.'
                                    : 'Doctor presence status: OFFLINE.',
                              ),
                              backgroundColor: val ? Colors.indigoAccent : Colors.redAccent.withOpacity(0.8),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
                  ],
                ),
              ],
            )
          : null,
      body: Container(
        color: const Color(0xFF0B1120),
        child: widget.child,
      ).animate().fadeIn(duration: 600.ms),
    );
  }
}
