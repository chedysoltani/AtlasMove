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
/// compression avant envoi (1600 px au plus, JPEG qualité 75 %, moins de 1 Mo
/// visé pour passer sur un réseau faible).
class DriverPhotoService {
  DriverPhotoService._();

  static const int maxSide = 1600;
  static const int jpegQuality = 75;

  /// Taille visée ; au-delà, qualité réduite jusqu'à [minJpegQuality], puis
  /// côté réduit pas à pas ([fallbackSides]) : le texte d'un document reste lisible.
  static const int targetBytes = 1024 * 1024;
  static const int minJpegQuality = 55;
  static const List<int> fallbackSides = [1280, 1024];

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
      // Avec une qualité demandée, le sélecteur natif réencode en JPEG : une
      // photo HEIC (iPhone), que [prepare] ne sait pas décoder, n'arrive plus brute.
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    return prepare(picked.path);
  }

  /// Convertit en JPEG (voir [_toJpeg]). Si l'image ne peut pas être
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

/// Isolate : décodage, rotation EXIF appliquée, réduction, encodage JPEG
/// sous [DriverPhotoService.targetBytes] autant que possible.
Uint8List? _toJpeg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image = _fit(img.bakeOrientation(decoded), DriverPhotoService.maxSide);

  var quality = DriverPhotoService.jpegQuality;
  var jpeg = img.encodeJpg(image, quality: quality);
  while (jpeg.length > DriverPhotoService.targetBytes &&
      quality > DriverPhotoService.minJpegQuality) {
    quality -= 10;
    jpeg = img.encodeJpg(image, quality: quality);
  }
  for (final side in DriverPhotoService.fallbackSides) {
    if (jpeg.length <= DriverPhotoService.targetBytes) break;
    image = _fit(image, side);
    jpeg = img.encodeJpg(image, quality: quality);
  }
  return jpeg;
}

/// Réduit l'image pour que son plus grand côté fasse au plus [side] px.
img.Image _fit(img.Image image, int side) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= side) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: side)
      : img.copyResize(image, height: side);
}
