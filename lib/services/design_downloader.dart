
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/ui_design.dart';

/// Saves a design preview as a PNG in the device's Downloads/MastUI folder.
/// Android 10+ uses MediaStore and does not need a storage permission prompt.
abstract final class DesignDownloader {
  static const _channel = MethodChannel('app.mastui/design-download');

  static Future<void> download(UiDesign design) async {
    final imageBytes = await _loadImageBytes(design);
    try {
      await _channel.invokeMethod<void>('savePng', {
        'bytes': imageBytes,
        'fileName': '${design.id}.png',
      });
    } on PlatformException catch (error) {
      throw DesignDownloadException(
        error.message ?? 'The image could not be saved to Downloads.',
      );
    } on MissingPluginException {
      throw const DesignDownloadException(
        'Image downloads are currently available on Android only.',
      );
    }
  }

  static Future<Uint8List> _loadImageBytes(UiDesign design) async {
    final url = design.imageUrl;
    if (url != null) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) return response.bodyBytes;
      } catch (_) {
        // Report one concise error below instead of leaking a network error.
      }
    }

    final asset = design.imageAsset;
    if (asset != null) {
      return (await rootBundle.load(asset)).buffer.asUint8List();
    }

    throw const DesignDownloadException('This design image is unavailable.');
  }
}

class DesignDownloadException implements Exception {
  const DesignDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}
