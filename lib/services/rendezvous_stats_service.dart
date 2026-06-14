import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/commission_models.dart';
import '../core/storage/token_storage.dart';

class RendezvousStatsService {
  static const String _base = 'https://api.atla.business/api/v1';

  Future<DriverCommissionStats?> fetchCommissionStats(String month) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;

    final uri = Uri.parse('$_base/m/rendezvous/commission?month=$month');
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] is Map ? body['data'] as Map<String, dynamic> : body;
    return DriverCommissionStats.fromJson(data);
  }

  /// Fallback: build stats from local rendezvous list when backend not ready
  DriverCommissionStats buildFromLocal(
    List<dynamic> rdvList,
    String month,
    String currency,
  ) {
    return DriverCommissionStats.fromRendezvousList(rdvList, month, currency);
  }
}
