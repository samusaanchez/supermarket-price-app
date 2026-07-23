import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/supermercados_service.dart';
import '../catalog/catalog_screen.dart';

class SupermercadoDetailScreen extends StatefulWidget {
  final int supermercadoId;

  const SupermercadoDetailScreen({super.key, required this.supermercadoId});

  @override
  State<SupermercadoDetailScreen> createState() =>
      _SupermercadoDetailScreenState();
}

class _SupermercadoDetailScreenState extends State<SupermercadoDetailScreen> {
  Map<String, dynamic>? _supermercado;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<SupermercadosService>();
      final data = await service.getById(widget.supermercadoId);
      if (!mounted) return;
      setState(() {
        _supermercado = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Supermercado no encontrado'
            : 'No se pudo cargar la información';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la información';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_supermercado?['nombre'] ?? 'Supermercado')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final s = _supermercado!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Row(icon: Icons.storefront, label: 'Cadena', value: s['cadena'] as String?),
        _Row(icon: Icons.place, label: 'Dirección', value: s['direccion'] as String?),
        _Row(icon: Icons.schedule, label: 'Horario', value: s['horario'] as String?),
        const SizedBox(height: 24),




        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CatalogScreen(
                  supermercadoId: widget.supermercadoId,
                  supermercadoNombre: s['nombre'] as String,
                ),
              ),
            );
          },
          icon: const Icon(Icons.shopping_basket),
          label: const Text('Ver productos'),
        ),



        
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}