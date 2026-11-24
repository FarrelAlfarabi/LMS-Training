import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/admin.dart';
import 'pages/auth.dart';
import 'pages/learner.dart';
import 'pages/player.dart';
import 'repo/demo_repo.dart';
import 'repo/repo.dart';
import 'repo/supabase_repo.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/shell.dart';

// Set at build time: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await initializeDateFormatting('id');
  Repo repo;
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    repo = SupabaseRepo();
  } else {
    repo = DemoRepo();
  }
  final state = AppState(repo);
  await state.boot();
  runApp(BigmaApp(state: state));
}

const _public = {'/login', '/activate', '/forgot', '/privacy'};

GoRouter buildRouter(AppState st) => GoRouter(
      initialLocation: '/',
      refreshListenable: st,
      redirect: (c, s) {
        final p = s.uri.path;
        if (!st.signedIn) return _public.contains(p) ? null : '/login';
        if (st.needsConsent && p != '/welcome' && p != '/privacy') return '/welcome';
        if (_public.contains(p) && p != '/privacy') return st.profile!.isAdmin ? '/admin' : '/';
        final admin = st.profile!.isAdmin;
        if (admin && !p.startsWith('/admin') && !{'/help', '/password', '/privacy', '/welcome'}.contains(p)) return '/admin';
        if (!admin && p.startsWith('/admin')) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/activate', builder: (_, __) => const ActivatePage()),
        GoRoute(path: '/forgot', builder: (_, __) => const ForgotPage()),
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomePage()),
        ShellRoute(
          builder: (c, s, child) => Shell(location: s.uri.path, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const HomePage()),
            GoRoute(path: '/classes', builder: (_, __) => const ClassesPage()),
            GoRoute(path: '/class/:id', builder: (_, s) => ClassPage(s.pathParameters['id']!, key: ValueKey(s.uri.toString()))),
            GoRoute(path: '/class/:id/step/:step', builder: (_, s) => StepPage(s.pathParameters['id']!, s.pathParameters['step']!)),
            GoRoute(path: '/class/:id/test/:kind', builder: (_, s) => TestPage(s.pathParameters['id']!, s.pathParameters['kind']!)),
            GoRoute(path: '/certificates', builder: (_, __) => const CertificatesPage()),
            GoRoute(path: '/certificates/:id', builder: (_, s) => CertificatePage(s.pathParameters['id']!)),
            GoRoute(path: '/points', builder: (_, __) => const PointsPage()),
            GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardPage()),
            GoRoute(path: '/notifications', builder: (_, __) => const NotificationsPage()),
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
            GoRoute(path: '/password', builder: (_, __) => const PasswordPage()),
            GoRoute(path: '/help', builder: (_, __) => const HelpPage()),
            GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
            GoRoute(path: '/admin/people', builder: (_, __) => const PeoplePage()),
            GoRoute(path: '/admin/courses', builder: (_, __) => const CoursesAdminPage()),
            GoRoute(path: '/admin/courses/:id', builder: (_, s) => CourseBuilderPage(s.pathParameters['id']!)),
            GoRoute(path: '/admin/courses/:id/test/:kind', builder: (_, s) => TestEditorPage(s.pathParameters['id']!, s.pathParameters['kind']!)),
            GoRoute(path: '/admin/assign', builder: (_, s) => AssignPage(courseId: s.uri.queryParameters['course'], key: ValueKey(s.uri.toString()))),
            GoRoute(path: '/admin/reports', builder: (_, s) => ReportsPage(filter: s.uri.queryParameters['filter'], key: ValueKey(s.uri.toString()))),
            GoRoute(path: '/admin/settings', builder: (_, __) => const SettingsPage()),
          ],
        ),
        GoRoute(path: '/privacy', builder: (_, __) => const Scaffold(backgroundColor: Colors.white, body: SafeArea(child: PrivacyPage()))),
      ],
      errorBuilder: (c, s) => Scaffold(body: Center(child: TextButton(onPressed: () => c.go('/'), child: const Text('Halaman tidak ditemukan. Kembali ke Beranda')))),
    );

class BigmaApp extends StatefulWidget {
  final AppState state;
  const BigmaApp({super.key, required this.state});
  @override
  State<BigmaApp> createState() => _BigmaAppState();
}

class _BigmaAppState extends State<BigmaApp> {
  late final _router = buildRouter(widget.state);
  @override
  Widget build(BuildContext context) => Scope(
        state: widget.state,
        child: MaterialApp.router(
          title: 'Bigma Belajar',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          routerConfig: _router,
          locale: const Locale('id'),
          supportedLocales: const [Locale('id'), Locale('en')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        ),
      );
}
