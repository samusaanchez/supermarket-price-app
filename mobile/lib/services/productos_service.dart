import 'api_client.dart';

class ProductosService {
  final ApiClient _api;

  ProductosService(this._api);

  Future<List<Map<String, dynamic>>> categorias() async {
    final res = await _api.get('/categorias', auth: true);
    final lista = res['categorias'] as List;
    return lista.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> listar({
    int? supermercadoId,
    int? categoriaId,
    int page = 1,
    String orden = 'nombre',
  }) async {
    final query = <String, dynamic>{'page': page, 'orden': orden};
    if (supermercadoId != null) query['supermercado_id'] = supermercadoId;
    if (categoriaId != null) query['categoria_id'] = categoriaId;

    final res = await _api.get('/productos', query: query, auth: true);
    return {
      'productos': (res['productos'] as List).cast<Map<String, dynamic>>(),
      'paginacion': res['paginacion'] as Map<String, dynamic>,
    };
  }

  Future<Map<String, dynamic>> detalle(String productoId) async {
    final res = await _api.get('/productos/$productoId', auth: true);
    return {
      'producto': res['producto'] as Map<String, dynamic>,
      'precios': (res['precios'] as List).cast<Map<String, dynamic>>(),
      'valoracion': res['valoracion'] as Map<String, dynamic>?,
    };
  }

  // Valorar un producto (calidad y precio, 1-5). Devuelve las medias nuevas.
  Future<Map<String, dynamic>> valorar(
    String productoId,
    int calidad,
    int precio,
  ) async {
    final res = await _api.post(
      '/productos/$productoId/valoraciones',
      body: {'calidad': calidad, 'precio': precio},
      auth: true,
    );
    return res['valoracion'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> buscar(
    String query, {
    int? supermercadoId,
  }) async {
    final q = <String, dynamic>{'q': query};
    if (supermercadoId != null) q['supermercado_id'] = supermercadoId;
    final res = await _api.get('/productos/buscar', query: q, auth: true);
    final lista = res['productos'] as List;
    return lista.cast<Map<String, dynamic>>();
  }

  // Busca un producto en Open Food Facts por su código de barras.
  Future<Map<String, dynamic>> buscarPorCodigo(String codigo) async {
    final res = await _api.get('/productos/barcode/$codigo', auth: true);
    return res['producto'] as Map<String, dynamic>;
  }

  // Crea un producto nuevo (o devuelve el existente si ya estaba).
  Future<Map<String, dynamic>> crear({
    required String nombre,
    required String marca,
    required String tamano,
    required String presentacion,
    String variante = '',
    int? categoriaId,
    num? cantidadValor,
    String? cantidadUnidad,
    String? codigoBarras,
  }) async {
    final body = <String, dynamic>{
      'nombre': nombre,
      'marca': marca,
      'tamano': tamano,
      'presentacion': presentacion,
      'variante': variante,
    };
    if (categoriaId != null) body['categoria_id'] = categoriaId;
    if (cantidadValor != null) body['cantidad_valor'] = cantidadValor;
    if (cantidadUnidad != null) body['cantidad_unidad'] = cantidadUnidad;
    if (codigoBarras != null && codigoBarras.isNotEmpty) {
      body['codigo_barras'] = codigoBarras;
    }

    final res = await _api.post('/productos', body: body, auth: true);
    return res['producto'] as Map<String, dynamic>;
  }

  // --- Fotos de producto ---

  Future<List<Map<String, dynamic>>> listarFotos(String productoId) async {
    final res = await _api.get('/fotos',
        query: {'producto_id': productoId}, auth: true);
    return (res['fotos'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> subirFoto(
    String productoId,
    List<int> bytes,
    String filename, {
    String? mimeType,
  }) async {
    final res = await _api.postMultipart(
      '/fotos',
      bytes: bytes,
      filename: filename,
      field: 'foto',
      contentType: _tipoImagen(mimeType, filename),
      fields: {'producto_id': productoId},
      auth: true,
    );
    return res['foto'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> votarFoto(String fotoId, int voto) async {
    final res = await _api.post('/fotos/$fotoId/votos',
        body: {'voto': voto}, auth: true);
    return res['foto'] as Map<String, dynamic>;
  }

  Future<void> eliminarFoto(String fotoId) async {
    await _api.delete('/fotos/$fotoId', auth: true);
  }

  // --- Reclamaciones ---

  Future<void> reportarPrecio(String precioId, String? motivo) async {
    await _api.post('/reclamaciones', body: {
      'tipo': 'precio',
      'precio_id': precioId,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
    }, auth: true);
  }

  Future<void> reportarFoto(String fotoId, String? motivo) async {
    await _api.post('/reclamaciones', body: {
      'tipo': 'foto',
      'foto_id': fotoId,
      if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
    }, auth: true);
  }

  String _tipoImagen(String? mimeType, String filename) {
    if (mimeType != null && mimeType.isNotEmpty) return mimeType;
    final f = filename.toLowerCase();
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}