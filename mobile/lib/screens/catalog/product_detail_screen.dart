import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/productos_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productoId;

  const ProductDetailScreen({super.key, required this.productoId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _producto;
  List<Map<String, dynamic>> _precios = [];
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
      final service = context.read<ProductosService>();
      final data = await service.detalle(widget.productoId);
      if (!mounted) return;
      setState(() {
        _producto = data['producto'] as Map<String, dynamic>;
        _precios = data['precios'] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Producto no encontrado'
            : 'No se pudo cargar el producto';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el producto';
        _loading = false;
      });
    }
  }

  String _tiempoDesde(String? isoDate) {
    if (isoDate == null) return '';
    final fecha = DateTime.tryParse(isoDate);
    if (fecha == null) return '';
    final diff = DateTime.now().toUtc().difference(fecha);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_producto?['nombre'] as String? ?? 'Producto')),
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

    final p = _producto!;
    final cantidadTexto = '${p['cantidad_valor']} ${p['cantidad_unidad']}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_basket_outlined, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['marca']} · ${p['tamano']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (p['categoria_nombre'] != null)
                    Text(
                      p['categoria_nombre'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Precios en supermercados cercanos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_precios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Aún no hay precios registrados')),
          )
        else
          ..._precios.asMap().entries.map((entry) {
            final index = entry.key;
            final precio = entry.value;
            final esElMasBarato = index == 0;

            // Precio por unidad de referencia, calculado en la app
            final cantidadValor =
                double.tryParse(p['cantidad_valor'].toString()) ?? 1;
            final precioValor =
                double.tryParse(precio['precio'].toString()) ?? 0;
            final porUnidad = (precioValor / cantidadValor).toStringAsFixed(3);

            return Card(
              color: esElMasBarato
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: esElMasBarato
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    (precio['supermercado_cadena'] as String).substring(0, 1),
                    style: TextStyle(
                      color: esElMasBarato ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(precio['supermercado_nombre'] as String),
                subtitle: Text(
                  '${_tiempoDesde(precio['fecha_actualizacion'] as String?)} · $porUnidad €/${p['cantidad_unidad']}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${precio['precio']} €',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: esElMasBarato
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                    ),
                    if (esElMasBarato)
                      const Text(
                        'Más barato',
                        style: TextStyle(fontSize: 11),
                      ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        Text(
          'Cantidad: $cantidadTexto',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}