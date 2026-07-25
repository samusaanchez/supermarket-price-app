import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/tickets_service.dart';
import '../../services/api_client.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TicketsService>().getById(widget.ticketId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final t = snap.data!;
          final items = (t['items'] as List).cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Foto del ticket.
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  '${ApiClient.origin}${t['foto_url']}',
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t['supermercado_nombre'] as String? ?? 'Sin supermercado asignado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('Estado: ${t['estado']}'),
              const Divider(height: 32),
              Text('Productos', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Este ticket aún no tiene productos revisados.'),
                )
              else
                ...items.map((it) {
                  final nombre = it['producto_nombre'] as String? ??
                      it['texto_ocr'] as String? ??
                      'Producto';
                  final marca = it['producto_marca'] as String?;
                  final precio = it['precio_confirmado'];
                  final pesoVariable =
                      it['es_peso_variable'] == true && it['peso'] != null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(marca != null ? '$nombre · $marca' : nombre),
                    subtitle: pesoVariable ? Text('Peso: ${it['peso']} kg') : null,
                    trailing: precio != null ? Text('$precio €') : null,
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
