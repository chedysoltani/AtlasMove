import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/notification_service.dart';
import '../services/call_service.dart';
import '../core/network/http_client.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _red = Color(0xFFEF4444);
  static const _bg = Color(0xFFF8F9FB);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF6B7280);
  static const _border = Color(0xFFE8ECF0);

  int _step = 0; // 0 = warning, 1 = password
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_pwCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ProfileService.deleteAccount(_pwCtrl.text.trim());
      NotificationService().disconnect();
      CallService().disconnect();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre compte a été supprimé.'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } on UnauthorizedException {
      setState(() => _error = 'Mot de passe incorrect. Veuillez réessayer.');
    } on NotFoundException {
      // Compte déjà supprimé — nettoyer la session
      await ProfileService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    } on NetworkException {
      setState(() => _error = 'Impossible de contacter le serveur. Vérifiez votre connexion.');
    } catch (_) {
      setState(() => _error = 'Une erreur est survenue. Veuillez réessayer.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          'Supprimer le compte',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: _step == 0 ? _buildWarning() : _buildPasswordStep(),
    );
  }

  // ── Step 0 : Avertissement ────────────────────────────────────────────────

  Widget _buildWarning() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_forever_rounded, color: _red, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Supprimer définitivement votre compte',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cette action est permanente et ne peut pas être annulée.',
            style: TextStyle(fontSize: 14, color: _red, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 24),
          _infoBox(
            'Ce qui sera supprimé',
            _red,
            Icons.delete_outline_rounded,
            [
              'Votre nom, email, numéro de téléphone et photo de profil',
              'Votre mot de passe et données d\'authentification',
              'Vos documents livreur (pièce d\'identité, permis, véhicule)',
            ],
          ),
          const SizedBox(height: 14),
          _infoBox(
            'Ce qui est conservé (obligations légales)',
            _textSecondary,
            Icons.info_outline_rounded,
            [
              'Historique des courses et livraisons (anonymisé)',
              'Données de facturation requises par la réglementation',
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: _textSecondary, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String title, Color color, IconData icon, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title,
              style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 5, color: color.withOpacity(0.6)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item,
                    style: const TextStyle(fontSize: 13, color: _textPrimary, height: 1.4)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ── Step 1 : Confirmation mot de passe ────────────────────────────────────

  Widget _buildPasswordStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: _red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_open_rounded, color: _red, size: 40),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Confirmez avec votre mot de passe',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Entrez votre mot de passe pour confirmer la suppression définitive de votre compte.',
            style: TextStyle(fontSize: 14, color: _textSecondary, height: 1.5),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _error != null ? _red : _border,
                width: _error != null ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: _pwCtrl,
              obscureText: _obscure,
              autofocus: true,
              onChanged: (_) { if (_error != null) setState(() => _error = null); },
              decoration: InputDecoration(
                hintText: 'Mot de passe',
                hintStyle: const TextStyle(color: Color(0xFF9BA3B4)),
                prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF9BA3B4), size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: const Color(0xFF9BA3B4), size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.error_outline_rounded, color: _red, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                  style: const TextStyle(color: _red, fontSize: 13)),
              ),
            ]),
          ],
          const SizedBox(height: 28),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _pwCtrl,
            builder: (_, value, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (value.text.isEmpty || _loading) ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  disabledBackgroundColor: _red.withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Supprimer définitivement mon compte',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _loading ? null : () => setState(() { _step = 0; _error = null; }),
              child: const Text('Retour', style: TextStyle(color: _textSecondary, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
