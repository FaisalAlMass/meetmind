import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meetmind/capabilities/calendar/domain/calendar_domain.dart';
import 'package:meetmind/core/models.dart';
import 'package:meetmind/shared/services/cloud_auth_service.dart';

/// يخزّن المواعيد على Firestore تحت users/{uid}/events — تبقى محفوظة حتى
/// لو انحذف التطبيق، وتتزامن تلقائيًا (Firestore عنده تخزين محلي مؤقت
/// مدمج، فتشتغل حتى بدون إنترنت وتتزامن لما يرجع الاتصال).
class FirestoreEventRepository implements EventRepository {
  FirestoreEventRepository(this._auth);

  final CloudAuthService _auth;

  CollectionReference<Map<String, dynamic>> get _events => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_auth.uid)
      .collection('events');

  @override
  Future<List<CalendarEvent>> all() async {
    final snapshot = await _events.get();
    final events = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  @override
  Future<List<CalendarEvent>> eventsFor(DateTime day) async {
    final events = await all();
    return events
        .where((e) =>
            e.start.year == day.year &&
            e.start.month == day.month &&
            e.start.day == day.day)
        .toList();
  }

  @override
  Future<void> add(CalendarEvent event) async {
    await _events.doc(event.id).set(_toMap(event));
  }

  @override
  Future<void> remove(String id) async {
    await _events.doc(id).delete();
  }

  Map<String, dynamic> _toMap(CalendarEvent e) => {
        'title': e.title,
        'start': e.start,
        'end': e.end,
        'location': e.location,
        'participants': e.participants,
        'isFocus': e.isFocus,
      };

  CalendarEvent _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    return CalendarEvent(
      id: doc.id,
      title: m['title'] as String,
      start: (m['start'] as Timestamp).toDate(),
      end: (m['end'] as Timestamp).toDate(),
      location: m['location'] as String?,
      participants:
          (m['participants'] as List<dynamic>).map((e) => e as String).toList(),
      isFocus: m['isFocus'] as bool,
    );
  }
}
