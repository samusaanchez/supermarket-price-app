import 'api_client.dart';

class TicketsService {
  final ApiClient _api;

  TicketsService(this._api);

  // Sube la foto del ticket. Devuelve el ticket creado (estado 'pendiente').
  Future<Map<String, dynamic>> subir(
    List<int> bytes,
    String filename, {
    String? mimeType,
  }) async {
    final res = await _api.postMultipart(
      '/tickets',
      bytes: bytes,
      filename: filename,
      field: 'foto',
      contentType: _tipo(mimeType, filename),
      auth: true,
    );
    return res['ticket'] as Map<String, dynamic>;
  }

  // Lista mis tickets (resumen: estado, num_items, supermercado...).
  Future<List<Map<String, dynamic>>> list() async {
    final res = await _api.get('/tickets', auth: true);
    return (res['tickets'] as List).cast<Map<String, dynamic>>();
  }

  // Un ticket con sus líneas (incluye 'items').
  Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get('/tickets/$id', auth: true);
    return res['ticket'] as Map<String, dynamic>;
  }

  // Usa el tipo que da el picker; si no hay, lo deduce por la extensión.
  String _tipo(String? mimeType, String filename) {
    if (mimeType != null && mimeType.isNotEmpty) return mimeType;
    final f = filename.toLowerCase();
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.webp')) return 'image/webp';
    if (f.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
