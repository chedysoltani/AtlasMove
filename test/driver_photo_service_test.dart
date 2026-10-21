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

  test('fichier non décodable : envoyé tel quel avec son type', () async {
    final heic = File('${dir.path}/photo.heic')..writeAsBytesSync([0, 1, 2, 3]);

    final photo = await DriverPhotoService.prepare(heic.path);

    expect(photo.file.path, heic.path);
    expect(photo.contentType, 'image/heic');
  });
}
