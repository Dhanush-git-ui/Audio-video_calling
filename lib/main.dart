import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'components/virtual_waiting_room.dart';
import 'components/consultation_view.dart';
import 'components/dashboard_layout.dart';

void main() {
  runApp(const ChavApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardLayout(child: VirtualWaitingRoom()),
    ),
    GoRoute(
      path: '/consultation',
      builder: (context, state) => const DashboardLayout(child: ConsultationView()),
    ),
  ],
);

class ChavApp extends StatelessWidget {
  const ChavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CHAV Flutter',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.indigo,
        colorScheme: const ColorScheme.dark(
          primary: Colors.indigoAccent,
          secondary: Colors.pinkAccent,
        ),
      ),
      routerConfig: _router,
    );
  }
}
