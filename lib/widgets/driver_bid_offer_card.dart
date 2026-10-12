import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/trip_models.dart';
import 'offer_card.dart';

/// Offre d'un chauffeur, côté client, dans le même style que les cartes de
/// course côté chauffeur (coque, prix et boutons partagés : `offer_card.dart`).
///
/// N'affiche que les données réellement reçues : la note et le véhicule
/// viennent de [BidOffer.reportedRating] / [BidOffer.reportedVehicle], jamais
/// des valeurs par défaut du modèle. Les actions restent celles de l'écran ;
/// la carte bloque seulement ses boutons pendant l'action en cours.
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
    final busy = _busy != null;
    final rating = offer.reportedRating;
    final vehicle = offer.reportedVehicle;

    return OfferCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(photoUrl: offer.driverPhoto, name: offer.driverName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: OfferCardStyle.dark),
                    ),
                    if (rating != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OfferFareText('${offer.proposedFare.toStringAsFixed(2)} ${widget.currency}'),
            ],
          ),
          if (vehicle != null) ...[
            const SizedBox(height: 10),
            OfferInfoChip(vehicle, icon: Icons.directions_car_rounded),
          ],
          const SizedBox(height: 12),
          OfferCardActions(
            onReject: busy ? null : () => _run(_Action.reject, widget.onReject),
            onAccept: busy ? null : () => _run(_Action.accept, widget.onAccept),
            rejectLoading: _busy == _Action.reject,
            acceptLoading: _busy == _Action.accept,
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: busy ? null : widget.onCounter,
              style: TextButton.styleFrom(
                foregroundColor: OfferCardStyle.orange,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(
                'rdv.counter_offer'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;

  const _Avatar({required this.photoUrl, required this.name});

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: OfferCardStyle.orange),
      ),
    );
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: OfferCardStyle.border),
      ),
      child: (photoUrl != null && photoUrl!.isNotEmpty)
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                width: _size,
                height: _size,
                errorBuilder: (_, __, ___) => fallback,
              ),
            )
          : fallback,
    );
  }
}
