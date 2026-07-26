import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Trae contadores frescos al abrir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshUser();
    });
  }

  int _nivel(double c) {
    if (c >= 95) return 5;
    if (c >= 80) return 4;
    if (c >= 60) return 3;
    if (c >= 30) return 2;
    return 1;
  }

  String _nivelTexto(int n) {
    switch (n) {
      case 5:
        return 'Top';
      case 4:
        return 'Muy fiable';
      case 3:
        return 'Fiable';
      case 2:
        return 'Básica';
      default:
        return 'No verificada';
    }
  }

  void _proximamente(String que) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$que — próximamente')),
    );
  }

  Future<void> _confirmarLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AuthProvider>().logout();
      // El _Root de main.dart cambia solo a la pantalla de login.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final nombre = (user?['nombre'] as String?) ?? 'Usuario';
    final email = (user?['email'] as String?) ?? '';
    final confiabilidad =
        double.tryParse('${user?['confiabilidad'] ?? 0}') ?? 0;
    final nivel = _nivel(confiabilidad);
    final tickets = user?['tickets_subidos'] ?? 0;
    final fotos = user?['fotos_verificadas'] ?? 0;
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          // Cabecera: avatar + nombre + email.
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      child: Text(inicial,
                          style: const TextStyle(fontSize: 36)),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => _proximamente('Cambiar foto de perfil'),
                      icon: const Icon(Icons.photo_camera, size: 18),
                      tooltip: 'Cambiar foto',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(nombre,
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(email,
                    style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confianza.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Confianza',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < nivel ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_nivelTexto(nivel)} · ${confiabilidad.toStringAsFixed(0)}/100',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Contadores.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _stat('Tickets subidos', '$tickets')),
                const SizedBox(width: 12),
                Expanded(child: _stat('Fotos verificadas', '$fotos')),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(),

          // Ajustes de cuenta (por venir).
          _fila(Icons.lock_outline, 'Cambiar contraseña',
              () => _proximamente('Cambiar contraseña')),
          _fila(Icons.verified_user_outlined, 'Verificación en dos pasos',
              () => _proximamente('Verificación en dos pasos')),
          _fila(Icons.link, 'Apps conectadas',
              () => _proximamente('Apps conectadas')),
          _fila(Icons.notifications_outlined, 'Notificaciones',
              () => _proximamente('Notificaciones')),

          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: _confirmarLogout,
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar sesión',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String valor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(valor, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _fila(IconData icono, String texto, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icono),
      title: Text(texto),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
