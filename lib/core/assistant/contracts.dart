import 'package:meetmind/core/models.dart';

// The assistant core depends only on these abstractions. Concrete engines
// (on-device parser, cloud LLM, EventKit/Google repositories, real prayer
// engines) implement them and are wired in the composition root.

/// Turns raw input into a draft event.
/// Implementations: on-device [NaturalLanguageEventParser] (shipped),
/// a cloud `LLMEventParser` (Phase 2). OCR/voice front-ends feed either one.
abstract class EventParser {
  Future<CaptureDraft?> parse(String text, {DateTime? now});
}

/// Resolves prayer times. The stub returns fixed daily times; a real engine
/// (astronomical calculation by location + method) conforms to the same API.
abstract class PrayerTimeProvider {
  DateTime timeFor(Prayer prayer, DateTime day);
}

/// A pluggable product capability. Calendar is the first; Meeting, Email,
/// Travel, Tasks, Chief-of-Staff… are future modules implementing this same
/// contract and registering with the core — the platform grows without a
/// redesign.
abstract class Capability {
  String get id;
  String get title;
}

/// Where capabilities register themselves so the core can discover them.
class CapabilityRegistry {
  final Map<String, Capability> _capabilities = {};

  void register(Capability capability) =>
      _capabilities[capability.id] = capability;

  Capability? byId(String id) => _capabilities[id];

  Iterable<Capability> get all => _capabilities.values;
}
