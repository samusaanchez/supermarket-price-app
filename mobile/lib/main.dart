import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

void main() {
  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  final authProvider = AuthProvider(authService);

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
        home: const Scaffold(
          body: Center(
            child: Text('App vacía. Aquí construiremos.'),
          ),
        ),
      ),
    );
  }
}