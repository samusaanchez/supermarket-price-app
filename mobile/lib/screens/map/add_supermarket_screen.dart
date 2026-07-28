import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/supermercados_service.dart';
import '../../services/api_client.dart';

class AddSupermarketScreen extends StatefulWidget {
  const AddSupermarketScreen({super.key});

  @override
  State<AddSupermarketScreen> createState() => _AddSupermarketScreenState();
}

class _AddSupermarketScreenState extends State<AddSupermarketScreen> {
  final _nombre = TextEditingController();
  final _cadena = TextEditingController();
  final _direccion = TextEditingController();
  LatLng? _punto;
  bool _guardando = false;

  static const _centroInicial = LatLng(36.8381, -2.4597); // Almería

  Future<void> _guardar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      _snack('Ponle un nombre al supermercado');
      return;
    }
    if (_punto == null) {
      _snack('Toca el mapa para marcar la ubicación');
      return;
    }
    setState(() => _guardando = true);
    try {
      final nuevo = await context.read<SupermercadosService>().crear(
            nombre: nombre,
            cadena: _cadena.text.trim(),
            direccion: _direccion.text.trim(),
            lat: _punto!.latitude,
            lng: _punto!.longitude,
          );
      if (!mounted) return;
      _snack('Supermercado "${nuevo['nombre']}" añadido');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _snack('Error: ${e.message}');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Añadir supermercado')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _nombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cadena,
                  decoration: const InputDecoration(
                    labelText: 'Cadena (Mercadona, Lidl…)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _direccion,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _punto == null
                    ? 'Toca el mapa para marcar dónde está'
                    : 'Ubicación: ${_punto!.latitude.toStringAsFixed(5)}, ${_punto!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _centroInicial,
                initialZoom: 14,
                onTap: (_, latlng) => setState(() => _punto = latlng),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.supermarketapp.mobile',
                ),
                if (_punto != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _punto!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                    ],
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
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar supermercado'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
