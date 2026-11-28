import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/push/push.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'features/auth/elder_pair_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session.dart';
import 'features/auth/welcome_screen.dart';
import 'features/elder/alarm_screen.dart';
import 'features/elder/issue_question_screen.dart';
import 'features/elder/readiness_screen.dart';
import 'features/care/care_api.dart';
import 'features/caregiver/caregiver_shell.dart';
import 'features/caregiver/today_api.dart';
import 'features/groups/groups_api.dart';
import 'features/groups/groups_screen.dart';
import 'features/home_gate.dart';
import 'features/medications/medications_screen.dart';
import 'features/spike/alarm_spike_screen.dart';
import 'core/config/server_config.dart';
import 'features/system/connection_screen.dart';
import 'features/system/consent_screen.dart';
import 'features/system/elder_preview_screen.dart';
import 'reminder/alarm_channel.dart';
import 'reminder/schedule_sync.dart';

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
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/pair', builder: (_, _) => const ElderPairScreen()),
      GoRoute(path: '/groups', builder: (_, _) => const GroupsScreen()),
      GoRoute(
        path: '/groups/:id',
        builder: (_, s) => CaregiverShell(
          key: ValueKey('group-${s.pathParameters['id']}'),
          groupId: int.parse(s.pathParameters['id']!),
          initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),
      GoRoute(
        path: '/groups/:id/elders/:elder/medications',
        builder: (_, s) => MedicationsScreen(
            groupId: int.parse(s.pathParameters['id']!), elderUserId: int.parse(s.pathParameters['elder']!)),
      ),
      GoRoute(path: '/connection', builder: (_, _) => const ConnectionScreen()),
      // Developer screens: only in debug builds, never on a parent's phone.
      if (kDebugMode) GoRoute(path: '/preview/elder', builder: (_, _) => const ElderPreviewScreen()),
      if (kDebugMode) GoRoute(path: '/spike/alarm', builder: (_, _) => const AlarmSpikeScreen()),
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
      // Consent first (plan §11); a ringing alarm above still wins.
      final consented = ref.read(sharedPreferencesProvider).getBool(consentKey) ?? false;
      if (!consented) return here == '/consent' ? null : '/consent';
      if (here == '/consent') return '/';
      final session = ref.read(sessionProvider);
      if (session.isLoading) return null;
      final signedIn = session.value != null;
      if (!signedIn && !_publicRoutes.contains(here) && here != '/alarm') return '/welcome';
      // An elder phone whose session expired may open the pairing screen to enter a new code.
      if (signedIn && here == '/pair' && session.value!.expired) return null;
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

class _AnTamAppState extends ConsumerState<AnTamApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmChannel.onRinging(
      (_) => ref.read(routerProvider).go('/alarm'),
      onSyncRequested: () {
        if (ref.read(meProvider).value?.isElder ?? false) ref.read(elderScheduleProvider.notifier).refresh();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone switched between light and dark: rebuild every screen with the other palette.
  @override
  void didChangePlatformBrightness() => setState(() {});

  void _onPush(String kind, Map<String, dynamic> data, {required bool elder}) {
    if (elder) {
      // "Stop ringing" (a caregiver marked the dose) and "schedule changed" both mean: download again.
      ref.read(elderScheduleProvider.notifier).refresh();
      return;
    }
    ref.invalidate(openAlertsProvider);
    ref.invalidate(dayViewProvider);
  }

  @override
  Widget build(BuildContext context) {
    // After sign-in, register this phone for pushes (no-op when Firebase is not set up). Only the session is
    // watched here: keeping meProvider alive from the root would cache a 401 from before sign-in.
    ref.listen(sessionProvider, (_, next) async {
      if (next.value == null || !PushSettings.configured) return;
      try {
        final me = await ref.read(groupsApiProvider).me();
        ref.read(pushProvider).start((k, d) => _onPush(k, d, elder: me.isElder));
      } catch (_) {
        // Tried again at the next sign-in or app start.
      }
    });
    // Light or dark follows the phone. Colours are read while screens build, so a switch remounts them.
    AppColors.dark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    return MaterialApp.router(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'An Tâm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(UiDensity.caregiver),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => KeyedSubtree(key: ValueKey(AppColors.dark), child: child ?? const SizedBox()),
    );
  }
}
