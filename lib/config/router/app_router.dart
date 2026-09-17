import 'package:flutter_application_1/pages/Pages.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/pages/graphs/graphs_screen.dart';

// GoRouter configuration
final appRouter = GoRouter(
  initialLocation: '/splash',

  routes: [
    GoRoute(path: '/', builder: (context, state) => HomeScreen()),
    GoRoute(path: '/data', builder: (context, state) => DataScreen()),
    GoRoute(path: '/splash', builder: (context, state) => SplashScreen()),
    GoRoute(
      path: '/graficas',
      builder: (context, state) => const GraphsScreen(),
    ),
  ],
);
