import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../services/location_service.dart';
import '../../providers/auth_provider.dart';
import 'chain_marker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/supermercados_service.dart';
import 'supermercado_detail_screen.dart';
import '../catalog/search_screen.dart';
import '../list/lists_screen.dart';
import '../upload/mis_tickets_screen.dart';
import '../profile/profile_screen.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Map<String, dynamic>> _supermercados = [];
  bool _loading = true;
  String? _error;
  final MapController _mapController = MapController();
  Position? _miPosicion;

  // Centro inicial: Nueva Almería, cerca del Mercadona que sembramos
  static const _centroInicial = LatLng(36.823817, -2.440373);

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
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
      // No bloqueante: intenta localizar en paralelo, sin cortar la carga
      _intentarLocalizar(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los supermercados';
        _loading = false;
      });
    }
  }

  Future<void> _intentarLocalizar({bool silent = false}) async {
    try {
      final pos = await context.read<LocationService>().current();
      if (!mounted) return;
      setState(() => _miPosicion = pos);
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } on LocationDeniedException catch (e) {
      if (silent || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (silent || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación')),
      );
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
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Mis tickets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MisTicketsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Buscar productos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Mis listas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListsScreen()),
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            icon: const Icon(Icons.person),
            tooltip: 'Perfil',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _intentarLocalizar(),
        tooltip: 'Centrarme',
        child: const Icon(Icons.my_location),
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
            child: ChainMarker(chain: s['cadena'] as String?),
          ),
        ),
      );
    }).toList();

final marcadoresUsuario = <Marker>[];
    if (_miPosicion != null) {
      marcadoresUsuario.add(
        Marker(
          point: LatLng(_miPosicion!.latitude, _miPosicion!.longitude),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
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
        MarkerLayer(markers: marcadoresUsuario),
      ],
    );
  }
}