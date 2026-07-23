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
  }) async {
    final query = <String, dynamic>{'page': page};
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
    };
  }

  Future<List<Map<String, dynamic>>> buscar(String query) async {
    final res = await _api.get(
      '/productos/buscar',
      query: {'q': query},
      auth: true,
    );
    final lista = res['productos'] as List;
    return lista.cast<Map<String, dynamic>>();
  }
}