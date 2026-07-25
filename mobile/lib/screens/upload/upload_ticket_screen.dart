import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../services/tickets_service.dart';
import '../../services/api_client.dart';

class UploadTicketScreen extends StatefulWidget {
  const UploadTicketScreen({super.key});

  @override
  State<UploadTicketScreen> createState() => _UploadTicketScreenState();
}

class _UploadTicketScreenState extends State<UploadTicketScreen> {
  final _picker = ImagePicker();
  XFile? _imagen;
  Uint8List? _bytes;
  bool _subiendo = false;
  bool _arrastrando = false; // para resaltar la zona al arrastrar encima

  // Punto único: tanto elegir como arrastrar terminan aquí.
  Future<void> _usarImagen(XFile img) async {
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imagen = img;
      _bytes = bytes;
      _arrastrando = false;
    });
  }

  // Abre galería o cámara.
  Future<void> _elegir(ImageSource source) async {
    try {
      final img = await _picker.pickImage(source: source, imageQuality: 85);
      if (img == null) return; // el usuario canceló
      await _usarImagen(img);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la imagen: $e')),
      );
    }
  }

  Future<void> _subir() async {
    if (_bytes == null || _imagen == null) return;
    setState(() => _subiendo = true);
    try {
      final tickets = context.read<TicketsService>();
      final ticket = await tickets.subir(
        _bytes!,
        _imagen!.name,
        mimeType: _imagen!.mimeType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket subido (estado: ${ticket['estado']})')),
      );
      Navigator.pop(context, ticket);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subir ticket')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: DropTarget(
                onDragEntered: (_) => setState(() => _arrastrando = true),
                onDragExited: (_) => setState(() => _arrastrando = false),
                onDragDone: (detail) async {
                  if (detail.files.isEmpty) return;
                  await _usarImagen(detail.files.first);
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _arrastrando ? colores.primary : colores.outlineVariant,
                      width: _arrastrando ? 2.5 : 1.5,
                    ),
                    color: _arrastrando
                        ? colores.primary.withValues(alpha: 0.06)
                        : null,
                  ),
                  child: Center(
                    child: _bytes == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 48, color: colores.outline),
                              const SizedBox(height: 8),
                              const Text('Arrastra la imagen aquí'),
                              const Text('o usa los botones de abajo',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_bytes!),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _subiendo ? null : () => _elegir(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _subiendo ? null : () => _elegir(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_bytes == null || _subiendo) ? null : _subir,
                child: _subiendo
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Subir ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
