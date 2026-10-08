import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../models/requests/update_profile_request.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────
  static const _navy = Color(0xFF0F172A);
  static const _navyLight = Color(0xFF1E293B);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _bg = Color(0xFFF8F9FB);
  static const _border = Color(0xFFE8ECF0);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  // ─── Controllers ─────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  User? _currentUser;
  String? _profilePictureUrl;
  String? _localAvatarPath; // aperçu local avant confirmation de l'upload
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _loadUserProfile();
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

  Future<void> _loadUserProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final response = await ProfileService.getCurrentProfile();
      if (mounted) {
        setState(() {
          _currentUser = response.user;
          _profilePictureUrl = ProfileService.resolveAvatarUrl(_currentUser?.profilePicture);
          _firstNameCtrl.text = _currentUser?.firstName ?? '';
          _lastNameCtrl.text = _currentUser?.lastName ?? '';
          _emailCtrl.text = _currentUser?.email ?? '';
          _phoneCtrl.text = _currentUser?.phone ?? '';
          _genderCtrl.text = _currentUser?.gender ?? '';
          _dobCtrl.text = _currentUser?.dateOfBirth ?? '';
          _countryCtrl.text = _currentUser?.country ?? '';
          _isLoadingProfile = false;
        });
        _animCtrl.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getErrorMessage(e);
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (image == null) return;
      // Aperçu local immédiat
      setState(() { _localAvatarPath = image.path; _isLoading = true; });
      try {
        final result = await ProfileService.uploadProfilePicture(image.path);
        final url = result['avatarUrl'] ??
            result['data']?['avatarUrl'] ??
            result['data']?['profilePicture'] ??
            result['profilePicture'];
        if (mounted && url is String) {
          setState(() {
            _profilePictureUrl = ProfileService.resolveAvatarUrl(url, bust: true);
            _localAvatarPath = null;
          });
          _showSnack('profile_extra.photo_updated'.tr(), success: true);
        } else if (mounted) {
          setState(() => _localAvatarPath = null);
          _showSnack('profile_extra.upload_no_url'.tr(), success: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _localAvatarPath = null);
          _showSnack('profile_extra.upload_failed'.tr(namedArgs: {'error': _getErrorMessage(e)}), success: false);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnack('common.unknown_error'.tr(), success: false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final request = UpdateProfileRequest(
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim().isEmpty ? null : _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        profilePicture: null,
        gender: _genderCtrl.text.trim().isEmpty ? null : _genderCtrl.text.trim(),
        dateOfBirth: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
        country: _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      );
      final response = await ProfileService.updateProfile(request);
      if (mounted) {
        _showSnack(response.message, success: true);
        await _loadUserProfile();
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = _getErrorMessage(e); _isLoading = false; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getErrorMessage(dynamic e) {
    if (e is ValidationException) return e.toString();
    if (e is AuthErrorResponse) return e.message;
    if (e is NetworkException) return e.message;
    return 'common.unknown_error'.tr();
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────────

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
                  ? _buildLoader()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                            children: [
                              if (_errorMessage != null) _buildError(),
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
                              _section('profile.contact'.tr(), Icons.contact_mail_rounded, [
                                _field(_emailCtrl, 'profile.email'.tr(), Icons.email_rounded,
                                    type: TextInputType.emailAddress),
                                _divider(),
                                _field(_phoneCtrl, 'profile.phone'.tr(), Icons.phone_rounded,
                                    type: TextInputType.phone),
                                _divider(),
                                _field(_countryCtrl, 'profile.country'.tr(), Icons.public_rounded),
                              ]),
                              const SizedBox(height: 16),
                              _languageButton(),
                              const SizedBox(height: 12),
                              _supportButton(),
                              const SizedBox(height: 12),
                              _guideButton(),
                              const SizedBox(height: 28),
                              _saveButton(),
                              const SizedBox(height: 16),
                              _deleteAccountButton(),
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

  // ─── Hero ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    final name = '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim();
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Stack(
          children: [
            // Rings
            Positioned(
              right: -20,
              top: -10,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05), width: 24),
                ),
              ),
            ),
            Column(
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: _iconBtn(Icons.arrow_back_ios_new_rounded),
                    ),
                    Text(
                      'profile.title'.tr(),
                      style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: _showLogoutDialog,
                      child: _iconBtn(Icons.logout_rounded,
                          color: const Color(0xFFEF4444).withOpacity(0.8)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _orange, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _orange.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _localAvatarPath != null
                            ? Image.file(
                                File(_localAvatarPath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarPlaceholder(),
                              )
                            : (_profilePictureUrl != null &&
                                    _profilePictureUrl!.isNotEmpty
                                ? Image.network(
                                    _profilePictureUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarPlaceholder(),
                                  )
                                : _avatarPlaceholder()),
                      ),
                    ),
                    if (_isLoading)
                      Positioned.fill(
                        child: ClipOval(
                          child: Container(
                            color: Colors.black45,
                            child: const Center(
                              child: SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2)),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickImage,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_orange, _orangeLight]),
                            shape: BoxShape.circle,
                            border: Border.all(color: _navy, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name.isEmpty ? 'profile.title'.tr() : name,
                  style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  _emailCtrl.text.isEmpty ? '' : _emailCtrl.text,
                  style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: _navyLight,
        child: const Icon(Icons.person_rounded, size: 44, color: Colors.white54),
      );

  Widget _iconBtn(IconData icon, {Color? color}) => Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 16),
      );

  // ─── Section ──────────────────────────────────────────────────────

  Widget _section(String title, IconData icon, List<Widget> fields) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: _orange),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: _textSecondary, letterSpacing: 0.4),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(children: fields),
        ),
      ],
    );
  }

  Widget _divider() => Divider(
      height: 1, thickness: 1, indent: 52, color: _border);

  // ─── Fields ───────────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
        decoration: InputDecoration(
          icon: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _orange, size: 15),
          ),
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _genderField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.wc_rounded, color: _orange, size: 15),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _genderCtrl.text.isEmpty ? null : _genderCtrl.text,
              decoration: InputDecoration(
                labelText: 'profile.gender'.tr(),
                labelStyle:
                    GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: _textSecondary),
              items: [
                DropdownMenuItem(value: 'male', child: Text('profile.male'.tr())),
                DropdownMenuItem(value: 'female', child: Text('profile.female'.tr())),
                DropdownMenuItem(value: 'other', child: Text('profile.other_gender'.tr())),
              ],
              onChanged: (v) => setState(() => _genderCtrl.text = v ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _dobCtrl,
        readOnly: true,
        style: GoogleFonts.poppins(fontSize: 14, color: _textPrimary),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime(1995),
            firstDate: DateTime(1940),
            lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(primary: _orange),
                textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(foregroundColor: _orange)),
              ),
              child: child!,
            ),
          );
          if (picked != null) {
            _dobCtrl.text =
                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          }
        },
        decoration: InputDecoration(
          icon: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cake_rounded, color: _orange, size: 15),
          ),
          labelText: 'profile.birth_date'.tr(),
          labelStyle:
              GoogleFonts.poppins(color: _textSecondary, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          suffixIcon: _dobCtrl.text.isEmpty
              ? null
              : const Icon(Icons.edit_rounded, color: _textSecondary, size: 16),
        ),
      ),
    );
  }

  // ─── Language button ──────────────────────────────────────────────

  Widget _languageButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/language'),
      icon: const Icon(Icons.language_rounded),
      label: Text('profile.language'.tr()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: _orange,
      ),
    );
  }

  Widget _supportButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/support'),
      icon: const Icon(Icons.support_agent_rounded),
      label: Text('support.title'.tr()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: _orange,
      ),
    );
  }

  Widget _guideButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/onboarding_client'),
      icon: const Icon(Icons.menu_book_rounded),
      label: Text('onboarding.replay'.tr()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: _orange,
      ),
    );
  }

  // ─── Save button ──────────────────────────────────────────────────

  Widget _saveButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [_orange, _orangeLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isLoading ? _border : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: _orange.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _textSecondary)),
                const SizedBox(width: 12),
                Text('common.loading'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, color: _textSecondary)),
              ])
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text('profile.edit'.tr(),
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────

  Widget _buildLoader() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: _orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const CircularProgressIndicator(
                color: _orange, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('common.loading'.tr(),
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
        ]),
      );

  Widget _buildError() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_errorMessage!,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFFEF4444))),
          ),
        ]),
      );

  Widget _deleteAccountButton() {
    return OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/delete_account'),
      icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
      label: Text('profile_extra.delete_account'.tr()),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        foregroundColor: const Color(0xFFEF4444),
      ),
    );
  }

  // ─── Logout ───────────────────────────────────────────────────────

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),
            Text('auth.logout'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 8),
            Text('auth.logout_confirm'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('common.cancel'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); _logout(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('profile.logout'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await ProfileService.logout();
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) _showSnack('common.unknown_error'.tr(), success: false);
    }
  }
}
