import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import 'driver_service.dart';
import 'location_service.dart';

// Callback déclenché quand le backend détecte une vitesse anormale (anti-spoofing)
typedef OnGpsSpoofingDetected = void Function();

/// Publie la position du chauffeur au backend selon DEUX cadences :
///
/// | Situation                          | Endpoint                    | Cadence   |
/// |------------------------------------|-----------------------------|-----------|
/// | En ligne, **sans course**          | `PATCH /l/trips/location`   | ~45 s     |
/// | **Course en cours** (acceptée → …) | `POST  /trips/location`     | ~5 s      |
///
/// Le mode « sans course » est indispensable : le ciblage « nouvelle course »
/// du backend ne retient que les chauffeurs ayant une position de moins de
/// 10 min. Un chauffeur inactif qui n'envoie rien ne reçoit jamais de course.
///
/// Erreurs de `POST /trips/location` :
/// - 409 `no_active_trip` / `trip_not_active` : la position est quand même
///   enregistrée ; on repasse en mode « sans course » (on n'arrête PAS d'envoyer) ;
/// - 429 `location_rate_limited` : on attend `retryAfter` ;
/// - 400 `gps_spoofing_detected` : le fix est abandonné.
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  final LocationService _locationService = LocationService();

  static const _activeSendInterval = Duration(seconds: 5); // le serveur plafonne à 1 / 2 s
  static const _activeHeartbeat = Duration(seconds: 10); // chauffeur immobile : pas d'évènement GPS
  static const _idleInterval = Duration(seconds: 45); // consigne backend : 30–60 s

  bool _isTracking = false;
  bool _sending = false;
  String? _activeTripId;
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  DateTime? _lastSentAt;
  DateTime? _blockedUntil; // fin d'un 429

  OnGpsSpoofingDetected? onGpsSpoofingDetected;

  bool get isTracking => _isTracking;

  /// Course en cours suivie par le client (null = chauffeur sans course).
  String? get activeTripId => _activeTripId;

  // token param kept for API compatibility but ignored — HttpClient handles auth + refresh
  Future<void> startLocationTracking([String? token]) async {
    if (_isTracking) return;
    _isTracking = true;
    DriverService.isOnlineNotifier.addListener(_onOnlineChanged);
    try {
      await _configure();
      unawaited(_tick(force: true));
    } catch (e) {
      debugPrint('LocationTrackingService.start: ${e.runtimeType}');
    }
  }

  /// La course vient d'être acceptée / reprise : bascule sur la cadence rapide,
  /// avec `tripId`, et envoie une position immédiatement.
  Future<void> setActiveTrip(String tripId) async {
    if (_activeTripId == tripId && _isTracking) return;
    _activeTripId = tripId;
    if (!_isTracking) {
      await startLocationTracking();
      return;
    }
    await _configure();
    unawaited(_tick(force: true));
  }

  /// Course terminée / annulée : le chauffeur reste suivi (mode « sans course »),
  /// sinon il ne recevrait plus de nouvelles courses.
  Future<void> clearActiveTrip() async {
    if (_activeTripId == null) return;
    _activeTripId = null;
    if (_isTracking) {
      await _configure();
      unawaited(_tick(force: true));
    }
  }

  /// (Re)construit abonnements et timers selon le mode courant.
  Future<void> _configure() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();

    if (_activeTripId != null) {
      await _locationService.startLocationUpdates();
      _positionSub = _locationService.positionStream?.listen(
        (Position position) {
          final last = _lastSentAt;
          if (last != null && DateTime.now().difference(last) < _activeSendInterval) return;
          unawaited(_send(position));
        },
        onError: (_) {},
      );
      _timer = Timer.periodic(_activeHeartbeat, (_) => unawaited(_tick()));
    } else {
      _timer = Timer.periodic(_idleInterval, (_) => unawaited(_tick()));
    }
  }

  /// Le chauffeur passe « en ligne » : première position sans attendre 45 s.
  void _onOnlineChanged() {
    if (_isTracking && _activeTripId == null && DriverService.isOnline) {
      unawaited(_tick(force: true));
    }
  }

  Future<void> _tick({bool force = false}) async {
    if (!_isTracking || _sending) return;
    // Hors course, on ne suit que les chauffeurs en ligne
    if (_activeTripId == null && !DriverService.isOnline) return;

    final last = _lastSentAt;
    final every = _activeTripId != null ? _activeHeartbeat : _idleInterval;
    if (!force && last != null && DateTime.now().difference(last) < every - const Duration(seconds: 1)) {
      return;
    }
    final position = await _currentFix();
    if (position != null) await _send(position);
  }

  /// Position GPS réelle, ou null. Contrairement à LocationService.getCurrentPosition,
  /// aucune position de repli « Casablanca » n'est jamais inventée : envoyer une
  /// fausse position au backend fausserait le ciblage des courses.
  Future<Position?> _currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: _activeTripId != null ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      return null;
    }
  }

  void stopLocationTracking() {
    if (!_isTracking) return;
    DriverService.isOnlineNotifier.removeListener(_onOnlineChanged);
    _timer?.cancel();
    _timer = null;
    _positionSub?.cancel();
    _positionSub = null;
    _locationService.stopLocationUpdates();
    _isTracking = false;
    _activeTripId = null;
    _lastSentAt = null;
    _blockedUntil = null;
  }

  Future<bool> _send(Position position) async {
    if (_sending) return false;
    final blocked = _blockedUntil;
    if (blocked != null && DateTime.now().isBefore(blocked)) return false;

    // Pas de token → arrêt silencieux, pas de requête
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      stopLocationTracking();
      return false;
    }

    _sending = true;
    final tripId = _activeTripId;
    try {
      final body = <String, dynamic>{
        'latitude': position.latitude,
        'longitude': position.longitude,
        if (position.heading.isFinite && position.heading >= 0) 'heading': position.heading,
        if (position.speed.isFinite && position.speed >= 0) 'speed': position.speed, // m/s
        if (position.accuracy.isFinite && position.accuracy >= 0) 'accuracy': position.accuracy, // m
        'timestamp': position.timestamp.toUtc().millisecondsSinceEpoch, // heure du capteur, ms
      };

      if (tripId != null) {
        await HttpClient.post('/trips/location', body: {...body, 'tripId': tripId});
      } else {
        await HttpClient.patch('/l/trips/location', body: body);
      }
      _lastSentAt = DateTime.now();
      return true;
    } on SessionExpiredException {
      // Seule la fin de session arrête le suivi (la navigation vers /login est gérée ailleurs)
      stopLocationTracking();
      return false;
    } on ApiException catch (e) {
      _handleApiError(e, tripId);
      return false;
    } catch (e) {
      // Réseau coupé, timeout : on garde le suivi actif, le prochain envoi réessaiera
      debugPrint('LocationTrackingService: ${e.runtimeType}');
      return false;
    } finally {
      _sending = false;
    }
  }

  void _handleApiError(ApiException e, String? tripId) {
    final status = e.response?.statusCode;
    final error = _errorInfo(e);

    if (tripId != null && status == 409 &&
        (error.code == 'no_active_trip' || error.code == 'trip_not_active')) {
      // La position a été enregistrée : la course n'est plus active côté serveur.
      _lastSentAt = DateTime.now();
      _activeTripId = null;
      unawaited(_configure());
    } else if (status == 429) {
      _blockedUntil = DateTime.now().add(Duration(seconds: error.retryAfter ?? 5));
    } else if (status == 400 && (error.code == 'gps_spoofing_detected' || error.code == null)) {
      // (400 sans code = ancien backend, où 400 signifiait déjà « anti-spoofing »)
      onGpsSpoofingDetected?.call();
    } else if (tripId != null && status == 404) {
      // Ancien backend : 404 = pas de course active
      _activeTripId = null;
      unawaited(_configure());
    } else {
      debugPrint('LocationTrackingService: HTTP $status ${error.code ?? ''}');
    }
  }

  ({String? code, int? retryAfter}) _errorInfo(ApiException e) {
    try {
      final body = e.response?.body;
      if (body == null || body.isEmpty) return (code: null, retryAfter: null);
      final json = jsonDecode(body);
      if (json is! Map) return (code: null, retryAfter: null);
      final err = json['error'] is Map ? json['error'] as Map : const {};
      final details = err['details'] is Map ? err['details'] as Map : const {};
      final retry = details['retryAfter'];
      return (
        code: (err['code'] ?? json['code'])?.toString(),
        retryAfter: retry is num ? retry.ceil() : null,
      );
    } catch (_) {
      return (code: null, retryAfter: null);
    }
  }

  Future<bool> sendCurrentLocation([String? token]) async {
    final position = await _currentFix();
    if (position == null) return false;
    return _send(position);
  }

  Future<bool> isLocationServiceAvailable() async {
    try {
      final enabled = await _locationService.isLocationServiceEnabled();
      if (!enabled) return false;
      final permission = await _locationService.requestLocationPermission();
      return permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (_) {
      return false;
    }
  }

  void dispose() => stopLocationTracking();
}
