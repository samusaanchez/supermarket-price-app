import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/tickets_service.dart';
import '../../services/api_client.dart';
import 'upload_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class MisTicketsScreen extends StatefulWidget {
  const MisTicketsScreen({super.key});

  @override
  State<MisTicketsScreen> createState() => _MisTicketsScreenState();
}

class _MisTicketsScreenState extends State<MisTicketsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _future = context.read<TicketsService>().list();
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _future;
  }

  Future<void> _abrirSubida() async {
    final ticket = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadTicketScreen()),
    );
    if (ticket != null) _refrescar(); // se subió algo: recargamos la lista
  }

  String _estadoTexto(String e) {
    switch (e) {
      case 'completado':
        return 'Completado';
      case 'pendiente':
        return 'Pendiente';
      case 'procesando':
        return 'Procesando';
      case 'error':
        return 'Error';
      default:
        return e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis tickets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirSubida,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Subir'),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${snap.error}'),
                  ),
                ],
              );
            }
            final tickets = snap.data ?? [];
            if (tickets.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('Aún no has subido tickets')),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final t = tickets[i];
                final estado = t['estado'] as String;
                final completado = estado == 'completado';
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      '${ApiClient.origin}${t['foto_url']}',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.receipt_long),
                    ),
                  ),
                  title: Text(
                    t['supermercado_nombre'] as String? ?? 'Sin confirmar',
                  ),
                  subtitle: Text(
                    '${_estadoTexto(estado)} · ${t['num_items']} productos',
                  ),
                  trailing: Icon(
                    completado ? Icons.check_circle : Icons.schedule,
                    color: completado ? Colors.green : Colors.orange,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TicketDetailScreen(ticketId: t['id'] as String),
                      ),
                    );
                    _refrescar();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
