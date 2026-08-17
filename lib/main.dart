import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'providers/user_session_provider.dart';
import 'components/virtual_waiting_room.dart';
import 'components/consultation_view.dart';
import 'components/dashboard_layout.dart';
import 'components/splash_screen.dart';
import 'components/ai_pre_consultation.dart';
import 'components/token_generator.dart';
import 'components/login_screen.dart';
import 'components/guest_exit_screen.dart';
import 'config.dart';

void main() {
  runApp(const ChavApp());
}

Map<String, String> _parseQueryParams(GoRouterState state) {
  final params = <String, String>{};
  
  String cleanValue(String val) {
    var cleaned = val.trim();
    if (cleaned.contains('\n')) {
      cleaned = cleaned.split('\n').first.trim();
    }
    if (cleaned.contains(' ')) {
      cleaned = cleaned.split(' ').first.trim();
    }
    return cleaned;
  }

  state.uri.queryParameters.forEach((key, value) {
    params[key] = cleanValue(value);
  });
  
  if (params.isEmpty) {
    Uri.base.queryParameters.forEach((key, value) {
      params[key] = cleanValue(value);
    });
  }
  
  if (params.isEmpty) {
    try {
      final fragment = Uri.base.fragment;
      if (fragment.contains('?')) {
        final queryPart = fragment.substring(fragment.indexOf('?'));
        final uri = Uri.parse(queryPart);
        uri.queryParameters.forEach((key, value) {
          params[key] = cleanValue(value);
        });
      }
    } catch (e) {
      // ignore
    }
  }
  return params;
}

final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/guest-exit',
      builder: (context, state) {
        final qp = _parseQueryParams(state);
        return GuestExitScreen(roomName: qp['room']);
      },
    ),
    GoRoute(
      path: '/pre-consultation',
      builder: (context, state) => const AiPreConsultation(),
    ),
    GoRoute(
      path: '/biometric-gate',
      builder: (context, state) {
        final qp = _parseQueryParams(state);
        final role = qp['role'] ?? 'patient';
        final roomName = qp['room'] ?? 'CLINICAL_ROOM_1';
        final userName = qp['name'] ?? 'Guest';

        final isDoctorRole = (role == 'doctor');
        final isGuestRole = (role == 'guest');
        final token = generateLiveKitToken(
          roomName: roomName,
          participantName: userName,
          apiKey: LiveKitConfig.apiKey,
          apiSecret: LiveKitConfig.apiSecret,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(
            Uri(
              path: '/consultation',
              queryParameters: {
                'room': roomName,
                'url': LiveKitConfig.serverUrl,
                'isDoctor': isDoctorRole.toString(),
                'isGuest': isGuestRole.toString(),
              },
            ).toString(),
            extra: {
              'token': token,
              'isDoctor': isDoctorRole.toString(),
              'isGuest': isGuestRole.toString(),
            },
          );
        });
        return const Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(
            child: CircularProgressIndicator(color: Colors.indigoAccent),
          ),
        );
      },
    ),
    GoRoute(
      path: '/',
      builder: (context, state) {
        final qp = _parseQueryParams(state);
        final session = Provider.of<UserSessionProvider>(context, listen: false);

        final role = session.isLoggedIn
            ? session.userRole.toLowerCase()
            : qp['role'];
        final name = session.isLoggedIn
            ? session.userName
            : (qp['name']);

        return DashboardLayout(
          child: VirtualWaitingRoom(
            initialRoom: qp['room'],
            initialName: name,
            initialUrl: qp['url'],
            initialKey: qp['key'],
            initialSecret: qp['secret'],
            initialRole: role,
            initialAccessCode: qp['ac'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/consultation',
      builder: (context, state) {
        final qp = _parseQueryParams(state);
        final extra = state.extra as Map<String, dynamic>? ?? {};
        
        final url = qp['url'] ?? extra['url'] ?? 'ws://localhost:7880';
        var token = qp['token'] ?? extra['token'] ?? '';
        final room = qp['room'] ?? extra['room'] ?? '';
        final apiKey = qp['apiKey'] ?? extra['apiKey'] ?? '';
        final apiSecret = qp['apiSecret'] ?? extra['apiSecret'] ?? '';
        final initialVideoOn = qp['initialVideoOn'] ?? extra['initialVideoOn'] ?? 'true';
        final initialAudioOn = qp['initialAudioOn'] ?? extra['initialAudioOn'] ?? 'true';
        final publicUrl = qp['publicUrl'] ?? extra['publicUrl'] ?? '';
        final isDoctor = (qp['isDoctor'] ?? extra['isDoctor'] ?? 'false') == 'true';
        final isGuest = (qp['isGuest'] == 'true') || (qp['role'] == 'guest') || ((extra['isGuest'] ?? 'false') == 'true');
        
        // Auto-generate token if missing on page reload/refresh
        if (token.isEmpty && room.isNotEmpty) {
          final name = isDoctor ? 'Doctor' : 'Guest - ${(100 + Random().nextInt(900))}';
          token = generateLiveKitToken(
            roomName: room,
            participantName: name,
            apiKey: LiveKitConfig.apiKey,
            apiSecret: LiveKitConfig.apiSecret,
          );
        }

        return DashboardLayout(
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
            isGuest: isGuest,
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
    return ChangeNotifierProvider(
      create: (_) => UserSessionProvider(),
      child: MaterialApp.router(
        title: 'AuraCare CHAV | Telehealth & Biometric Intelligence',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF080C14),
          primaryColor: const Color(0xFF6366F1),
          canvasColor: const Color(0xFF0F172A),
          cardColor: const Color(0xFF0F172A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            primaryContainer: Color(0xFF4338CA),
            secondary: Color(0xFF06B6D4),
            secondaryContainer: Color(0xFF0E7490),
            tertiary: Color(0xFF10B981),
            surface: Color(0xFF0F172A),
            surfaceContainerHighest: Color(0xFF1E293B),
            error: Color(0xFFF43F5E),
            onPrimary: Colors.white,
            onSurface: Color(0xFFF8FAFC),
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700, letterSpacing: -0.5),
            headlineLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700, letterSpacing: -0.4),
            headlineMedium: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600, letterSpacing: -0.3),
            titleLarge: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w600, letterSpacing: -0.2),
            titleMedium: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.5),
            bodyMedium: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4),
            labelSmall: TextStyle(color: Color(0xFF64748B), fontSize: 10, letterSpacing: 0.5, fontWeight: FontWeight.w600),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            },
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0x3364748B)),
            ),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF0F172A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0x22FFFFFF)),
            ),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0x1FFFFFFF),
            thickness: 1,
            space: 1,
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}
