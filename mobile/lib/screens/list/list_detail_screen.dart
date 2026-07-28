import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/listas_service.dart';
import '../catalog/product_detail_screen.dart';

import 'comparison_screen.dart';

class ListDetailScreen extends StatefulWidget {
  final String listaId;

  const ListDetailScreen({super.key, required this.listaId});

  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  Map<String, dynamic>? _lista;
  List<Map<String, dynamic>> _items = [];
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
      final service = context.read<ListasService>();
      final data = await service.getById(widget.listaId);
      if (!mounted) return;
      setState(() {
        _lista = data['lista'] as Map<String, dynamic>;
        _items = data['items'] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Lista no encontrada'
            : 'No se pudo cargar la lista';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista';
        _loading = false;
      });
    }
  }

  Future<void> _cambiarCantidad(Map<String, dynamic> item, int nuevaCantidad) async {
    if (nuevaCantidad < 1) return;
    if (nuevaCantidad > 999) nuevaCantidad = 999;

    // Actualización optimista: cambiamos ya en la UI, y si falla revertimos.
    final cantidadAnterior = item['cantidad'] as int;
    setState(() => item['cantidad'] = nuevaCantidad);

    try {
      final service = context.read<ListasService>();
      await service.updateItem(
        widget.listaId,
        item['id'] as String,
        nuevaCantidad,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => item['cantidad'] = cantidadAnterior);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar')),
      );
    }
  }

  Future<void> _quitar(Map<String, dynamic> item) async {
    final index = _items.indexOf(item);
    setState(() => _items.remove(item));

    try {
      final service = context.read<ListasService>();
      await service.removeItem(widget.listaId, item['id'] as String);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items.insert(index, item));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_lista?['nombre'] as String? ?? 'Lista')),
      body: _buildBody(),
      floatingActionButton: _items.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ComparisonScreen(
                      listaId: widget.listaId,
                      listaNombre: _lista?['nombre'] as String? ?? 'Lista',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.balance),
              label: const Text('Comparar precios'),
            )
          : null,
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
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La lista está vacía.\nAñade productos desde el catálogo o el buscador.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80), // hueco para el botón flotante
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ItemTile(
          item: item,
          onIncremento: () =>
              _cambiarCantidad(item, (item['cantidad'] as int) + 1),
          onDecremento: () =>
              _cambiarCantidad(item, (item['cantidad'] as int) - 1),
          onQuitar: () => _quitar(item),
          onAbrir: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  productoId: item['producto_id'] as String,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onIncremento;
  final VoidCallback onDecremento;
  final VoidCallback onQuitar;
  final VoidCallback onAbrir;

  const _ItemTile({
    required this.item,
    required this.onIncremento,
    required this.onDecremento,
    required this.onQuitar,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final cantidad = item['cantidad'] as int;
    return ListTile(
      onTap: onAbrir,
      title: Text(item['nombre'] as String),
      subtitle: Text('${item['marca']} · ${item['tamano']}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: cantidad > 1 ? onDecremento : onQuitar,
            tooltip: cantidad > 1 ? 'Menos' : 'Quitar',
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: cantidad < 999 ? onIncremento : null,
            tooltip: 'Más',
          ),
        ],
      ),
    );
  }
}