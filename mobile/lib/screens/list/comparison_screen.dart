import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/listas_service.dart';
import '../map/chain_style.dart';

class ComparisonScreen extends StatefulWidget {
  final String listaId;
  final String listaNombre;

  const ComparisonScreen({
    super.key,
    required this.listaId,
    required this.listaNombre,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  Map<String, dynamic>? _data;
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
      final data = await service.comparar(widget.listaId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Lista no encontrada'
            : 'No se pudo cargar la comparativa';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la comparativa';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comparar: ${widget.listaNombre}')),
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

    final data = _data!;
    final itemsCount = data['items_count'] as int;
    final supermercados =
        (data['supermercados'] as List).cast<Map<String, dynamic>>();

    if (itemsCount == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'La lista no tiene productos.\nAñade algunos y vuelve a comparar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Encontrar el índice del "mejor" (primer supermercado que tenga todos los productos)
    final mejorIndex = supermercados.indexWhere(
      (s) => (s['productos_disponibles'] as int) == itemsCount,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: supermercados.length + 1, // + resumen arriba
      itemBuilder: (context, index) {
        if (index == 0) {
          return _ResumenCard(
            itemsCount: itemsCount,
            supermercados: supermercados,
            mejorIndex: mejorIndex,
          );
        }
        final super_ = supermercados[index - 1];
        return _SupermercadoCard(
          super_: super_,
          itemsCount: itemsCount,
          esElMejor: mejorIndex >= 0 && index - 1 == mejorIndex,
        );
      },
    );
  }
}

class _ResumenCard extends StatelessWidget {
  final int itemsCount;
  final List<Map<String, dynamic>> supermercados;
  final int mejorIndex;

  const _ResumenCard({
    required this.itemsCount,
    required this.supermercados,
    required this.mejorIndex,
  });

  @override
  Widget build(BuildContext context) {
    if (mejorIndex < 0) {
      // Ningún supermercado tiene todos los productos
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ningún supermercado tiene los $itemsCount productos de tu lista.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mejor = supermercados[mejorIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mejor precio con todos los productos',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              mejor['supermercado_nombre'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${mejor['total']} €',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupermercadoCard extends StatelessWidget {
  final Map<String, dynamic> super_;
  final int itemsCount;
  final bool esElMejor;

  const _SupermercadoCard({
    required this.super_,
    required this.itemsCount,
    required this.esElMejor,
  });

  @override
  Widget build(BuildContext context) {
    final chain = super_['supermercado_cadena'] as String?;
    final style = ChainStyle.forChain(chain);
    final disponibles = super_['productos_disponibles'] as int;
    final faltantes = itemsCount - disponibles;
    final items = (super_['items'] as List).cast<Map<String, dynamic>>();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: style.color,
          child: Text(
            style.initial,
            style: TextStyle(
              color: ThemeData.estimateBrightnessForColor(style.color) ==
                      Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(super_['supermercado_nombre'] as String),
        subtitle: Row(
          children: [
            Text('$disponibles / $itemsCount productos'),
            if (faltantes > 0) ...[
              const SizedBox(width: 8),
              Text(
                'faltan $faltantes',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${super_['total']} €',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: esElMejor ? Theme.of(context).colorScheme.primary : null,
                  ),
            ),
            if (esElMejor)
              const Text('Mejor', style: TextStyle(fontSize: 11)),
          ],
        ),
        children: items.map((item) {
          final precio = item['precio'] as String?;
          final subtotal = item['subtotal'] as String?;
          final cantidad = item['cantidad'] as int;

          return ListTile(
            dense: true,
            title: Text(item['nombre'] as String),
            subtitle: Text('${item['marca']} · ${item['tamano']} × $cantidad'),
            trailing: precio == null
                ? Text(
                    'No disponible',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$subtotal €',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$precio €/u',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          );
        }).toList(),
      ),
    );
  }
}