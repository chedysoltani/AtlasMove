import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/profile_service.dart';
import '../models/requests/update_profile_request.dart';
import '../models/responses/auth_response.dart';
import '../core/network/http_client.dart';

/// Écran de profil utilisateur avec mise à jour des informations
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _profilePictureController = TextEditingController();
  final _genderController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _countryController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;
  String? _profilePictureUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _profilePictureController.dispose();
    _genderController.dispose();
    _dateOfBirthController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      debugPrint('🔄 Chargement du profil utilisateur...');
      final response = await ProfileService.getCurrentProfile();
      
      debugPrint('👤 Données utilisateur reçues:');
      debugPrint('  - ID: ${response.user.id}');
      debugPrint('  - Prénom: ${response.user.firstName}');
      debugPrint('  - Nom: ${response.user.lastName}');
      debugPrint('  - Email: ${response.user.email}');
      debugPrint('  - Téléphone: ${response.user.phone}');
      debugPrint('  - Pays: ${response.user.country}');
      debugPrint('  - Genre: ${response.user.gender}');
      debugPrint('  - Date de naissance: ${response.user.dateOfBirth}');
      
      setState(() {
        _currentUser = response.user;
        _profilePictureUrl = _currentUser?.profilePicture;
        
        // Pré-remplir les champs avec les données actuelles
        _firstNameController.text = _currentUser?.firstName ?? '';
        _lastNameController.text = _currentUser?.lastName ?? '';
        _emailController.text = _currentUser?.email ?? '';
        _phoneController.text = _currentUser?.phone ?? '';
        _profilePictureController.text = _currentUser?.profilePicture ?? '';
        _genderController.text = _currentUser?.gender ?? '';
        _dateOfBirthController.text = _currentUser?.dateOfBirth ?? '';
        _countryController.text = _currentUser?.country ?? '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image != null) {
        setState(() {
          _profilePictureController.text = image.path;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors de la sélection de l\'image: $e';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = UpdateProfileRequest(
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        profilePicture: _profilePictureController.text.trim().isEmpty ? null : _profilePictureController.text.trim(),
        gender: _genderController.text.trim().isEmpty ? null : _genderController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim().isEmpty ? null : _dateOfBirthController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      );

      final response = await ProfileService.updateProfile(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );

        // Recharger les données du profil
        await _loadUserProfile();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is ValidationException) {
      return error.toString();
    } else if (error is AuthErrorResponse) {
      return error.message;
    } else if (error is NetworkException) {
      return error.message;
    } else {
      return 'Une erreur inattendue est survenue: $error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mon Profil',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => _showLogoutDialog(),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading && _currentUser == null
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSectionTitle('INFORMATIONS PERSONNELLES'),
                          _buildInfoSection([
                            _buildModernField(
                              controller: _firstNameController,
                              label: 'Prénom',
                              icon: Icons.person_outline_rounded,
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildModernField(
                              controller: _lastNameController,
                              label: 'Nom',
                              icon: Icons.person_outline_rounded,
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildModernField(
                              controller: _genderController,
                              label: 'Genre',
                              icon: Icons.wc_rounded,
                              hint: 'male, female, other',
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildModernField(
                              controller: _dateOfBirthController,
                              label: 'Date de naissance',
                              icon: Icons.cake_outlined,
                              hint: 'YYYY-MM-DD',
                            ),
                          ]),
                          
                          const SizedBox(height: 25),
                          _buildSectionTitle('COORDONNÉES'),
                          _buildInfoSection([
                            _buildModernField(
                              controller: _emailController,
                              label: 'Email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildModernField(
                              controller: _phoneController,
                              label: 'Téléphone',
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                            const Divider(height: 1, indent: 50),
                            _buildModernField(
                              controller: _countryController,
                              label: 'Pays',
                              icon: Icons.public_rounded,
                            ),
                          ]),

                          const SizedBox(height: 35),
                          
                          // Bouton de mise à jour
                          _buildUpdateButton(),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _profilePictureUrl != null && _profilePictureUrl!.isNotEmpty
                      ? Image.network(
                          _profilePictureUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60, color: Colors.grey),
                        )
                      : const Icon(Icons.person, size: 60, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_firstNameController.text} ${_lastNameController.text}'.trim().isEmpty 
                ? 'Mon Profil' 
                : '${_firstNameController.text} ${_lastNameController.text}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          Text(
            _emailController.text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          icon: Icon(icon, color: AppTheme.primaryColor, size: 22),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          hintText: hint,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _updateProfile,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, Color(0xFFE85A2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Enregistrer les modifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await ProfileService.logout();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
