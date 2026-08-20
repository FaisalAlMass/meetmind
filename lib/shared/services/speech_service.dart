import 'package:speech_to_text/speech_to_text.dart' as stt;

/// يغلّف speech_to_text — يدير الإذن والاستماع وتحويل الصوت لنص.
class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool get isListening => _speech.isListening;

  /// يبدأ الاستماع بلغة [lang] ('ar' أو 'en'). يستدعي [onResult] مع النص
  /// المتعرف عليه (جزئي أو نهائي)، و[onError] لو صار خطأ، و[onStatus]
  /// لمتابعة حالة الجلسة (نافع لإعادة ضبط الواجهة حتى لو ما صار خطأ
  /// صريح ولا نتيجة نهائية — جلسة عالقة بصمت).
  ///
  /// نعيد تهيئة الحزمة (initialize) قبل كل جلسة بدل تخزينها مرة وحدة
  /// فقط طول عمر التطبيق: لاحظنا إن أول جلسة تشتغل بس اللي بعدها تفشل
  /// بصمت على بعض الأجهزة (محرك الصوت الأصلي ما يتحرر كامل من الجلسة
  /// السابقة)، وإعادة التهيئة + مهلة قصيرة بعد الإلغاء تصلح المشكلة.
  Future<bool> listen({
    required String lang,
    required void Function(String text, bool isFinal) onResult,
    void Function(bool permanent)? onError,
    void Function(String status)? onStatus,
  }) async {
    if (_speech.isListening) {
      await _speech.cancel();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final available = await _speech.initialize(
      onError: (e) => onError?.call(e.permanent),
      onStatus: (status) => onStatus?.call(status),
    );
    if (!available) return false;

    final locales = await _speech.locales();
    String? localeId;
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(lang)) {
        localeId = locale.localeId;
        break;
      }
    }

    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: localeId ?? lang,
        // بدون pauseFor، بعض المنصات (خصوصًا iOS) تفضل بجلسة استماع
        // مفتوحة للأبد ولا تعتبر الكلام "خلص" إلا لو المستخدم أوقفها يدويًا.
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
      ),
    );
    return true;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
