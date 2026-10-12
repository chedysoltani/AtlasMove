import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Éléments visuels communs aux cartes d'offre : cartes de course côté
/// chauffeur (`ride_offers_panel.dart`) et cartes d'offre de chauffeur côté
/// client (`driver_bid_offer_card.dart`). Les valeurs reprennent exactement
/// celles de la carte chauffeur d'origine.
class OfferCardStyle {
  OfferCardStyle._();

  static const orange = Color(0xFFFF6600);
  static const dark = Color(0xFF0F172A);
  static const background = Color(0xFFFFF8F2);
  static const border = Color(0xFFFFE0BD);
  static const fare = Color(0xFF16803C);
  static const radius = 18.0;
  static const padding = 14.0;
  static const buttonHeight = 42.0;
  static const buttonRadius = 12.0;
}

/// Coque d'une carte d'offre : fond crème, bordure orange pâle, rayon 18.
class OfferCardShell extends StatelessWidget {
  final Widget child;
  const OfferCardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OfferCardStyle.padding),
      decoration: BoxDecoration(
        color: OfferCardStyle.background,
        borderRadius: BorderRadius.circular(OfferCardStyle.radius),
        border: Border.all(color: OfferCardStyle.border),
      ),
      child: child,
    );
  }
}

/// Prix d'une offre, mis en avant (vert, gras).
class OfferFareText extends StatelessWidget {
  final String text;
  const OfferFareText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: OfferCardStyle.fare, fontWeight: FontWeight.w800, fontSize: 17),
    );
  }
}

/// Petite pastille blanche d'information (distance, véhicule…).
class OfferInfoChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  const OfferInfoChip(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey.shade700);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: icon == null
          ? Text(text, style: style)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Flexible(child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }
}

/// Rangée « Refuser » / « Accepter » des cartes d'offre. Un bouton à `null`
/// est désactivé ; `rejectLoading` / `acceptLoading` remplacent son libellé
/// par un indicateur de chargement.
class OfferCardActions extends StatelessWidget {
  final VoidCallback? onReject;
  final VoidCallback? onAccept;
  final bool rejectLoading;
  final bool acceptLoading;

  const OfferCardActions({
    super.key,
    required this.onReject,
    required this.onAccept,
    this.rejectLoading = false,
    this.acceptLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(OfferCardStyle.buttonRadius));
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: OfferCardStyle.buttonHeight,
            child: OutlinedButton(
              onPressed: onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              child: rejectLoading
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.grey.shade700))
                  : Text('common.reject'.tr(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: OfferCardStyle.buttonHeight,
            child: ElevatedButton(
              onPressed: onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: OfferCardStyle.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: shape,
              ),
              child: acceptLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Text('common.accept'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ),
        ),
      ],
    );
  }
}
