import 'package:firebase_auth/firebase_auth.dart';

/// يدير هوية المستخدم بـ Firebase — حساب مجهول تلقائي (يحمي المواعيد من
/// الضياع لو انحذف التطبيق أو انثبّت من جديد بنفس الجهاز)، مع إمكانية
/// اختيارية لربطه ببريد إلكتروني عشان يصير قابل للاسترجاع من أي جهاز.
class CloudAuthService {
  CloudAuthService._();
  static final CloudAuthService instance = CloudAuthService._();

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// تُستدعى مرة واحدة عند تشغيل التطبيق — قبل أي قراءة/كتابة لـ Firestore.
  Future<void> ensureSignedIn() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  String get uid => _auth.currentUser!.uid;

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  /// البريد المرتبط بالحساب، لو تم ربطه مسبقًا.
  String? get linkedEmail => _auth.currentUser?.email;

  /// يرفع الحساب المجهول لحساب حقيقي بنفس المعرّف ونفس البيانات — بدون
  /// أي عملية نقل، لأنه نفس الـ uid قبل وبعد الربط.
  Future<void> linkWithEmail(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _auth.currentUser!.linkWithCredential(credential);
  }
}
