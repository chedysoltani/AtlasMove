import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import 'custom_button.dart';

class ImageUploadWidget extends StatelessWidget {
  final String title;
  final String? imagePath;
  final ValueChanged<String?> onImageChanged;
  final bool isRequired;

  const ImageUploadWidget({
    super.key,
    required this.title,
    this.imagePath,
    required this.onImageChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(height: 4),
          Text(
            '* Obligatoire',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showImagePicker(context),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: imagePath != null ? AppTheme.primaryColor : const Color(0xFFE0E0E0),
                width: imagePath != null ? 2 : 1,
              ),
            ),
            child: imagePath != null
                ? _buildImagePreview()
                : _buildPlaceholder(),
          ),
        ),
        if (imagePath != null) ...[
          const SizedBox(height: 8),
          CustomButton(
            text: 'Supprimer',
            type: ButtonType.outline,
            onPressed: () => onImageChanged(null),
            height: 40,
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imagePath!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorPlaceholder();
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
          ),
          const Center(
            child: Icon(
              Icons.camera_alt,
              color: AppTheme.textWhite,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 40,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'Télécharger une image',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PNG, JPG jusqu\'à 5MB',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image,
          size: 40,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'Erreur de chargement',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choisir une image',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildImageOption(
                          context,
                          'Appareil photo',
                          Icons.camera_alt,
                          () => _pickImage(ImageSource.camera),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildImageOption(
                          context,
                          'Galerie',
                          Icons.photo_library,
                          () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        onImageChanged(image.path);
      }
    } catch (e) {
      // Handle error
      debugPrint('Error picking image: $e');
    }
  }
}
