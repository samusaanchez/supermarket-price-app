import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supermercados_service.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'screens/map/map_screen.dart';


void main() {
  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  final supermercadosService = SupermercadosService(apiClient);
  final authProvider = AuthProvider(authService)..bootstrap();

  runApp(SupermarketApp(
    authProvider: authProvider,
    supermercadosService: supermercadosService,
  ));
}

class SupermarketApp extends StatelessWidget {
  final AuthProvider authProvider;
  final SupermercadosService supermercadosService;

  const SupermarketApp({
    super.key,
    required this.authProvider,
    required this.supermercadosService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: supermercadosService),
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