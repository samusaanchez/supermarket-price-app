import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/supermercados_service.dart';
import 'supermercado_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Map<String, dynamic>> _supermercados = [];
  bool _loading = true;
  String? _error;

  // Centro inicial: Nueva Almería, cerca del Mercadona que sembramos
  static const _centroInicial = LatLng(36.823817, -2.440373);

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
      final lista = await service.list();
      if (!mounted) return;
      setState(() {
        _supermercados = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los supermercados';
        _loading = false;
      });
    }
  }
  void _abrirDetalle(int id, String nombre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupermercadoDetailScreen(supermercadoId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supermercados'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
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

    final marcadores = _supermercados.map((s) {
      final lat = double.parse(s['lat'] as String);
      final lng = double.parse(s['lng'] as String);
      return Marker(
        point: LatLng(lat, lng),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _abrirDetalle(s['id'] as int, s['nombre'] as String),
          child: Tooltip(
            message: s['nombre'] as String,
            child: const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ),
        ),
      );
    }).toList();

    return FlutterMap(
      options: const MapOptions(
        initialCenter: _centroInicial,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.supermarketapp.mobile',
        ),
        MarkerLayer(markers: marcadores),
      ],
    );
  }
}