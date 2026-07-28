import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/listas_service.dart';
import 'list_detail_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  List<Map<String, dynamic>> _listas = [];
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
      final listas = await service.list();
      if (!mounted) return;
      setState(() {
        _listas = listas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus listas';
        _loading = false;
      });
    }
  }

  Future<void> _crear() async {
    final nombre = await _pedirNombre(context, titulo: 'Nueva lista');
    if (nombre == null || !mounted) return;

    try {
      final service = context.read<ListasService>();
      await service.create(nombre);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la lista')),
      );
    }
  }

  Future<void> _renombrar(Map<String, dynamic> lista) async {
    final nombre = await _pedirNombre(
      context,
      titulo: 'Renombrar lista',
      inicial: lista['nombre'] as String,
    );
    if (nombre == null || !mounted) return;

    try {
      final service = context.read<ListasService>();
      await service.rename(lista['id'] as String, nombre);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo renombrar')),
      );
    }
  }

  Future<void> _borrar(Map<String, dynamic> lista) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar lista?'),
        content: Text('Vas a borrar "${lista['nombre']}" y todos sus productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    try {
      final service = context.read<ListasService>();
      await service.delete(lista['id'] as String);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo borrar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis listas')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _crear,
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
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
    if (_listas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no tienes ninguna lista.\nCrea una con el botón "+" de abajo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _listas.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final lista = _listas[index];
        final numItems = lista['num_items'] as int? ?? 0;
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.list_alt)),
          title: Text(lista['nombre'] as String),
          subtitle: Text('$numItems ${numItems == 1 ? "producto" : "productos"}'),
          trailing: PopupMenuButton<String>(
            onSelected: (accion) {
              if (accion == 'renombrar') _renombrar(lista);
              if (accion == 'borrar') _borrar(lista);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'renombrar', child: Text('Renombrar')),
              PopupMenuItem(value: 'borrar', child: Text('Borrar')),
            ],
          ),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ListDetailScreen(listaId: lista['id'] as String),
              ),
            );
            _cargar(); // al volver, recargamos por si cambió num_items
          },
        );
      },
    );
  }
}

Future<String?> _pedirNombre(
  BuildContext context, {
  required String titulo,
  String inicial = '',
}) {
  final controller = TextEditingController(text: inicial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 255,
        decoration: const InputDecoration(
          hintText: 'Ej: Compra semanal',
        ),
        onSubmitted: (value) {
          final nombre = value.trim();
          if (nombre.isNotEmpty) Navigator.pop(ctx, nombre);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final nombre = controller.text.trim();
            if (nombre.isNotEmpty) Navigator.pop(ctx, nombre);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}