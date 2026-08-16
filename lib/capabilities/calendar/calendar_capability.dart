import 'package:meetmind/core/assistant/contracts.dart';

/// The first capability module. Future modules (Meeting, Email, Travel,
/// Tasks, Chief of Staff…) implement this same contract and register the same
/// way — so the platform grows by adding modules, not by redesigning the core.
class CalendarCapability implements Capability {
  @override
  String get id => 'calendar';

  @override
  String get title => 'Calendar & scheduling';
}
