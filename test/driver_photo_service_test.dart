import 'dart:io';
import 'dart:math';

import 'package:atlasmove/services/driver_photo_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Photo d'appareil simulée : dégradé + grain, comme un document photographié.
File _cameraPhoto(Directory dir, int width, int height, {int grain = 40}) {
  final random = Random(1);
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    final base = (p.x * 255 ~/ width + p.y * 255 ~/ height) ~/ 2;
    int c(int v) => (v + random.nextInt(grain) - grain ~/ 2).clamp(0, 255);
    p
      ..r = c(base)
      ..g = c(200 - base ~/ 2)
      ..b = c(120);
  }
  final file = File('${dir.path}/photo_${width}x$height.jpg');
  file.writeAsBytesSync(img.encodeJpg(image, quality: 95));
  return file;
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('driver_photo_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('grande photo : JPEG de 1600 px au plus et moins de 1 Mo', () async {
    final source = _cameraPhoto(dir, 4000, 3000);
    expect(source.lengthSync(), greaterThan(DriverPhotoService.targetBytes));

    final photo = await DriverPhotoService.prepare(source.path);
    final out = img.decodeJpg(photo.file.readAsBytesSync())!;

    expect(photo.contentType, 'image/jpeg');
    expect(max(out.width, out.height), lessThanOrEqualTo(DriverPhotoService.maxSide));
    expect(photo.file.lengthSync(), lessThan(DriverPhotoService.targetBytes));
  });

  test('photo très chargée : réduite davantage pour passer sous 1 Mo', () async {
    final source = _cameraPhoto(dir, 4000, 3000, grain: 255);

    final photo = await DriverPhotoService.prepare(source.path);
    final out = img.decodeJpg(photo.file.readAsBytesSync())!;

    expect(max(out.width, out.height), lessThanOrEqualTo(DriverPhotoService.maxSide));
    expect(photo.file.lengthSync(), lessThan(DriverPhotoService.targetBytes));
  });

  group('Métadonnées retirées', () {
    /// Photo avec position GPS, téléphone, date et rotation EXIF (portrait
    /// enregistré en paysage, comme un appareil photo de téléphone).
    File photoWithGps(String name, {int width = 2000, int height = 1500}) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(200, 210, 230));
      image.exif.gpsIfd['GPSLatitudeRef'] = img.IfdValueAscii('N');
      image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(36, 1);
      image.exif.gpsIfd['GPSLongitudeRef'] = img.IfdValueAscii('E');
      image.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(3, 1);
      image.exif.imageIfd['Make'] = img.IfdValueAscii('TestPhone');
      image.exif.imageIfd['Model'] = img.IfdValueAscii('Model X');
      image.exif.imageIfd['DateTime'] = img.IfdValueAscii('2026:10:21 10:00:00');
      image.exif.imageIfd.orientation = 6; // à tourner de 90°
      final file = File('${dir.path}/$name')..writeAsBytesSync(img.encodeJpg(image));
      final exif = img.decodeJpgExif(file.readAsBytesSync())!;
      expect(exif.gpsIfd.isEmpty, isFalse, reason: 'la photo de départ doit avoir du GPS');
      return file;
    }

    void expectNoMetadata(File file) {
      final bytes = file.readAsBytesSync();
      final exif = img.decodeJpgExif(bytes);
      expect(exif == null || exif.isEmpty, isTrue, reason: 'aucun EXIF en sortie');
      expect(exif?.gpsIfd.isEmpty ?? true, isTrue, reason: 'aucune donnée GPS en sortie');
      // Aucun segment APP1 (EXIF / XMP) dans le fichier.
      for (var i = 0; i + 1 < bytes.length; i++) {
        if (bytes[i] == 0xFF && bytes[i + 1] == 0xDA) break; // début de l'image
        expect(bytes[i] == 0xFF && bytes[i + 1] == 0xE1, isFalse, reason: 'segment APP1 trouvé');
      }
    }

    test('photo avec GPS : plus aucune donnée GPS ni EXIF, rotation appliquée', () async {
      final photo = await DriverPhotoService.prepare(photoWithGps('gps.jpg').path);

      expectNoMetadata(photo.file);
      final out = img.decodeJpg(photo.file.readAsBytesSync())!;
      // 2000×1500 avec rotation 90° → portrait 1500×2000, réduit à 1600 de haut.
      expect(out.height, greaterThan(out.width));
    });

    test('HEIC converti en JPEG par le sélecteur (EXIF gardé) : métadonnées retirées', () async {
      // Le sélecteur natif rend un JPEG qui peut garder l'EXIF du HEIC d'origine.
      final converted = photoWithGps('image_picker_123.jpg', width: 4032, height: 3024);

      final photo = await DriverPhotoService.prepare(converted.path);

      expect(photo.contentType, 'image/jpeg');
      expectNoMetadata(photo.file);
    });
  });

  test('fichier non décodable : envoyé tel quel avec son type', () async {
    final heic = File('${dir.path}/photo.heic')..writeAsBytesSync([0, 1, 2, 3]);

    final photo = await DriverPhotoService.prepare(heic.path);

    expect(photo.file.path, heic.path);
    expect(photo.contentType, 'image/heic');
  });
}
