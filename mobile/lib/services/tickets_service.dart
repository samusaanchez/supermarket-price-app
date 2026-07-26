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

  // Empareja líneas de texto contra el catálogo (clasificación auto/revisar/sin_match).
  Future<List<Map<String, dynamic>>> emparejar(
    List<Map<String, dynamic>> lineas,
  ) async {
    final res = await _api.post(
      '/tickets/emparejar',
      body: {'lineas': lineas},
      auth: true,
    );
    return (res['resultados'] as List).cast<Map<String, dynamic>>();
  }

  // Confirma el ticket: vuelca los precios y lo marca como completado.
  Future<Map<String, dynamic>> confirmar(
    String ticketId, {
    required int supermercadoId,
    required List<Map<String, dynamic>> items,
    String? fechaCompra,
    num? totalTicket,
  }) async {
    final body = <String, dynamic>{
      'supermercado_id': supermercadoId,
      'items': items,
    };
    if (fechaCompra != null) body['fecha_compra'] = fechaCompra;
    if (totalTicket != null) body['total_ticket'] = totalTicket;

    return _api.post('/tickets/$ticketId/confirmar', body: body, auth: true);
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
