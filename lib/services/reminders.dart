import '../data/models.dart';
import '../l10n/strings.dart';

/// Daily medicine reminders, set as local notifications on the phone.
/// Nothing is sent anywhere: the phone's own scheduler shows them.
abstract class Reminders {
  Future<void> init();

  /// Asks the phone for permission to show notifications. Returns true if allowed.
  Future<bool> requestPermission();

  /// Replaces all scheduled reminders with one daily reminder per medicine.
  Future<void> sync(List<Medicine> meds, S t);
}

/// Used in tests and on platforms without notifications.
class NoReminders implements Reminders {
  const NoReminders();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> sync(List<Medicine> meds, S t) async {}
}
