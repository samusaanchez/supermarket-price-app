import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_client.dart';
import '../../services/productos_service.dart';
import '../../providers/auth_provider.dart';

import '../../services/listas_service.dart';
import '../list/list_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productoId;

  const ProductDetailScreen({super.key, required this.productoId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Map<String, dynamic>? _producto;
  List<Map<String, dynamic>> _precios = [];
  List<Map<String, dynamic>> _fotos = [];
  Map<String, dynamic>? _valoracion;
  int _miCalidad = 0;
  int _miPrecio = 0;
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarFotos();
  }

  Future<void> _cargarFotos() async {
    try {
      final fotos =
          await context.read<ProductosService>().listarFotos(widget.productoId);
      if (!mounted) return;
      setState(() => _fotos = fotos);
    } catch (_) {
      // Si fallan las fotos, no rompemos la ficha.
    }
  }

  Future<void> _subirFoto() async {
    try {
      final img =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (img == null) return;
      final Uint8List bytes = await img.readAsBytes();
      await context.read<ProductosService>().subirFoto(
            widget.productoId,
            bytes,
            img.name,
            mimeType: img.mimeType,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto subida')));
      _cargarFotos();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _eliminarFoto(Map<String, dynamic> foto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Seguro que quieres borrar esta foto?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context
          .read<ProductosService>()
          .eliminarFoto(foto['id'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Foto eliminada')));
      _cargarFotos();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _votarFoto(Map<String, dynamic> foto, int voto) async {
    try {
      await context
          .read<ProductosService>()
          .votarFoto(foto['id'] as String, voto);
      _cargarFotos();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
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
        _valoracion = data['valoracion'] as Map<String, dynamic>?;
        _miCalidad = (_valoracion?['mi_calidad'] as int?) ?? 0;
        _miPrecio = (_valoracion?['mi_precio'] as int?) ?? 0;
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

  Future<void> _anadirALista() async {
    final listasService = context.read<ListasService>();
    List<Map<String, dynamic>> listas;
    try {
      listas = await listasService.list();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar tus listas')),
      );
      return;
    }
    if (!mounted) return;

    final seleccion = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Añadir a una lista', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (listas.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No tienes listas. Crea una desde "Mis listas".'),
                )
              else
                ...listas.map((lista) => ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(lista['nombre'] as String),
                      onTap: () => Navigator.pop(ctx, lista),
                    )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );

    if (seleccion == null || !mounted) return;

    try {
      await listasService.addItem(
        seleccion['id'] as String,
        widget.productoId,
        cantidad: 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Añadido a "${seleccion['nombre']}"'),
          action: SnackBarAction(
            label: 'Ver lista',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ListDetailScreen(
                    listaId: seleccion['id'] as String,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo añadir')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_producto?['nombre'] as String? ?? 'Producto')),
      body: _buildBody(),
      floatingActionButton: _producto == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _anadirALista,
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Añadir a lista'),
            ),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: _fotos.isNotEmpty
                    ? Image.network(
                        '${ApiClient.origin}${_fotos.first['url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcono(),
                      )
                    : _placeholderIcono(),
              ),
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
        _buildFotos(),
        const SizedBox(height: 24),
        _buildValoracion(),
        const SizedBox(height: 24),
        Text(
          'Precios en supermercados cercanos',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          'Mantén pulsado un precio para reportarlo si es incorrecto',
          style: Theme.of(context).textTheme.bodySmall,
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
                onLongPress: () => _reportarPrecio(precio),
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

  Future<String?> _pedirMotivo(String titulo) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            hintText: 'Ej: el precio ha subido, la foto es de otro producto…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enviar')),
        ],
      ),
    );
  }

  Future<void> _reportarPrecio(Map<String, dynamic> precio) async {
    final motivo = await _pedirMotivo('Reportar precio incorrecto');
    if (motivo == null) return; // canceló
    try {
      await context
          .read<ProductosService>()
          .reportarPrecio(precio['precio_id'] as String, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias, lo revisaremos')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _reportarFoto(Map<String, dynamic> foto) async {
    final motivo = await _pedirMotivo('Reportar foto incorrecta');
    if (motivo == null) return;
    try {
      await context
          .read<ProductosService>()
          .reportarFoto(foto['id'] as String, motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias, lo revisaremos')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _valorar() async {
    if (_miCalidad == 0 || _miPrecio == 0) return;
    try {
      final v = await context
          .read<ProductosService>()
          .valorar(widget.productoId, _miCalidad, _miPrecio);
      if (!mounted) return;
      setState(() => _valoracion = v);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Gracias por tu valoración!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Widget _buildValoracion() {
    final total = _valoracion?['total'] ?? 0;
    final calidadMedia = _valoracion?['calidad_media'];
    final precioMedia = _valoracion?['precio_media'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Valoración', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (total == 0)
          const Text('Aún no tiene valoraciones. ¡Sé el primero!')
        else ...[
          _mediaFila('Calidad', calidadMedia),
          const SizedBox(height: 4),
          _mediaFila('Precio', precioMedia),
          const SizedBox(height: 4),
          Text(
            '$total ${total == 1 ? "valoración" : "valoraciones"} · el precio es la percepción de la gente, no el precio real',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const Divider(height: 24),
        Text('Tu valoración', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        _estrellasInteractivas(
            'Calidad', _miCalidad, (n) => setState(() => _miCalidad = n)),
        _estrellasInteractivas(
            'Precio', _miPrecio, (n) => setState(() => _miPrecio = n)),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: (_miCalidad > 0 && _miPrecio > 0) ? _valorar : null,
          child: const Text('Guardar valoración'),
        ),
      ],
    );
  }

  Widget _mediaFila(String label, dynamic media) {
    final valor = double.tryParse('${media ?? 0}') ?? 0;
    final n = valor.round();
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        ...List.generate(
          5,
          (i) => Icon(i < n ? Icons.star : Icons.star_border,
              size: 18, color: Colors.amber),
        ),
        const SizedBox(width: 6),
        Text(valor.toStringAsFixed(1)),
      ],
    );
  }

  Widget _estrellasInteractivas(
      String label, int actual, ValueChanged<int> onTap) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        ...List.generate(
          5,
          (i) => IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(i < actual ? Icons.star : Icons.star_border,
                color: Colors.amber),
            onPressed: () => onTap(i + 1),
          ),
        ),
      ],
    );
  }

  Widget _placeholderIcono() {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.shopping_basket_outlined, size: 32),
    );
  }

  Widget _buildFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Fotos', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            FilledButton.icon(
              onPressed: _subirFoto,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Añadir foto'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_fotos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Aún no hay fotos. Sé el primero en subir una.'),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fotos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _fotoCard(_fotos[i]),
            ),
          ),
      ],
    );
  }

  Widget _fotoCard(Map<String, dynamic> f) {
    final estado = f['estado'] as String? ?? 'pendiente';
    final pos = f['votos_positivos'] ?? 0;
    final neg = f['votos_negativos'] ?? 0;
    final miId = context.read<AuthProvider>().user?['id'];
    final esMia = miId != null && f['usuario_id'] == miId;

    return SizedBox(
      width: 150,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 118,
                  width: double.infinity,
                  child: Image.network(
                    '${ApiClient.origin}${f['url']}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0x11000000),
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
                if (estado == 'verificada')
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('✓ verificada',
                          style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                if (esMia)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _eliminarFoto(f),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.delete,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (!esMia)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _reportarFoto(f),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.flag,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _votarFoto(f, 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.thumb_up, size: 14),
                        const SizedBox(width: 4),
                        Text('$pos'),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _votarFoto(f, -1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.thumb_down, size: 14),
                        const SizedBox(width: 4),
                        Text('$neg'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}