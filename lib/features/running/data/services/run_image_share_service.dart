import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class RunImageShareService {
  Future<void> sharePng({
    required Uint8List bytes,
    required Rect sharePositionOrigin,
    required bool Function() canShare,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('A imagem da corrida está vazia.');
    }

    if (!canShare()) return;

    final temporaryDirectory = await getTemporaryDirectory();
    final directory = Directory(
      path.join(temporaryDirectory.path, 'okan_run_shares'),
    );

    await directory.create(recursive: true);
    await _removeOldImages(directory);

    if (!canShare()) return;

    final file = File(
      path.join(directory.path, 'okan-corrida-${const Uuid().v4()}.png'),
    );

    await file.writeAsBytes(bytes, flush: true);

    if (!canShare()) {
      await file.delete();
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        title: 'Compartilhar corrida',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> _removeOldImages(Directory directory) async {
    final cutoff = DateTime.now().subtract(const Duration(days: 3));

    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || path.extension(entity.path) != '.png') {
          continue;
        }

        try {
          final modified = await entity.lastModified();

          if (modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } on FileSystemException {
          // A limpeza de um arquivo antigo não impede o compartilhamento.
        }
      }
    } on FileSystemException {
      // A limpeza é opcional; a criação da imagem continua.
    }
  }
}
