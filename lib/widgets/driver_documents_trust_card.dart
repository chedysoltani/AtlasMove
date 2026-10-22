import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/remote_config_service.dart';
import 'driver_onboarding_ui.dart';

/// « Vos documents sont protégés », en haut de « Mon dossier » : pourquoi on
/// demande les documents, trois garanties, preuve sociale et politique de
/// confidentialité. Dépliée tant qu'aucun document n'est envoyé, puis repliée
/// sur son titre (un appui la rouvre).
///
/// Le nombre de chauffeurs et l'URL viennent de Remote Config ; un nombre à 0
/// masque la phrase de preuve sociale.
class DriverDocumentsTrustCard extends StatefulWidget {
  /// Pays du chauffeur (`DZ`, `MA`…) : choisit la phrase de preuve sociale.
  final String? country;
  final bool initiallyExpanded;

  const DriverDocumentsTrustCard({
    super.key,
    required this.country,
    required this.initiallyExpanded,
  });

  @override
  State<DriverDocumentsTrustCard> createState() => _DriverDocumentsTrustCardState();
}

class _DriverDocumentsTrustCardState extends State<DriverDocumentsTrustCard> {
  late bool _expanded = widget.initiallyExpanded;

  static const _socialProofCountries = {'DZ', 'MA'};

  Future<void> _openPrivacy() async {
    try {
      await launchUrl(Uri.parse(RemoteConfigService.instance.privacyUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final count = RemoteConfigService.instance.socialProofCount;
    final socialProofKey = _socialProofCountries.contains(widget.country?.toUpperCase())
        ? 'driver_v2.trust_social_proof_dzma'
        : 'driver_v2.trust_social_proof';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DriverUi.green.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: DriverUi.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, color: DriverUi.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('driver_v2.trust_title'.tr(),
                        style: DriverUi.text(15, weight: FontWeight.w800)),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: DriverUi.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('driver_v2.trust_why'.tr(),
                      style: DriverUi.text(13, color: DriverUi.textPrimary, height: 1.5)),
                  const SizedBox(height: 10),
                  _guarantee(Icons.visibility_rounded, 'driver_v2.trust_team'.tr()),
                  _guarantee(Icons.do_not_disturb_on_outlined,
                      'driver_v2.trust_never_shared'.tr()),
                  _guarantee(Icons.verified_user_rounded, 'driver_v2.trust_secure'.tr()),
                  if (count > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: DriverUi.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.groups_rounded, color: DriverUi.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              socialProofKey.tr(namedArgs: {'count': '$count'}),
                              style: DriverUi.text(12.5, weight: FontWeight.w700,
                                  color: DriverUi.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _openPrivacy,
                      style: TextButton.styleFrom(
                        foregroundColor: DriverUi.blue,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.privacy_tip_outlined, size: 16),
                      label: Text('driver_v2.trust_privacy'.tr(),
                          style: DriverUi.text(12.5, weight: FontWeight.w600, color: DriverUi.blue)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Une garantie : icône verte + texte.
  Widget _guarantee(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: DriverUi.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: DriverUi.text(13, color: DriverUi.textPrimary, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
