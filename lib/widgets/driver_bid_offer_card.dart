import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/trip_models.dart';

/// Carte d'une offre de chauffeur, côté client : même structure que la carte
/// de course côté chauffeur (voir `widgets/ride_offers_panel.dart`) — en-tête,
/// prix bien visible, puis une rangée de grands boutons — dans les couleurs de
/// l'écran de réservation client.
///
/// Les actions sont fournies par l'écran ; la carte se contente de bloquer
/// ses boutons et d'afficher un indicateur pendant l'action en cours.
class DriverBidOfferCard extends StatefulWidget {
  final BidOffer offer;
  final String currency;
  final Future<void> Function() onReject;
  final VoidCallback onCounter;
  final Future<void> Function() onAccept;

  const DriverBidOfferCard({
    super.key,
    required this.offer,
    required this.currency,
    required this.onReject,
    required this.onCounter,
    required this.onAccept,
  });

  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFFF1EB);
  static const _dark = Color(0xFF0F172A);
  static const _gray200 = Color(0xFFE2E6EF);
  static const _gray300 = Color(0xFFCDD3E0);
  static const _gray600 = Color(0xFF5C6475);

  @override
  State<DriverBidOfferCard> createState() => _DriverBidOfferCardState();
}

enum _Action { reject, accept }

class _DriverBidOfferCardState extends State<DriverBidOfferCard> {
  _Action? _busy;

  Future<void> _run(_Action action, Future<void> Function() fn) async {
    if (_busy != null) return;
    setState(() => _busy = action);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    const orange = DriverBidOfferCard._orange;
    final busy = _busy != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DriverBidOfferCard._orangeLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(photoUrl: offer.driverPhoto, name: offer.driverName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: DriverBidOfferCard._dark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          offer.driverRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: DriverBidOfferCard._gray600,
                          ),
                        ),
                        if (offer.driverVehicle.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.directions_car_rounded, size: 13, color: DriverBidOfferCard._gray600),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              offer.driverVehicle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: DriverBidOfferCard._gray600),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: DriverBidOfferCard._orangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${offer.proposedFare.toStringAsFixed(2)} ${widget.currency}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _button(
                  label: 'common.reject'.tr(),
                  onPressed: busy ? null : () => _run(_Action.reject, widget.onReject),
                  loading: _busy == _Action.reject,
                  foreground: DriverBidOfferCard._gray600,
                  border: DriverBidOfferCard._gray300,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _button(
                  label: 'rdv.counter_offer'.tr(),
                  onPressed: busy ? null : widget.onCounter,
                  foreground: orange,
                  border: orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _button(
                  label: 'common.accept'.tr(),
                  onPressed: busy ? null : () => _run(_Action.accept, widget.onAccept),
                  loading: _busy == _Action.accept,
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    bool filled = false,
    Color foreground = Colors.white,
    Color border = DriverBidOfferCard._gray200,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: filled ? Colors.white : foreground,
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          );
    return SizedBox(
      height: 42,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverBidOfferCard._orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: DriverBidOfferCard._orange.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: shape,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: foreground,
                side: BorderSide(color: onPressed == null ? border.withValues(alpha: 0.5) : border, width: 1.3),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: shape,
              ),
              child: child,
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _Avatar({required this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: DriverBidOfferCard._orange,
        ),
      ),
    );
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: DriverBidOfferCard._orangeLight,
      ),
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: 46,
                height: 46,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : fallback,
    );
  }
}
