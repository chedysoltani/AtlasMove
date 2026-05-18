import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trip_models.dart';
import '../services/trip_service.dart';
import '../utils/app_theme.dart';

// ── Local color palette (mirrors create_ride_screen.dart) ──────────────────
class _C {
  static const primary    = Color(0xFFFF6600);
  static const green      = Color(0xFF22C55E);
  static const red        = Color(0xFFEF4444);
  static const gray900    = Color(0xFF0F172A);
  static const gray800    = Color(0xFF1E293B);
  static const gray600    = Color(0xFF475569);
  static const gray400    = Color(0xFF94A3B8);
  static const gray100    = Color(0xFFF1F5F9);
  static const white      = Colors.white;
  static const accentLight = Color(0xFFFFF7ED);
}

class ClientActiveRideScreen extends StatefulWidget {
  final String tripId;
  final double lockedFare;
  final String currency;
  final String driverName;
  final String? driverPhoto;
  final double driverRating;
  final String driverVehicle;
  final String destination;

  const ClientActiveRideScreen({
    super.key,
    required this.tripId,
    required this.lockedFare,
    required this.currency,
    required this.driverName,
    this.driverPhoto,
    required this.driverRating,
    required this.driverVehicle,
    required this.destination,
  });

  @override
  State<ClientActiveRideScreen> createState() => _ClientActiveRideScreenState();
}

class _ClientActiveRideScreenState extends State<ClientActiveRideScreen>
    with SingleTickerProviderStateMixin {
  String _status = 'accepted';
  Timer? _pollTimer;
  bool _isCancelling = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final history = await TripService.getClientTripHistory(page: 1, limit: 5);
        for (final t in history.trips) {
          if (t.id == widget.tripId) {
            if (mounted && t.status != _status) {
              setState(() => _status = t.status);
              if (t.status == 'completed' || t.status == 'cancelled') {
                _pollTimer?.cancel();
              }
            }
            break;
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Annuler la course ?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'Êtes-vous sûr de vouloir annuler cette course ? Des frais peuvent s\'appliquer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await TripService.cancelClientTrip(widget.tripId, 'Annulé par le client');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/client_trip_history');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _C.red,
          ),
        );
        setState(() => _isCancelling = false);
      }
    }
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color get _statusColor {
    switch (_status.toLowerCase()) {
      case 'accepted':  return _C.primary;
      case 'arriving':  return Colors.orange;
      case 'in_progress': return _C.green;
      case 'completed': return _C.green;
      case 'cancelled': return _C.red;
      default:          return _C.gray400;
    }
  }

  String get _statusLabel {
    switch (_status.toLowerCase()) {
      case 'accepted':    return 'Course confirmée';
      case 'arriving':    return 'Livreur en route vers vous';
      case 'in_progress': return 'Course en cours';
      case 'completed':   return 'Course terminée';
      case 'cancelled':   return 'Course annulée';
      default:            return 'En attente';
    }
  }

  IconData get _statusIcon {
    switch (_status.toLowerCase()) {
      case 'accepted':    return Icons.check_circle_rounded;
      case 'arriving':    return Icons.directions_bike_rounded;
      case 'in_progress': return Icons.navigation_rounded;
      case 'completed':   return Icons.flag_rounded;
      case 'cancelled':   return Icons.cancel_rounded;
      default:            return Icons.hourglass_top_rounded;
    }
  }

  bool get _isCancelable =>
      _status == 'accepted' || _status == 'arriving';

  bool get _isFinished =>
      _status == 'completed' || _status == 'cancelled';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.gray100,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildFareCard(),
                    const SizedBox(height: 16),
                    _buildDriverCard(),
                    const SizedBox(height: 16),
                    _buildTripInfoCard(),
                    const SizedBox(height: 24),
                    if (_isFinished)
                      _buildFinishedActions()
                    else if (_isCancelable)
                      _buildCancelButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.gray900, _C.gray800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _C.primary.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: _C.primary, width: 1.5),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: _C.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                Text('Suivi en temps réel',
                    style: TextStyle(color: _C.primary, fontSize: 12)),
              ],
            ),
          ),
          // Live indicator dot
          _buildLiveDot(),
        ],
      ),
    );
  }

  Widget _buildLiveDot() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _C.green.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.green.withAlpha(100)),
          ),
          child: Row(
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: _C.green, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('LIVE',
                  style: TextStyle(
                      color: _C.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusColor.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _statusColor.withAlpha(60)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: _statusColor, width: 2),
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_statusLabel,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _statusColor)),
                const SizedBox(height: 4),
                Text(widget.destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: _C.gray600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tarif négocié et verrouillé 🔒',
                  style: TextStyle(
                      fontSize: 12,
                      color: _C.gray600,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.lockedFare.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: _C.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.currency,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _C.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.handshake_rounded,
                color: _C.primary, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Votre livreur',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.gray400,
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_C.primary, Color(0xFFFF8C00)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: _C.primary.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: widget.driverPhoto != null
                    ? ClipOval(
                        child: Image.network(
                          widget.driverPhoto!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildAvatarInitials(),
                        ),
                      )
                    : _buildAvatarInitials(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.driverName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _C.gray900)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 3),
                        Text(widget.driverRating.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _C.gray600)),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: _C.gray400, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(widget.driverVehicle,
                            style: const TextStyle(
                                fontSize: 12, color: _C.gray400)),
                      ],
                    ),
                  ],
                ),
              ),
              // Call button placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _C.green.withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.green.withAlpha(80)),
                ),
                child: const Icon(Icons.phone_rounded,
                    color: _C.green, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarInitials() {
    final initials = widget.driverName.isNotEmpty
        ? widget.driverName[0].toUpperCase()
        : 'L';
    return Center(
      child: Text(initials,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildTripInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Détails du trajet',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.gray400,
                  letterSpacing: 0.8)),
          const SizedBox(height: 14),
          // Status stepper
          _buildStatusStepper(),
        ],
      ),
    );
  }

  Widget _buildStatusStepper() {
    final steps = [
      ('Course confirmée', 'accepted'),
      ('Livreur en route', 'arriving'),
      ('Course en cours', 'in_progress'),
      ('Course terminée', 'completed'),
    ];

    final currentIdx = steps.indexWhere((s) => s.$2 == _status);

    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = i < currentIdx;
        final isCurrent = i == currentIdx;
        final label = steps[i].$1;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // Step indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? _C.green
                      : isCurrent
                          ? _statusColor.withAlpha(20)
                          : _C.gray100,
                  border: Border.all(
                    color: isDone
                        ? _C.green
                        : isCurrent
                            ? _statusColor
                            : _C.gray400,
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.circle,
                  size: isDone ? 16 : (isCurrent ? 10 : 8),
                  color: isDone
                      ? Colors.white
                      : isCurrent
                          ? _statusColor
                          : _C.gray400,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? _statusColor
                      : isDone
                          ? _C.gray600
                          : _C.gray400,
                ),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _statusColor,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : _cancelRide,
        icon: _isCancelling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _C.red))
            : const Icon(Icons.close_rounded, size: 18),
        label: Text(_isCancelling ? 'Annulation...' : 'Annuler la course'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.red,
          side: const BorderSide(color: _C.red, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFinishedActions() {
    final isCompleted = _status == 'completed';
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:
                isCompleted ? _C.green.withAlpha(15) : _C.red.withAlpha(15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isCompleted
                    ? _C.green.withAlpha(60)
                    : _C.red.withAlpha(60)),
          ),
          child: Column(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: isCompleted ? _C.green : _C.red,
                size: 48,
              ),
              const SizedBox(height: 10),
              Text(
                isCompleted ? 'Course terminée ! 🎉' : 'Course annulée',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? _C.green : _C.red),
              ),
              if (isCompleted) ...[
                const SizedBox(height: 6),
                Text(
                  'Montant payé : ${widget.lockedFare.toStringAsFixed(2)} ${widget.currency}',
                  style: const TextStyle(
                      fontSize: 14, color: _C.gray600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/client_trip_history'),
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('Voir l\'historique'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
