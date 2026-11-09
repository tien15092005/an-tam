import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/auth/elder_pair_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session.dart';
import 'features/auth/welcome_screen.dart';
import 'features/elder/alarm_screen.dart';
import 'features/elder/issue_question_screen.dart';
import 'features/elder/readiness_screen.dart';
import 'features/groups/group_detail_screen.dart';
import 'features/home_gate.dart';
import 'features/medications/medications_screen.dart';
import 'features/spike/alarm_spike_screen.dart';
import 'features/system/connection_screen.dart';
import 'features/system/elder_preview_screen.dart';
import 'reminder/alarm_channel.dart';

/// Re-runs the router's redirect whenever the session changes (sign-in, sign-out, expiry).
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

const _publicRoutes = {'/welcome', '/login', '/pair', '/connection', '/spike/alarm', '/preview/elder'};

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _SessionListenable(ref),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeGate()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/pair', builder: (_, _) => const ElderPairScreen()),
      GoRoute(path: '/groups/:id', builder: (_, s) => GroupDetailScreen(groupId: int.parse(s.pathParameters['id']!))),
      GoRoute(
        path: '/groups/:id/elders/:elder/medications',
        builder: (_, s) => MedicationsScreen(
            groupId: int.parse(s.pathParameters['id']!), elderUserId: int.parse(s.pathParameters['elder']!)),
      ),
      GoRoute(path: '/connection', builder: (_, _) => const ConnectionScreen()),
      GoRoute(path: '/preview/elder', builder: (_, _) => const ElderPreviewScreen()),
      GoRoute(path: '/spike/alarm', builder: (_, _) => const AlarmSpikeScreen()),
      GoRoute(path: '/alarm', builder: (_, _) => const AlarmScreen()),
      GoRoute(
        path: '/alarm/question',
        builder: (_, s) => s.extra is QuestionArgs ? IssueQuestionScreen(args: s.extra! as QuestionArgs) : const HomeGate(),
      ),
      GoRoute(path: '/readiness', builder: (_, _) => const ReadinessScreen()),
    ],
    redirect: (context, state) async {
      final here = state.matchedLocation;
      // A ringing alarm always wins, signed in or not: the alarm must never be hidden behind a login.
      if (here != '/alarm' && await AlarmChannel.ringingId() != null) return '/alarm';
      final session = ref.read(sessionProvider);
      if (session.isLoading) return null;
      final signedIn = session.value != null;
      if (!signedIn && !_publicRoutes.contains(here) && here != '/alarm') return '/welcome';
      if (signedIn && (here == '/welcome' || here == '/login' || here == '/pair')) return '/';
      return null;
    },
  );
});

class AnTamApp extends ConsumerStatefulWidget {
  const AnTamApp({super.key});

  @override
  ConsumerState<AnTamApp> createState() => _AnTamAppState();
}

class _AnTamAppState extends ConsumerState<AnTamApp> {
  @override
  void initState() {
    super.initState();
    AlarmChannel.onRinging((_) => ref.read(routerProvider).go('/alarm'));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'An Tâm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(UiDensity.caregiver),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
