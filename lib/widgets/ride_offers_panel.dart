import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../core/network/http_client.dart';
import '../main.dart' show navigatorKey;
import '../models/new_ride_offer.dart';
import '../screens/driver_active_ride.dart';
import '../services/ride_offer_queue.dart';
import '../services/trip_service.dart';

const _orange = Color(0xFFFF6600);

/// Panneau flottant listant toutes les offres de course en attente, une carte
/// par course — visible par-dessus n'importe quel écran chauffeur (inséré une
/// fois via `MaterialApp.builder`, voir main.dart). Se rétracte tout seul
/// quand la liste est vide.
class RideOffersPanel extends StatelessWidget {
  const RideOffersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NewRideOffer>>(
      valueListenable: RideOfferQueue.instance.offers,
      builder: (context, offers, _) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(animation),
              child: child,
            ),
            child: offers.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : _Panel(key: const ValueKey('panel'), offers: offers),
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  final List<NewRideOffer> offers;
  const _Panel({super.key, required this.offers});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.60;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: _orange.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.local_taxi_rounded, color: _orange, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      offers.length > 1
                          ? 'ride_offer.new_count'.tr(namedArgs: {'count': '${offers.length}'})
                          : 'ride_offer.new_one'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _OfferCard(key: ValueKey(offers[i].tripId), offer: offers[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  final NewRideOffer offer;
  const _OfferCard({super.key, required this.offer});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await RideOfferQueue.instance.accept(widget.offer.tripId);
      final trip = await TripService.getActiveTrip();
      final nav = navigatorKey.currentState;
      if (trip != null && nav != null) {
        nav.push(MaterialPageRoute(builder: (_) => DriverActiveRideScreen(trip: trip)));
      }
    } on ApiException catch (e) {
      _showError(e.response?.statusCode == 409
          ? 'ride_offer.already_taken'.tr()
          : 'ride_offer.accept_error'.tr());
    } catch (_) {
      _showError('ride_offer.network_error'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _refuse() {
    if (_busy) return;
    RideOfferQueue.instance.refuse(widget.offer.tripId);
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final remaining = offer.remaining;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0BD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _addressRow(Icons.trip_origin_rounded, const Color(0xFF22C55E), offer.pickupAddress, bold: true),
                    if (offer.destinationAddress != null) ...[
                      const SizedBox(height: 5),
                      _addressRow(Icons.flag_rounded, const Color(0xFFEF4444), offer.destinationAddress!),
                    ],
                  ],
                ),
              ),
              if (remaining != null) ...[
                const SizedBox(width: 8),
                _CountdownBadge(remaining: remaining),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (offer.offeredFare != null)
                Text(
                  '${offer.offeredFare!.toStringAsFixed(2)} ${offer.currency}',
                  style: const TextStyle(color: Color(0xFF16803C), fontWeight: FontWeight.w800, fontSize: 17),
                ),
              if (offer.distanceKm != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Text('${offer.distanceKm!.toStringAsFixed(1)} km',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                ),
              ],
              const Spacer(),
              if (offer.serviceName != null)
                Text(offer.serviceName!,
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _refuse,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('common.reject'.tr(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : Text('common.accept'.tr(), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addressRow(IconData icon, Color color, String text, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              fontSize: bold ? 13.5 : 12.5,
              color: bold ? const Color(0xFF0F172A) : Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final Duration remaining;
  const _CountdownBadge({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final s = remaining.inSeconds.clamp(0, 999);
    final urgent = s <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: urgent ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDDD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${s}s',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: urgent ? const Color(0xFFDC2626) : _orange,
        ),
      ),
    );
  }
}
