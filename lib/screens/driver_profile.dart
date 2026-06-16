import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../models/requests/update_profile_request.dart';
import '../services/profile_service.dart';
import '../core/network/http_client.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen>
    with SingleTickerProviderStateMixin {
  // ── Palette (matches profile_screen & dashboard) ──────────────────────────
  static const _navy       = Color(0xFF0F172A);
  static const _navyLight  = Color(0xFF1E293B);
  static const _orange     = Color(0xFFFF6B35);
  static const _bg         = Color(0xFFF8F9FB);
  static const _border     = Color(0xFFE8ECF0);
  static const _textPrim   = Color(0xFF1A1F36);
  static const _textSecond = Color(0xFF9BA3B4);

  // ── Controllers ───────────────────────────────────────────────────────────
  final _formKey       = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _genderCtrl    = TextEditingController();
  final _dobCtrl       = TextEditingController();
  final _countryCtrl   = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool    _isLoading        = false;
  bool    _isLoadingProfile = true;
  bool    _isUploadingPhoto = false;
  User?   _user;
  String? _error;
  String? _localAvatarPath; // local file preview before upload confirms

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _loadProfile();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _genderCtrl.dispose();
    _dobCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    setState(() { _isLoadingProfile = true; _error = null; });
    try {
      final resp = await ProfileService.getCurrentProfile();
      if (mounted) {
        setState(() {
          _user = resp.user;
          _firstNameCtrl.text = _user?.firstName ?? '';
          _lastNameCtrl.text  = _user?.lastName  ?? '';
          _emailCtrl.text     = _user?.email     ?? '';
          _phoneCtrl.text     = _user?.phone     ?? '';
          _genderCtrl.text    = _user?.gender    ?? '';
          _dobCtrl.text       = _user?.dateOfBirth ?? '';
          _countryCtrl.text   = _user?.country   ?? '';
          _isLoadingProfile   = false;
        });
        _animCtrl.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _error = _errMsg(e); _isLoadingProfile = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() { _isLoading = true; _error = null; });
    try {
      final req = UpdateProfileRequest(
        firstName:   _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName:    _lastNameCtrl.text.trim().isEmpty  ? null : _lastNameCtrl.text.trim(),
        email:       _emailCtrl.text.trim().isEmpty     ? null : _emailCtrl.text.trim(),
        phone:       _phoneCtrl.text.trim().isEmpty     ? null : _phoneCtrl.text.trim(),
        gender:      _genderCtrl.text.trim().isEmpty    ? null : _genderCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim().isEmpty       ? null : _dobCtrl.text.trim(),
        country:     _countryCtrl.text.trim().isEmpty   ? null : _countryCtrl.text.trim(),
      );
      await ProfileService.updateProfile(req);
      if (mounted) {
        _showSnack('Profil mis à jour', ok: true);
        await _loadProfile();
      }
    } catch (e) {
      if (mounted) setState(() { _error = _errMsg(e); });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errMsg(dynamic e) {
    if (e is ValidationException) return e.toString();
    if (e is NetworkException)    return e.message;
    return e.toString();
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (image == null || !mounted) return;
      setState(() { _localAvatarPath = image.path; _isUploadingPhoto = true; });
      try {
        final result = await ProfileService.uploadProfilePicture(image.path);
        final url = result['data']?['profilePicture'] ??
            result['profilePicture'] ??
            result['data']?['profile_picture'] ??
            result['profile_picture'];
        if (mounted) {
          if (url is String) {
            setState(() => _localAvatarPath = null);
            await _loadProfile();
            _showSnack('Photo mise à jour', ok: true);
          } else {
            _showSnack('Upload réussi mais URL manquante', ok: false);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _localAvatarPath = null);
          _showSnack('Échec upload: $e', ok: false);
        }
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur sélection photo: $e', ok: false);
    }
  }

  void _showSnack(String msg, {required bool ok}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: _isLoadingProfile
                  ? const Center(child: CircularProgressIndicator(color: _orange))
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                            children: [
                              if (_error != null) _buildErrorBanner(),

                              // ── Personal info ──────────────────────────
                              _section('profile.personal_info'.tr(), Icons.person_rounded, [
                                _field(_firstNameCtrl, 'profile.first_name'.tr(), Icons.badge_rounded),
                                _divider(),
                                _field(_lastNameCtrl, 'profile.last_name'.tr(), Icons.badge_outlined),
                                _divider(),
                                _genderField(),
                                _divider(),
                                _dobField(),
                              ]),
                              const SizedBox(height: 20),

                              // ── Contact ───────────────────────────────
                              _section('profile.contact'.tr(), Icons.contact_mail_rounded, [
                                _field(_emailCtrl, 'profile.email'.tr(), Icons.email_rounded,
                                    type: TextInputType.emailAddress),
                                _divider(),
                                _field(_phoneCtrl, 'profile.phone'.tr(), Icons.phone_rounded,
                                    type: TextInputType.phone),
                                _divider(),
                                _field(_countryCtrl, 'profile.country'.tr(), Icons.public_rounded),
                              ]),
                              const SizedBox(height: 20),

                              // ── Driver info (read-only) ───────────────
                              if (_user?.vehicleType != null || _user?.referralCode != null)
                                _section('Informations livreur', Icons.local_taxi_rounded, [
                                  if (_user?.vehicleType != null)
                                    _infoRow('Véhicule', _user!.vehicleType!.displayName,
                                        Icons.directions_car_rounded),
                                  if (_user?.vehicleType != null && _user?.referralCode != null)
                                    _divider(),
                                  if (_user?.referralCode != null)
                                    _infoRow('Code parrainage', _user!.referralCode!,
                                        Icons.card_giftcard_rounded),
                                ]),
                              if (_user?.vehicleType != null || _user?.referralCode != null)
                                const SizedBox(height: 20),

                              // ── Actions ───────────────────────────────
                              _section('Compte', Icons.settings_rounded, [
                                _actionRow(Icons.card_giftcard_rounded,
                                    'driver.referral_menu'.tr(), _orange,
                                    () => Navigator.pushNamed(context, '/referral')),
                                _divider(),
                                _actionRow(Icons.language_rounded,
                                    'profile.language'.tr(), Colors.blue,
                                    () => Navigator.pushNamed(context, '/language')),
                                _divider(),
                                _actionRow(Icons.support_agent_rounded,
                                    'Centre d\'aide', _orange,
                                    () => Navigator.pushNamed(context, '/support')),
                                _divider(),
                                _actionRow(Icons.logout_rounded,
                                    'auth.logout'.tr(), const Color(0xFFEF4444),
                                    _showLogoutDialog),
                              ]),
                              const SizedBox(height: 28),

                              // ── Save button ───────────────────────────
                              _saveButton(),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ───────────────────────────────────────────────────────────
  Widget _buildHero() {
    final first = _firstNameCtrl.text;
    final last  = _lastNameCtrl.text;
    final name  = '$first $last'.trim();
    final initials = first.isNotEmpty
        ? (first[0] + (last.isNotEmpty ? last[0] : '')).toUpperCase()
        : '?';

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          children: [
            // Top bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 38),
                Text('driver.profile_title'.tr(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                GestureDetector(
                  onTap: _showLogoutDialog,
                  child: _iconBtn(Icons.logout_rounded,
                      color: const Color(0xFFEF4444).withOpacity(0.85)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Avatar
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _orange, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: _orange.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAvatar,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipOval(
                      child: _isLoadingProfile
                          ? Container(color: _navyLight,
                              child: const Icon(Icons.person, color: Colors.white54, size: 44))
                          : _localAvatarPath != null
                              ? Image.file(File(_localAvatarPath!), fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarFallback(initials))
                              : (_user?.profilePicture != null &&
                                        _user!.profilePicture!.startsWith('http')
                                    ? Image.network(_user!.profilePicture!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _avatarFallback(initials))
                                    : _avatarFallback(initials)),
                    ),
                    if (_isUploadingPhoto)
                      ClipOval(
                        child: Container(
                          color: Colors.black54,
                          child: const Center(
                            child: SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          ),
                        ),
                      ),
                    if (!_isUploadingPhoto && !_isLoadingProfile)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 26, height: 26,
                          decoration: const BoxDecoration(
                              color: _orange, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(name.isEmpty ? 'Chargement...' : name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_user?.isVerified == true) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: Color(0xFF22C55E), size: 12),
                        SizedBox(width: 4),
                        Text('Vérifié',
                            style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_user?.vehicleType != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: _orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_taxi_rounded, color: _orange, size: 12),
                        const SizedBox(width: 4),
                        Text(_user!.vehicleType!.displayName,
                            style: const TextStyle(
                                color: _orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    return Container(
      color: _navyLight,
      child: Center(
        child: Text(initials,
            style: const TextStyle(
                color: _orange, fontSize: 30, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _iconBtn(IconData icon, {Color color = Colors.white}) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18),
    );
  }

  // ── Section ───────────────────────────────────────────────────────────────
  Widget _section(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(children: [
            Icon(icon, size: 15, color: _orange),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(
                    color: _textPrim,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _divider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, color: _border));

  // ── Editable field ────────────────────────────────────────────────────────
  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        Icon(icon, color: _orange, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: ctrl,
            keyboardType: type,
            style: const TextStyle(fontSize: 14, color: _textPrim, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: _textSecond, fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Read-only info row ────────────────────────────────────────────────────
  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, color: _orange, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: _textSecond, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: _textPrim, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Action row ────────────────────────────────────────────────────────────
  Widget _actionRow(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  color: _textPrim, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: _textSecond, size: 18),
        ]),
      ),
    );
  }

  // ── Gender field ──────────────────────────────────────────────────────────
  Widget _genderField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const Icon(Icons.wc_rounded, color: _orange, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _genderCtrl.text.isEmpty ? null : _genderCtrl.text,
            decoration: InputDecoration(
              labelText: 'profile.gender'.tr(),
              labelStyle: const TextStyle(color: _textSecond, fontSize: 12),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, color: _textPrim, fontWeight: FontWeight.w500),
            items: const [
              DropdownMenuItem(value: 'male',   child: Text('Homme')),
              DropdownMenuItem(value: 'female', child: Text('Femme')),
              DropdownMenuItem(value: 'other',  child: Text('Autre')),
            ],
            onChanged: (v) => setState(() => _genderCtrl.text = v ?? ''),
          ),
        ),
      ]),
    );
  }

  // ── Date of birth field ───────────────────────────────────────────────────
  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        const Icon(Icons.cake_rounded, color: _orange, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _dobCtrl,
            readOnly: true,
            style: const TextStyle(fontSize: 14, color: _textPrim, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: 'profile.birth_date'.tr(),
              labelStyle: const TextStyle(color: _textSecond, fontSize: 12),
              border: InputBorder.none, isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime(1995),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                        primary: _orange, onPrimary: Colors.white)),
                  child: child!,
                ),
              );
              if (d != null) {
                _dobCtrl.text =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ),
      ]),
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5))),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
      ]),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────
  Widget _saveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_orange, Color(0xFFFF8C42)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: _orange.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.logout'.tr()),
        content: Text('auth.logout_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.cancel'.tr())),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ProfileService.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                }
              },
              child: Text('auth.logout'.tr(),
                  style: const TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );
  }
}
