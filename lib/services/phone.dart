import 'package:url_launcher/url_launcher.dart';

import '../data/calc.dart';

/// Opens the phone's own dialler with the number filled in.
/// The app never places a call by itself and never looks numbers up.
Future<bool> openDialler(String number) async {
  final String digits = dialable(number);
  if (digits.isEmpty) {
    return false;
  }
  try {
    return await launchUrl(Uri(scheme: 'tel', path: digits));
  } catch (_) {
    return false;
  }
}
