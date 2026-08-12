import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/adapters/auth_store_adapter.dart';
import 'core/adapters/base_url_adapter.dart';
import 'core/api_client.dart';
import 'core/pwa_install_service.dart';
import 'core/theme.dart';
import 'screens/app_shell.dart';
import 'screens/community_screen.dart';
import 'screens/heat_data_screen.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient(
    baseUrlAdapter: BaseUrlAdapter(),
    authStore: createAuthStoreAdapter(),
  );
  final auth = AuthState(authStore: createAuthStoreAdapter());
  final app = AppState(api: api, auth: auth);

  // PWA install support (web only).
  final pwaInstall = PwaInstallService()..init();

  // Restore any persisted token.
  await auth.restore();

  runApp(NowcastApp(app: app, pwaInstall: pwaInstall));
}

class NowcastApp extends StatefulWidget {
  const NowcastApp({super.key, required this.app, required this.pwaInstall});

  final AppState app;
  final PwaInstallService pwaInstall;

  @override
  State<NowcastApp> createState() => _NowcastAppState();
}

class _NowcastAppState extends State<NowcastApp> {
  @override
  void dispose() {
    widget.pwaInstall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: widget.app),
        ChangeNotifierProvider<PwaInstallService>.value(
          value: widget.pwaInstall,
        ),
      ],
      child: MaterialApp(
        title: 'Nowcast',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const AppShell(
          tabs: [
            HomeScreen(),
            HeatDataScreen(),
            MapScreen(),
            CommunityScreen(),
            ProfileScreen(),
          ],
          titles: ['Home', 'Heat Data', 'Map', 'Community', 'Profile'],
        ),
      ),
    );
  }
}
