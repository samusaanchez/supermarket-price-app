import 'api_client.dart';

class ListasService {
  final ApiClient _api;

  ListasService(this._api);

  Future<List<Map<String, dynamic>>> list() async {
    final res = await _api.get('/listas', auth: true);
    return (res['listas'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(String nombre) async {
    final res = await _api.post(
      '/listas',
      body: {'nombre': nombre},
      auth: true,
    );
    return res['lista'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get('/listas/$id', auth: true);
    return {
      'lista': res['lista'] as Map<String, dynamic>,
      'items': (res['items'] as List).cast<Map<String, dynamic>>(),
    };
  }

  Future<Map<String, dynamic>> rename(String id, String nombre) async {
    final res = await _api.patch(
      '/listas/$id',
      body: {'nombre': nombre},
      auth: true,
    );
    return res['lista'] as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _api.delete('/listas/$id', auth: true);
  }

  Future<Map<String, dynamic>> addItem(
    String listaId,
    String productoId, {
    int cantidad = 1,
  }) async {
    final res = await _api.post(
      '/listas/$listaId/items',
      body: {'producto_id': productoId, 'cantidad': cantidad},
      auth: true,
    );
    return res['item'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateItem(
    String listaId,
    String itemId,
    int cantidad,
  ) async {
    final res = await _api.patch(
      '/listas/$listaId/items/$itemId',
      body: {'cantidad': cantidad},
      auth: true,
    );
    return res['item'] as Map<String, dynamic>;
  }

  Future<void> removeItem(String listaId, String itemId) async {
    await _api.delete('/listas/$listaId/items/$itemId', auth: true);
  }

  Future<Map<String, dynamic>> comparar(String listaId) async {
    final res = await _api.get('/listas/$listaId/comparar', auth: true);
    return res;
  }
}