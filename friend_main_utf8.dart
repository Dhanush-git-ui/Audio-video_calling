import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'components/virtual_waiting_room.dart';
import 'components/consultation_view.dart';
import 'components/dashboard_layout.dart';
import 'config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  runApp(const ChavApp());
}

// Custom page transition — fade + slight slide up
CustomTransitionPage<T> _fadePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(fade);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slideAnim, child: child),
      );
    },
  );
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) {
        final qp = state.uri.queryParameters;
        return _fadePage(
          context: context,
          state: state,
          child: DashboardLayout(
            child: VirtualWaitingRoom(
              initialRoom: qp['room'],
              initialUrl: qp['url'],
              initialKey: qp['key'],
              initialSecret: qp['secret'],
            ),
          ),
        );
      },
    ),
    GoRoute(
      path: '/consultation',
      pageBuilder: (context, state) {
        final qp = state.uri.queryParameters;
        final extra = state.extra as Map<String, dynamic>? ?? {};

        final url = qp['url'] ?? extra['url'] ?? 'ws://localhost:7880';
        final token = qp['token'] ?? extra['token'] ?? '';
        final room = qp['room'] ?? extra['room'] ?? '';
        final apiKey = qp['apiKey'] ?? extra['apiKey'] ?? '';
        final apiSecret = qp['apiSecret'] ?? extra['apiSecret'] ?? '';
        final initialVideoOn =
            qp['initialVideoOn'] ?? extra['initialVideoOn'] ?? 'true';
        final initialAudioOn =
            qp['initialAudioOn'] ?? extra['initialAudioOn'] ?? 'true';
        final publicUrl = qp['publicUrl'] ?? extra['publicUrl'] ?? '';
        final isDoctor =
            (qp['isDoctor'] ?? extra['isDoctor'] ?? 'false') == 'true';

        return _fadePage(
          context: context,
          state: state,
          child: DashboardLayout(
            child: ConsultationView(
              url: url,
              token: token,
              room: room,
              apiKey: apiKey,
              apiSecret: apiSecret,
              initialVideoOn: initialVideoOn == 'true',
              initialAudioOn: initialAudioOn == 'true',
              publicUrl: publicUrl,
              isDoctor: isDoctor,
            ),
          ),
        );
      },
    ),
  ],
);

class ChavApp extends StatelessWidget {
  const ChavApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'CHAV Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: Colors.indigo,
        colorScheme: const ColorScheme.dark(
          primary: Colors.indigoAccent,
          secondary: Colors.pinkAccent,
        ),
        // Smooth page transitions for dialogs and overlays
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      routerConfig: _router,
    );
  }
}
