import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';

/// يستخرج نص من صورة عبر Tesseract (عربي + إنجليزي معًا، محليًا على
/// الجهاز). مدعومة على iOS وAndroid والويب بس — مو macOS/Windows/Linux.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  bool get isSupported =>
      kIsWeb || Platform.isIOS || Platform.isAndroid;

  Future<String> extractText(String imagePath) {
    return FlutterTesseractOcr.extractText(
      imagePath,
      language: 'ara+eng',
      args: const {'preserve_interword_spaces': '1'},
    );
  }
}
