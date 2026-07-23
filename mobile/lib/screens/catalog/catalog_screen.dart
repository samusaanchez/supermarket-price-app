import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/productos_service.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final int supermercadoId;
  final String supermercadoNombre;

  const CatalogScreen({
    super.key,
    required this.supermercadoId,
    required this.supermercadoNombre,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _categorias = [];
  bool _loadingCategorias = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    setState(() {
      _loadingCategorias = true;
      _error = null;
    });
    try {
      final service = context.read<ProductosService>();
      final categorias = await service.categorias();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _loadingCategorias = false;
        // +1 pestaña para "Todas"
        _tabController = TabController(length: categorias.length + 1, vsync: this);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las categorías';
        _loadingCategorias = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCategorias) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.supermercadoNombre)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.supermercadoNombre)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _cargarCategorias,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supermercadoNombre),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            const Tab(text: 'Todas'),
            ..._categorias.map((c) => Tab(text: c['nombre'] as String)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProductGrid(
            supermercadoId: widget.supermercadoId,
            categoriaId: null,
          ),
          ..._categorias.map((c) => _ProductGrid(
                supermercadoId: widget.supermercadoId,
                categoriaId: c['id'] as int,
              )),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatefulWidget {
  final int supermercadoId;
  final int? categoriaId;

  const _ProductGrid({required this.supermercadoId, required this.categoriaId});

  @override
  State<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<_ProductGrid>
    with AutomaticKeepAliveClientMixin {
  final List<Map<String, dynamic>> _productos = [];
  int _page = 1;
  int _totalPaginas = 1;
  bool _loading = true;
  bool _loadingMas = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final res = await service.listar(
        supermercadoId: widget.supermercadoId,
        categoriaId: widget.categoriaId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _productos
          ..clear()
          ..addAll(res['productos'] as List<Map<String, dynamic>>);
        _page = 1;
        _totalPaginas = res['paginacion']['total_paginas'] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los productos';
        _loading = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_page >= _totalPaginas || _loadingMas) return;
    setState(() => _loadingMas = true);
    try {
      final service = context.read<ProductosService>();
      final res = await service.listar(
        supermercadoId: widget.supermercadoId,
        categoriaId: widget.categoriaId,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _productos.addAll(res['productos'] as List<Map<String, dynamic>>);
        _page++;
        _loadingMas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar más productos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // requerido por AutomaticKeepAliveClientMixin

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
    if (_productos.isEmpty) {
      return const Center(child: Text('No hay productos en esta categoría'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _productos.length + (_page < _totalPaginas ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _productos.length) {
          // Última celda: botón "cargar más"
          _cargarMas();
          return const Center(child: CircularProgressIndicator());
        }
        return _ProductCard(producto: _productos[index]);
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> producto;

  const _ProductCard({required this.producto});

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
    final precio = producto['precio_actual'] as String?;
    final fecha = producto['fecha_precio'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productoId: producto['id'] as String,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_basket_outlined, size: 32),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                producto['nombre'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '${producto['marca']} · ${producto['tamano']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              if (precio != null) ...[
                Text(
                  '$precio €',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  _tiempoDesde(fecha),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else
                Text(
                  'Sin precio',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}