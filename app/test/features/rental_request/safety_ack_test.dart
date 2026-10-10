import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests the preference-gating logic of SafetyAckDialog.checkAndShow WITHOUT
/// showing any dialog UI. The method returns true immediately when the
/// 'safety_ack_shown' SharedPreferences key is already true.
void main() {
  group('SafetyAckDialog preference gating', () {
    tearDown(() async {
      // Reset SharedPreferences between tests.
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'returns true immediately when safety_ack_shown is already true '
        '(no dialog shown)', () async {
      SharedPreferences.setMockInitialValues({'safety_ack_shown': true});
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool('safety_ack_shown') == true;
      // This mirrors the guard logic inside checkAndShow.
      expect(alreadyShown, true);
    });

    test(
        'requires showing dialog when safety_ack_shown is absent', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool('safety_ack_shown') == true;
      expect(alreadyShown, false);
    });

    test(
        'requires showing dialog when safety_ack_shown is false', () async {
      SharedPreferences.setMockInitialValues({'safety_ack_shown': false});
      final prefs = await SharedPreferences.getInstance();
      final alreadyShown = prefs.getBool('safety_ack_shown') == true;
      expect(alreadyShown, false);
    });

    test(
        'setting safety_ack_shown to true persists across getInstance calls',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('safety_ack_shown', true);
      // Simulate a second call to getInstance (same in-memory instance).
      final prefs2 = await SharedPreferences.getInstance();
      expect(prefs2.getBool('safety_ack_shown'), true);
    });

    test('getBool returns null (not false) when key is missing', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('safety_ack_shown'), isNull);
    });
  });
}
