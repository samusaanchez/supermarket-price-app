import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/productos_service.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;
  String? _error;
  String _ultimaQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _buscar(query.trim());
    });
  }

  Future<void> _buscar(String query) async {
    if (query == _ultimaQuery) return;
    _ultimaQuery = query;

    if (query.length < 2) {
      setState(() {
        _resultados = [];
        _buscando = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _buscando = true;
      _error = null;
    });

    try {
      final service = context.read<ProductosService>();
      final resultados = await service.buscar(query);
      if (!mounted) return;
      // Si el usuario ya escribió algo distinto mientras esperábamos,
      // descartamos esta respuesta.
      if (query != _ultimaQuery) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (query != _ultimaQuery) return;
      setState(() {
        _error = e.code == 'QUERY_CORTA' ? null : 'Error al buscar';
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (query != _ultimaQuery) return;
      setState(() {
        _error = 'Error al buscar';
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Buscar producto o marca...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_buscando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Escribe al menos 2 caracteres para buscar',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_resultados.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No se han encontrado productos'),
        ),
      );
    }

    return ListView.builder(
      itemCount: _resultados.length,
      itemBuilder: (context, index) {
        final p = _resultados[index];
        return ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.shopping_basket_outlined),
          ),
          title: Text(p['nombre'] as String),
          subtitle: Text('${p['marca']} · ${p['tamano']}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  productoId: p['id'] as String,
                ),
              ),
            );
          },
        );
      },
    );
  }
}