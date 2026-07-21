import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

void main() {
  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  final authProvider = AuthProvider(authService)..bootstrap();

  runApp(SupermarketApp(authProvider: authProvider));
}

class SupermarketApp extends StatelessWidget {
  final AuthProvider authProvider;

  const SupermarketApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: authProvider,
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
        final nombre = auth.user?['nombre'] ?? auth.user?['email'] ?? '';
        return Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: Center(child: Text('Hola, $nombre')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.read<AuthProvider>().logout(),
            label: const Text('Cerrar sesión'),
            icon: const Icon(Icons.logout),
          ),
        );
    }
  }
}