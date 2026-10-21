import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/support_constants.dart';
import '../models/driver_onboarding.dart';
import '../services/auth_service.dart';
import '../services/driver_account_store.dart';
import '../services/driver_onboarding_analytics.dart';
import '../services/driver_onboarding_api.dart';
import '../services/driver_photo_service.dart';
import '../services/support_whatsapp.dart';
import '../widgets/driver_onboarding_ui.dart';

/// « Mon dossier » : statut du compte chauffeur, documents un par un (envoi,
/// renvoi, raison du refus), délai de validation et aide WhatsApp.
///
/// Rechargé à l'ouverture, en tirant vers le bas, et à chaque notification
/// « dossier » (voir DriverAccountStore). Ouvert par-dessus l'app chauffeur
/// (bandeau, blocage « en ligne ») : retour possible. Compte activé : on
/// revient à l'app ; compte suspendu : écran de suspension.
class DriverDossierScreen extends StatefulWidget {
  static const route = '/driver_dossier';

  const DriverDossierScreen({super.key});

  @override
  State<DriverDossierScreen> createState() => _DriverDossierScreenState();
}

class _UploadState {
  double progress = 0;
  String? error;
  bool running = false;

  /// Photo prise, en cours de compression.
  bool preparing = false;

  /// Nouvel essai automatique en cours (`attempt` sur `total`), sinon null.
  int? retryAttempt;
  int retryTotal = 0;

  /// Photo déjà préparée et pas encore reçue : « Réessayer » la renvoie sans
  /// la reprendre. Null après un succès, ou si la photo elle-même est refusée.
  DriverPhoto? photo;

  bool get busy => running || preparing;
}

class _DriverDossierScreenState extends State<DriverDossierScreen> {
  final _store = DriverAccountStore.instance;
  final Map<String, _UploadState> _uploads = {};

  bool _loading = false;
  String? _loadError;
  bool _leaving = false;
  bool _openingWhatsApp = false;

  @override
  void initState() {
    super.initState();
    _store.profile.addListener(_onProfileChanged);
    DriverOnboardingAnalytics.documentScreenViewed();
    _refresh();
  }

  @override
  void dispose() {
    _store.profile.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    final p = _store.profile.value;
    if (!mounted || p == null) return;
    if ((p.isSuspended || p.isActive) && !_leaving) {
      _leaving = true;
      final nav = Navigator.of(context);
      if (p.isActive && nav.canPop()) {
        nav.pop();
      } else {
        nav.pushNamedAndRemoveUntil(DriverAccountStore.routeFor(p), (_) => false);
      }
      return;
    }
    setState(() {});
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      await _store.refresh();
    } on DriverApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'ACCOUNT_SUSPENDED') {
        Navigator.of(context).pushNamedAndRemoveUntil(DriverAccountStore.routeSuspended, (_) => false);
        return;
      }
      setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'driver_v2.errors.generic'.tr());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Envoi d'un document ───────────────────────────────────────────────────

  /// Nouvelle photo (appareil photo ou galerie), préparée puis envoyée.
  Future<void> _upload(DriverDocument doc) async {
    final state = _uploads.putIfAbsent(doc.type, _UploadState.new);
    if (state.busy) return;

    final source = await DriverPhotoService.askSource(context);
    if (source == null || !mounted) return;

    setState(() { state.preparing = true; state.error = null; });
    DriverPhoto? photo;
    try {
      photo = await DriverPhotoService.pick(source);
    } on CameraPermissionDenied {
      if (mounted) setState(() => state.error = 'driver_v2.camera_permission'.tr());
      return;
    } catch (_) {
      if (mounted) setState(() => state.error = 'driver_v2.photo_error'.tr());
      return;
    } finally {
      if (mounted) setState(() => state.preparing = false);
    }
    if (photo == null || !mounted) return;
    state.photo = photo;
    await _send(doc, photo);
  }

  /// Envoi d'une photo préparée (première fois ou « Réessayer »).
  Future<void> _send(DriverDocument doc, DriverPhoto photo) async {
    final state = _uploads.putIfAbsent(doc.type, _UploadState.new);
    if (state.busy) return;
    DriverOnboardingAnalytics.documentUploadStarted(doc.type);

    if (await photo.file.length() > DriverOnboardingApi.maxFileBytes) {
      DriverOnboardingAnalytics.registrationError(step: 'upload', errorCode: 'FILE_TOO_LARGE');
      DriverOnboardingAnalytics.documentUploadFailed(doc.type, reason: 'size');
      if (mounted) {
        setState(() {
          state.photo = null;
          state.error = 'driver_v2.errors.FILE_TOO_LARGE'.tr();
        });
      }
      return;
    }

    final wasComplete = _requiredDocsSent(_store.profile.value);
    setState(() {
      state.running = true;
      state.error = null;
      state.progress = 0;
      state.retryAttempt = null;
    });
    try {
      final profile = await DriverOnboardingApi.uploadDocument(
        doc.type,
        photo.file,
        contentType: photo.contentType,
        onProgress: (p) {
          if (mounted) setState(() => state.progress = p);
        },
        onRetry: (attempt, total) {
          if (!mounted) return;
          setState(() {
            state.retryAttempt = attempt;
            state.retryTotal = total;
            state.progress = 0;
          });
        },
      );
      state.photo = null;
      DriverOnboardingAnalytics.documentUploaded(doc.type);
      if (profile.id.isNotEmpty) {
        await _store.update(profile);
      } else {
        await _store.refresh();
      }
      final updated = _store.profile.value;
      if (!wasComplete && updated != null && _requiredDocsSent(updated)) {
        unawaited(DriverOnboardingAnalytics.documentsCompleted(updated.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('driver_v2.document_sent'.tr(namedArgs: {'document': doc.label})),
          backgroundColor: DriverUi.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on DriverApiException catch (e) {
      final reason = _failureReason(e);
      DriverOnboardingAnalytics.registrationError(step: 'upload', errorCode: e.code);
      DriverOnboardingAnalytics.documentUploadFailed(doc.type,
          reason: reason, httpStatus: e.statusCode);
      if (mounted) {
        setState(() {
          // Photo refusée (taille, format) : il faut en reprendre une.
          if (reason == 'size' || reason == 'format') state.photo = null;
          state.error = switch (reason) {
            'network' => 'driver_v2.upload_network_error'.tr(),
            'server' => 'driver_v2.upload_server_error'.tr(),
            _ => e.message,
          };
        });
      }
    } catch (e) {
      // Fichier illisible sur l'appareil, réponse inattendue… : jamais muet.
      debugPrint('Driver document upload: ${e.runtimeType}');
      DriverOnboardingAnalytics.documentUploadFailed(doc.type, reason: 'unknown');
      if (mounted) {
        setState(() {
          state.photo = null;
          state.error = 'driver_v2.photo_error'.tr();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          state.running = false;
          state.retryAttempt = null;
        });
      }
    }
  }

  /// Tous les documents obligatoires envoyés (ni manquants, ni refusés).
  static bool _requiredDocsSent(DriverProfile? p) {
    final required = p?.documents.where((d) => d.required).toList() ?? const <DriverDocument>[];
    return required.isNotEmpty && required.every((d) => !d.isMissing && !d.isRejected);
  }

  /// Motif d'échec pour Analytics : `size`, `format`, `network`, `server` ou `unknown`.
  static String _failureReason(DriverApiException e) {
    if (e.code == 'FILE_TOO_LARGE' || e.statusCode == 413) return 'size';
    if (e.code == 'FILE_TYPE_NOT_ALLOWED' || e.code == 'FILE_UNREADABLE' || e.statusCode == 415) {
      return 'format';
    }
    if (e.isRetryable) return 'network';
    if ((e.statusCode ?? 0) >= 500 || e.code == 'INTERNAL_ERROR') return 'server';
    return 'unknown';
  }

  Future<void> _openWhatsApp() async {
    if (_openingWhatsApp) return;
    DriverOnboardingAnalytics.documentHelpWhatsAppClicked();
    setState(() => _openingWhatsApp = true);
    try {
      if (!await SupportWhatsApp.open() && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('support_extra.wa_unavailable'.tr(namedArgs: {
            'number': '\u2066${SupportConstants.whatsAppDisplayNumber}\u2069',
          })),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'common.copy'.tr(),
            onPressed: () => Clipboard.setData(
                const ClipboardData(text: '+${SupportConstants.whatsAppNumber}')),
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _openingWhatsApp = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    // Chauffeur : connexion par téléphone (pas le formulaire e-mail + mot de passe).
    Navigator.of(context).pushNamedAndRemoveUntil('/driver_login', (_) => false);
  }

  // ── Interface ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = _store.profile.value;
    // Ouvert depuis l'app chauffeur : retour possible. Écran racine : pas de
    // retour vers l'inscription ou la connexion.
    final canGoBack = Navigator.of(context).canPop();
    return PopScope(
      canPop: canGoBack,
      child: DriverOnboardingScaffold(
        title: 'driver_v2.dossier_title'.tr(),
        subtitle: profile == null
            ? null
            : 'driver_v2.dossier_hello'.tr(namedArgs: {'name': profile.firstName}),
        showBack: canGoBack,
        onRefresh: _refresh,
        trailing: IconButton(
          tooltip: 'driver_v2.logout'.tr(),
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
        ),
        child: profile == null
            ? _buildEmpty()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loadError != null) ...[
                    DriverMessageBanner(
                        message: _loadError!,
                        actionLabel: 'common.retry'.tr(),
                        onAction: _refresh),
                    const SizedBox(height: 14),
                  ],
                  _statusCard(profile),
                  const SizedBox(height: 22),
                  Text('driver_v2.documents_title'.tr(),
                      style: DriverUi.text(16, weight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  for (final doc in profile.documents) ...[
                    // Dossier refusé : lecture seule, la suite passe par le support.
                    _documentCard(doc,
                        canSend: !doc.isApproved &&
                            profile.accountStatus != DriverAccountStatus.rejected),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  _helpButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: DriverUi.orange)),
      );
    }
    return Column(
      children: [
        DriverMessageBanner(
          message: _loadError ?? 'driver_v2.errors.generic'.tr(),
          actionLabel: 'common.retry'.tr(),
          onAction: _refresh,
        ),
        const SizedBox(height: 20),
        _helpButton(),
      ],
    );
  }

  Widget _statusCard(DriverProfile p) {
    final requiredDocs = p.documents.where((d) => d.required).toList();
    final sent = requiredDocs.where((d) => !d.isMissing && !d.isRejected).length;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String body;
    switch (p.accountStatus == DriverAccountStatus.rejected
        ? DriverNextAction.contactSupport
        : p.nextAction) {
      case DriverNextAction.waitForReview:
        color = DriverUi.blue;
        icon = Icons.hourglass_top_rounded;
        title = 'driver_v2.status_review_title'.tr();
        body = 'driver_v2.status_review_body'.tr(namedArgs: {'hours': '${p.reviewSlaHours}'});
        break;
      case DriverNextAction.replaceRejectedDocuments:
        color = DriverUi.red;
        icon = Icons.report_gmailerrorred_rounded;
        title = 'driver_v2.status_replace_title'.tr();
        body = 'driver_v2.status_replace_body'.tr();
        break;
      case DriverNextAction.contactSupport:
        color = DriverUi.red;
        icon = Icons.block_rounded;
        title = 'driver_v2.status_rejected_title'.tr();
        body = p.rejectionReason ?? 'driver_v2.status_rejected_body'.tr();
        break;
      default:
        color = DriverUi.orange;
        icon = Icons.upload_file_rounded;
        title = 'driver_v2.status_upload_title'.tr();
        body = 'driver_v2.status_upload_body'.tr(namedArgs: {'hours': '${p.reviewSlaHours}'});
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: DriverUi.text(15, weight: FontWeight.w800, color: color))),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: DriverUi.text(13, color: DriverUi.textPrimary, height: 1.5)),
          if (requiredDocs.isNotEmpty && p.nextAction != DriverNextAction.waitForReview) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: sent / requiredDocs.length,
                minHeight: 7,
                color: color,
                backgroundColor: color.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'driver_v2.required_progress'.tr(namedArgs: {
                'sent': '$sent',
                'total': '${requiredDocs.length}',
              }),
              style: DriverUi.text(12, color: DriverUi.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _documentCard(DriverDocument doc, {required bool canSend}) {
    final upload = _uploads[doc.type];
    final running = upload?.running == true;
    final busy = upload?.busy == true;

    final (Color color, String statusLabel) = switch (doc.status) {
      DriverDocumentStatus.approved => (DriverUi.green, 'driver_v2.doc_approved'.tr()),
      DriverDocumentStatus.uploaded => (DriverUi.blue, 'driver_v2.doc_uploaded'.tr()),
      DriverDocumentStatus.rejected => (DriverUi.red, 'driver_v2.doc_rejected'.tr()),
      _ => (DriverUi.textSecondary, 'driver_v2.doc_missing'.tr()),
    };

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: doc.isRejected ? DriverUi.red.withOpacity(0.4) : DriverUi.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_docIcon(doc.type), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.label, style: DriverUi.text(13.5, weight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(statusLabel, color),
                        _chip(doc.required ? 'driver_v2.required'.tr() : 'driver_v2.optional'.tr(),
                            DriverUi.textSecondary),
                      ],
                    ),
                  ],
                ),
              ),
              if (canSend && !busy)
                TextButton(
                  onPressed: () => _upload(doc),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: DriverUi.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    doc.isMissing ? 'driver_v2.send'.tr() : 'driver_v2.resend_doc'.tr(),
                    style: DriverUi.text(12.5, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
            ],
          ),
          if (doc.isRejected && doc.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DriverUi.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'driver_v2.rejection_reason'.tr(namedArgs: {'reason': doc.rejectionReason!}),
                style: DriverUi.text(12.5, color: DriverUi.red, height: 1.45),
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: running && upload!.progress > 0 ? upload.progress : null,
                minHeight: 6,
                color: DriverUi.orange,
                backgroundColor: DriverUi.orange.withOpacity(0.15),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              !running
                  ? 'driver_v2.preparing_photo'.tr()
                  : upload!.retryAttempt != null
                      ? 'driver_v2.upload_retrying'.tr(namedArgs: {
                          'attempt': '${upload.retryAttempt}',
                          'total': '${upload.retryTotal}',
                        })
                      : 'driver_v2.uploading'.tr(
                          namedArgs: {'percent': '${(upload.progress * 100).round()}'}),
              style: DriverUi.text(11.5, color: DriverUi.textSecondary),
            ),
          ],
          if (upload?.error != null && !busy) ...[
            const SizedBox(height: 10),
            // Photo gardée : « Réessayer » la renvoie ; sinon, nouvelle photo.
            DriverMessageBanner(
              message: upload!.error!,
              actionLabel: upload.photo != null
                  ? 'common.retry'.tr()
                  : 'driver_v2.retake_photo'.tr(),
              onAction: () {
                final photo = upload.photo;
                photo != null ? _send(doc, photo) : _upload(doc);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: DriverUi.text(11, weight: FontWeight.w600, color: color)),
      );

  static IconData _docIcon(String type) {
    if (type == 'selfie') return Icons.face_rounded;
    if (type.startsWith('vehicle_photo')) return Icons.directions_car_rounded;
    if (type == 'driving_license') return Icons.badge_rounded;
    if (type == 'vehicle_registration') return Icons.description_rounded;
    return Icons.credit_card_rounded;
  }

  Widget _helpButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _openingWhatsApp ? null : _openWhatsApp,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF128C7E),
          side: const BorderSide(color: Color(0xFF25D366)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _openingWhatsApp
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)))
            : const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
        label: Text('driver_v2.help_whatsapp'.tr(),
            style: DriverUi.text(14, weight: FontWeight.w700, color: const Color(0xFF128C7E))),
      ),
    );
  }
}
