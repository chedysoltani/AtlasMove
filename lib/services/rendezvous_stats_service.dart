import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/commission_models.dart';
import '../core/storage/token_storage.dart';

class RendezvousStatsService {
  static const String _base = 'https://api.atla.business/api/v1';

  Future<DriverCommissionStats?> fetchCommissionStats(
    String month, {
    double? latitude,
    double? longitude,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;

    final params = <String, String>{'month': month};
    if (latitude != null) params['latitude'] = latitude.toStringAsFixed(6);
    if (longitude != null) params['longitude'] = longitude.toStringAsFixed(6);
    final uri = Uri.parse('$_base/m/rendezvous/commission')
        .replace(queryParameters: params);
    debugPrint('📊 commission uri: $uri');
    final res = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    debugPrint('📊 commission body: $body');
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
