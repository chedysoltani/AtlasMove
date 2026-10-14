import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/utils/permission_gate.dart';

/// Photo prête à envoyer.
class DriverPhoto {
  final File file;
  final String contentType;
  const DriverPhoto(this.file, this.contentType);
}

/// L'appareil photo n'est pas autorisé.
class CameraPermissionDenied implements Exception {}

/// Photos des documents chauffeur : appareil photo ou galerie, puis
/// compression avant envoi (1600 px au plus, JPEG qualité 80 %).
class DriverPhotoService {
  DriverPhotoService._();

  static const int maxSide = 1600;
  static const int jpegQuality = 80;

  static final _picker = ImagePicker();

  /// Choix appareil photo / galerie ; null si l'utilisateur annule.
  static Future<ImageSource?> askSource(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: Color(0xFFFF6B35)),
            title: Text('upload.camera'.tr()),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF6B35)),
            title: Text('upload.gallery'.tr()),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Prend ou choisit une photo et la prépare ; null si l'utilisateur annule.
  /// Lance [CameraPermissionDenied] si l'appareil photo est refusé.
  static Future<DriverPhoto?> pick(ImageSource source) async {
    // Android : la permission CAMERA est déclarée (SDK d'appels), elle doit
    // donc être accordée avant d'ouvrir l'appareil photo. Sur iOS,
    // image_picker la demande lui-même.
    if (source == ImageSource.camera && Platform.isAndroid) {
      final status = await PermissionGate.run(Permission.camera.request,
          onTimeout: PermissionStatus.denied);
      if (!status.isGranted) {
        if (status.isPermanentlyDenied) await openAppSettings();
        throw CameraPermissionDenied();
      }
    }
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: maxSide.toDouble(),
      maxHeight: maxSide.toDouble(),
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return prepare(picked.path);
  }

  /// Convertit en JPEG (1600 px, qualité 80 %). Si l'image ne peut pas être
  /// décodée ici (ex. HEIC), le fichier part tel quel : le serveur accepte
  /// le HEIC et le convertit lui-même.
  static Future<DriverPhoto> prepare(String path) async {
    final source = File(path);
    try {
      final bytes = await source.readAsBytes();
      final jpeg = await compute(_toJpeg, bytes);
      if (jpeg != null) {
        final out = File('${Directory.systemTemp.path}/driver_doc_'
            '${DateTime.now().microsecondsSinceEpoch}.jpg');
        await out.writeAsBytes(jpeg, flush: true);
        return DriverPhoto(out, 'image/jpeg');
      }
    } catch (e) {
      debugPrint('DriverPhotoService: compression impossible (${e.runtimeType})');
    }
    return DriverPhoto(source, _contentTypeOf(path));
  }

  static String _contentTypeOf(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}

/// Isolate : décodage, rotation EXIF appliquée, réduction, encodage JPEG.
Uint8List? _toJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > DriverPhotoService.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: DriverPhotoService.maxSide)
        : img.copyResize(image, height: DriverPhotoService.maxSide);
  }
  return img.encodeJpg(image, quality: DriverPhotoService.jpegQuality);
}
