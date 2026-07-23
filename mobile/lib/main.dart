import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supermercados_service.dart';
import 'services/location_service.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'screens/map/map_screen.dart';


void main() {
  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  apiClient.refreshAccessToken = authService.refreshAccessToken;
  final supermercadosService = SupermercadosService(apiClient);
  final locationService = LocationService();
  final authProvider = AuthProvider(authService)..bootstrap();

  runApp(SupermarketApp(
    authProvider: authProvider,
    supermercadosService: supermercadosService,
    locationService: locationService,
  ));
}

class SupermarketApp extends StatelessWidget {
  final AuthProvider authProvider;
  final SupermercadosService supermercadosService;
  final LocationService locationService;

  const SupermarketApp({
    super.key,
    required this.authProvider,
    required this.supermercadosService,
    required this.locationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: supermercadosService),
        Provider.value(value: locationService),
      ],
      child: MaterialApp(
        title: 'Supermarket',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const MapScreen();
    }
  }
}