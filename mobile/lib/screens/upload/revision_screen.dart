import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/tickets_service.dart';
import '../../services/productos_service.dart';
import '../../services/supermercados_service.dart';
import '../../services/api_client.dart';

// Estado de una línea en revisión.
class _Linea {
  String texto;
  final TextEditingController precioCtrl;
  String clasificacion; // '', 'auto', 'revisar', 'sin_match'
  List<Map<String, dynamic>> candidatos;
  String? productoId;
  String? productoNombre;
  bool confirmada;
  bool descartada;

  _Linea(this.texto, String precioInicial)
      : precioCtrl = TextEditingController(text: precioInicial),
        clasificacion = '',
        candidatos = [],
        confirmada = false,
        descartada = false;

  double? get precio =>
      double.tryParse(precioCtrl.text.replaceAll(',', '.').trim());
}

class RevisionScreen extends StatefulWidget {
  final String ticketId;

  const RevisionScreen({super.key, required this.ticketId});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final List<_Linea> _lineas = [];
  List<Map<String, dynamic>> _supermercados = [];
  int? _supermercadoId;
  bool _cargando = true;
  bool _analizando = false;
  bool _confirmando = false;

  @override
  void initState() {
    super.initState();
    _cargarSupermercados();
  }

  Future<void> _cargarSupermercados() async {
    try {
      final lista = await context.read<SupermercadosService>().list();
      if (!mounted) return;
      setState(() {
        _supermercados = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      _snack('No se pudieron cargar los supermercados: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _nombreProd(Map<String, dynamic> c) {
    final tam = (c['tamano'] ?? '').toString();
    return '${c['nombre']} · ${c['marca']} $tam'.trim();
  }

  // --- Acciones sobre líneas ---

  Future<void> _anadirLinea() async {
    final textoCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir línea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textoCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Texto (como aparece en el ticket)',
              ),
            ),
            TextField(
              controller: precioCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Añadir')),
        ],
      ),
    );
    if (ok == true && textoCtrl.text.trim().isNotEmpty) {
      setState(() =>
          _lineas.add(_Linea(textoCtrl.text.trim(), precioCtrl.text.trim())));
    }
  }

  Future<void> _analizar() async {
    if (_lineas.isEmpty) return;
    setState(() => _analizando = true);
    try {
      final payload = _lineas
          .map((l) => {'texto': l.texto, 'precio': l.precio})
          .toList();
      final resultados =
          await context.read<TicketsService>().emparejar(payload);

      for (var i = 0; i < _lineas.length && i < resultados.length; i++) {
        final r = resultados[i];
        final cls = r['clasificacion'] as String;
        final candidatos =
            (r['candidatos'] as List).cast<Map<String, dynamic>>();
        final l = _lineas[i];
        l.clasificacion = cls;
        l.candidatos = candidatos;
        if (cls == 'auto' && candidatos.isNotEmpty) {
          l.productoId = candidatos.first['id'] as String;
          l.productoNombre = _nombreProd(candidatos.first);
          l.confirmada = true; // alta confianza: aceptada
        } else if (cls == 'revisar' && candidatos.isNotEmpty) {
          l.productoId = candidatos.first['id'] as String;
          l.productoNombre = _nombreProd(candidatos.first);
          l.confirmada = false; // propuesta, pendiente de tu ok
        } else {
          l.productoId = null;
          l.productoNombre = null;
          l.confirmada = false;
        }
      }
      setState(() {});
    } on ApiException catch (e) {
      _snack('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  Future<void> _cambiarProducto(_Linea l) async {
    final prod = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BuscarProductoSheet(textoInicial: l.texto),
    );
    if (prod != null) {
      setState(() {
        l.productoId = prod['id'] as String;
        l.productoNombre = _nombreProd(prod);
        l.confirmada = true;
      });
    }
  }

  Future<void> _crearProducto(_Linea l) async {
    final prod = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CrearProductoDialog(textoInicial: l.texto),
    );
    if (prod != null) {
      setState(() {
        l.productoId = prod['id'] as String;
        l.productoNombre = _nombreProd(prod);
        l.confirmada = true;
      });
    }
  }

  bool get _puedeConfirmar {
    if (_supermercadoId == null) return false;
    final activas = _lineas.where((l) => !l.descartada).toList();
    if (activas.isEmpty) return false;
    return activas.every((l) =>
        l.confirmada && l.productoId != null && (l.precio ?? 0) > 0);
  }

  Future<void> _confirmar() async {
    if (!_puedeConfirmar) return;
    setState(() => _confirmando = true);
    try {
      final items = _lineas
          .where((l) => !l.descartada && l.productoId != null)
          .map((l) => {
                'producto_id': l.productoId,
                'precio': l.precio ?? 0,
                'texto_ocr': l.texto,
              })
          .toList();
      final res = await context.read<TicketsService>().confirmar(
            widget.ticketId,
            supermercadoId: _supermercadoId!,
            items: items,
          );
      if (!mounted) return;
      _snack('Ticket confirmado · ${res['precios_actualizados']} precios');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack('Error: ${e.message}');
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  // --- UI ---

  ({String texto, Color color}) _estado(_Linea l) {
    if (l.descartada) return (texto: 'Descartada', color: Colors.grey);
    if (l.confirmada && l.productoId != null) {
      return (texto: 'OK', color: Colors.green);
    }
    if (l.clasificacion == 'revisar') {
      return (texto: 'Revisar', color: Colors.orange);
    }
    if (l.clasificacion == 'sin_match') {
      return (texto: 'Falta producto', color: Colors.red);
    }
    if (l.clasificacion.isEmpty) {
      return (texto: 'Sin analizar', color: Colors.blueGrey);
    }
    return (texto: 'Revisar', color: Colors.orange);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final analizado = _lineas.any((l) => l.clasificacion.isNotEmpty);
    final atencion = _lineas
        .where((l) => !l.descartada && !(l.confirmada && l.productoId != null))
        .toList();
    final resueltas = _lineas
        .where((l) => l.descartada || (l.confirmada && l.productoId != null))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar ticket')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Supermercado',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _supermercadoId,
                  hint: const Text('Elige supermercado'),
                  items: _supermercados
                      .map((s) => DropdownMenuItem<int>(
                            value: s['id'] as int,
                            child: Text(s['nombre'] as String),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _supermercadoId = v),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _anadirLinea,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir línea'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed:
                      (_lineas.isEmpty || _analizando) ? null : _analizar,
                  icon: _analizando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('Analizar'),
                ),
              ],
            ),
          ),
          if (analizado)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (atencion.isEmpty ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                atencion.isEmpty
                    ? 'Todo cuadra. Revisa y confirma.'
                    : '${atencion.length} ${atencion.length == 1 ? "producto necesita" : "productos necesitan"} tu atención',
                style: TextStyle(
                  color: atencion.isEmpty
                      ? Colors.green.shade800
                      : Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _lineas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Añade las líneas del ticket y pulsa Analizar.\n'
                        '(En móvil las rellenará el OCR.)',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      // Solo lo que requiere acción, arriba y visible.
                      ...atencion.map(_filaLinea),
                      // Lo que ya cuadra, plegado.
                      if (resueltas.isNotEmpty)
                        ExpansionTile(
                          title: Text(
                            '${resueltas.length} ${resueltas.length == 1 ? "producto reconocido" : "productos reconocidos"} ✓',
                          ),
                          children: resueltas.map(_filaLinea).toList(),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      (!_puedeConfirmar || _confirmando) ? null : _confirmar,
                  child: _confirmando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Confirmar y guardar precios'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaLinea(_Linea l) {
    final est = _estado(l);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: est.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(est.texto,
                      style: TextStyle(
                          color: est.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'confirmar':
                        if (l.productoId != null) {
                          setState(() => l.confirmada = true);
                        } else {
                          _snack('Esta línea no tiene producto; elige o crea uno');
                        }
                        break;
                      case 'cambiar':
                        _cambiarProducto(l);
                        break;
                      case 'crear':
                        _crearProducto(l);
                        break;
                      case 'descartar':
                        setState(() => l.descartada = !l.descartada);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'confirmar', child: Text('Confirmar')),
                    const PopupMenuItem(
                        value: 'cambiar', child: Text('Cambiar producto')),
                    const PopupMenuItem(
                        value: 'crear', child: Text('Crear producto')),
                    PopupMenuItem(
                        value: 'descartar',
                        child: Text(l.descartada ? 'Recuperar' : 'Descartar')),
                  ],
                ),
              ],
            ),
            Text(l.texto,
                style: TextStyle(
                    decoration:
                        l.descartada ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            Text(
              l.productoNombre ?? 'Sin producto',
              style: TextStyle(
                fontSize: 13,
                color: l.productoNombre == null ? Colors.red : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: l.precioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      isDense: true,
                      border: OutlineInputBorder(),
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

// --- Bottom sheet de búsqueda de producto ---

class _BuscarProductoSheet extends StatefulWidget {
  final String textoInicial;

  const _BuscarProductoSheet({required this.textoInicial});

  @override
  State<_BuscarProductoSheet> createState() => _BuscarProductoSheetState();
}

class _BuscarProductoSheetState extends State<_BuscarProductoSheet> {
  late TextEditingController _ctrl;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.textoInicial);
    _buscar();
  }

  Future<void> _buscar() async {
    final q = _ctrl.text.trim();
    if (q.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final r = await context.read<ProductosService>().buscar(q);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 440,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar producto…',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                      icon: const Icon(Icons.search), onPressed: _buscar),
                ),
                onSubmitted: (_) => _buscar(),
              ),
            ),
            if (_buscando) const LinearProgressIndicator(),
            Expanded(
              child: _resultados.isEmpty
                  ? const Center(child: Text('Sin resultados'))
                  : ListView.builder(
                      itemCount: _resultados.length,
                      itemBuilder: (_, i) {
                        final p = _resultados[i];
                        return ListTile(
                          title: Text('${p['nombre']} · ${p['marca']}'),
                          subtitle:
                              Text('${p['tamano']} ${p['presentacion']}'),
                          onTap: () => Navigator.pop(context, p),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Diálogo de crear producto ---

class _CrearProductoDialog extends StatefulWidget {
  final String textoInicial;

  const _CrearProductoDialog({required this.textoInicial});

  @override
  State<_CrearProductoDialog> createState() => _CrearProductoDialogState();
}

class _CrearProductoDialogState extends State<_CrearProductoDialog> {
  late TextEditingController _nombre;
  final _marca = TextEditingController();
  final _tamano = TextEditingController();
  final _presentacion = TextEditingController();
  final _variante = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.textoInicial);
  }

  Future<void> _guardar() async {
    if (_nombre.text.trim().isEmpty ||
        _marca.text.trim().isEmpty ||
        _tamano.text.trim().isEmpty ||
        _presentacion.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rellena nombre, marca, tamaño y presentación')));
      return;
    }
    setState(() => _guardando = true);
    try {
      final prod = await context.read<ProductosService>().crear(
            nombre: _nombre.text.trim(),
            marca: _marca.text.trim(),
            tamano: _tamano.text.trim(),
            presentacion: _presentacion.text.trim(),
            variante: _variante.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, prod);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
                controller: _marca,
                decoration: const InputDecoration(labelText: 'Marca')),
            TextField(
                controller: _tamano,
                decoration:
                    const InputDecoration(labelText: 'Tamaño (p.ej. 500g)')),
            TextField(
                controller: _presentacion,
                decoration: const InputDecoration(
                    labelText: 'Presentación (p.ej. paquete)')),
            TextField(
                controller: _variante,
                decoration:
                    const InputDecoration(labelText: 'Variante (opcional)')),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }
}
