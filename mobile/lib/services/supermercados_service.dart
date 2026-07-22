import 'api_client.dart';

class SupermercadosService {
  final ApiClient _api;

  SupermercadosService(this._api);

  Future<List<Map<String, dynamic>>> list({
    double? lat,
    double? lng,
    double radioKm = 10,
  }) async {
    final query = <String, dynamic>{};
    if (lat != null && lng != null) {
      query['lat'] = lat;
      query['lng'] = lng;
      query['radio'] = radioKm;
    }

    final res = await _api.get(
      '/supermercados',
      query: query.isEmpty ? null : query,
      auth: true,
    );
    final lista = res['supermercados'] as List;
    return lista.cast<Map<String, dynamic>>();
  }
  Future<Map<String, dynamic>> getById(int id) async {
    final res = await _api.get('/supermercados/$id', auth: true);
    return res['supermercado'] as Map<String, dynamic>;
  }
}