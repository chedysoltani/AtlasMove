import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../core/network/http_client.dart';
import '../models/driver_onboarding.dart';
import '../services/driver_account_store.dart';
import 'driver_onboarding_ui.dart';

/// Accès au travail d'un chauffeur selon son dossier (`account_status`).
///
/// Un chauffeur inscrit peut se connecter et parcourir l'app, mais ne peut ni
/// se mettre en ligne, ni accepter une course ou un rendez-vous tant que son
/// compte n'est pas `active` (documents envoyés puis validés). Le backend
/// applique la même règle (403 `DOCUMENTS_REQUIRED`) : ce garde-fou ne sert
/// qu'à expliquer le blocage et à envoyer le chauffeur vers « Mon dossier ».
class DriverDossierGate {
  DriverDossierGate._();

  static DriverAccountStore get _store => DriverAccountStore.instance;

  /// Dernier profil connu. Inconnu (hors-ligne, ancien compte) : on laisse le
  /// backend décider plutôt que de bloquer à tort.
  static bool get canWorkCached {
    final p = _store.profile.value;
    return p == null || p.isActive;
  }

  /// Avant de se mettre en ligne / d'accepter : statut rechargé (un dossier
  /// validé il y a une minute débloque tout de suite), sinon fenêtre explicative.
  static Future<bool> ensureCanWork(BuildContext context) async {
    DriverProfile? p;
    try {
      p = await _store.refresh().timeout(const Duration(seconds: 8));
    } catch (_) {
      p = _store.profile.value;
    }
    if (p == null || p.isActive) return true;
    if (context.mounted) await showBlockedSheet(context, p);
    return false;
  }

  /// Refus du backend parce que le dossier n'est pas validé.
  static bool isDocumentsRequired(Object error) {
    if (error is! ApiException) return false;
    try {
      final json = error.response?.json;
      if (json == null) return false;
      final nested = json['error'];
      final code = json['code'] ??
          json['error_code'] ??
          (nested is Map ? nested['code'] : null);
      return code?.toString() == 'DOCUMENTS_REQUIRED';
    } catch (_) {
      return false;
    }
  }

  /// Après un refus `DOCUMENTS_REQUIRED` : profil rechargé puis explication.
  static Future<void> handleDocumentsRequired(BuildContext context) async {
    DriverProfile? p;
    try {
      p = await _store.refresh().timeout(const Duration(seconds: 8));
    } catch (_) {
      p = _store.profile.value;
    }
    if (context.mounted) await showBlockedSheet(context, p);
  }

  static Future<void> openDossier(BuildContext context) =>
      Navigator.of(context).pushNamed(DriverAccountStore.routeDossier);

  static Future<void> showBlockedSheet(BuildContext context, DriverProfile? p) {
    final status = _DossierStatus.of(p);
    final pending = p?.documents
            .where((d) => d.required && (d.isMissing || d.isRejected))
            .toList() ??
        const <DriverDocument>[];

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(status.icon, color: status.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(status.title,
                        style: DriverUi.text(16, weight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(status.body,
                  style: DriverUi.text(13, color: DriverUi.textSecondary)),
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('driver_gate.missing_docs'.tr(),
                    style: DriverUi.text(13, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final d in pending)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          d.isRejected ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: d.isRejected ? DriverUi.red : DriverUi.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.isRejected && d.rejectionReason != null
                                ? '${d.label} — ${d.rejectionReason}'
                                : d.label,
                            style: DriverUi.text(13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    openDossier(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DriverUi.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('driver_gate.open_dossier'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texte, couleur et icône de l'état du dossier — mêmes messages que « Mon dossier ».
class _DossierStatus {
  final String title;
  final String body;
  final Color color;
  final IconData icon;

  const _DossierStatus(this.title, this.body, this.color, this.icon);

  factory _DossierStatus.of(DriverProfile? p) {
    final hours = {'hours': '${p?.reviewSlaHours ?? 24}'};
    final step = p == null
        ? DriverNextAction.uploadDocuments
        : p.accountStatus == DriverAccountStatus.rejected
            ? DriverNextAction.contactSupport
            : p.nextAction;
    switch (step) {
      case DriverNextAction.waitForReview:
        return _DossierStatus('driver_v2.status_review_title'.tr(),
            'driver_v2.status_review_body'.tr(namedArgs: hours),
            DriverUi.blue, Icons.hourglass_top_rounded);
      case DriverNextAction.replaceRejectedDocuments:
        return _DossierStatus('driver_v2.status_replace_title'.tr(),
            'driver_v2.status_replace_body'.tr(),
            DriverUi.red, Icons.report_gmailerrorred_rounded);
      case DriverNextAction.contactSupport:
        return _DossierStatus('driver_v2.status_rejected_title'.tr(),
            p?.rejectionReason ?? 'driver_v2.status_rejected_body'.tr(),
            DriverUi.red, Icons.block_rounded);
      default:
        return _DossierStatus('driver_v2.status_upload_title'.tr(),
            'driver_v2.status_upload_body'.tr(namedArgs: hours),
            DriverUi.orange, Icons.upload_file_rounded);
    }
  }
}

/// Bandeau en haut du tableau de bord tant que le dossier n'est pas validé.
class DriverDossierBanner extends StatelessWidget {
  const DriverDossierBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverProfile?>(
      valueListenable: DriverAccountStore.instance.profile,
      builder: (context, p, _) {
        if (p == null || p.isActive) return const SizedBox.shrink();
        final status = _DossierStatus.of(p);
        return GestureDetector(
          onTap: () => DriverDossierGate.openDossier(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: status.color.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(status.icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('driver_gate.banner_tap'.tr(),
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// À la place des listes de courses / rendez-vous : un chauffeur non validé ne
/// voit ni les adresses ni les noms des clients.
class DriverDossierLockedView extends StatelessWidget {
  const DriverDossierLockedView({super.key});

  @override
  Widget build(BuildContext context) {
    final status = _DossierStatus.of(DriverAccountStore.instance.profile.value);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_clock_rounded, color: status.color, size: 40),
            ),
            const SizedBox(height: 18),
            Text('driver_gate.locked_title'.tr(),
                textAlign: TextAlign.center,
                style: DriverUi.text(17, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('driver_gate.locked_body'.tr(),
                textAlign: TextAlign.center,
                style: DriverUi.text(13, color: DriverUi.textSecondary)),
            const SizedBox(height: 6),
            Text(status.title,
                textAlign: TextAlign.center,
                style: DriverUi.text(13, weight: FontWeight.w700, color: status.color)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => DriverDossierGate.openDossier(context),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text('driver_gate.open_dossier'.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: DriverUi.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
