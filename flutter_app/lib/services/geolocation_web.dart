// Web implementation using `dart:html` geolocation API.
import 'dart:async';
import 'dart:html' as html;

Future<Map<String, double>?> getBrowserLocation() {
  final c = Completer<Map<String, double>?>();
  try {
    final geo = html.window.navigator.geolocation;
    if (geo == null) {
      c.complete(null);
    } else {
      geo.getCurrentPosition().then((pos) {
        final coords = pos.coords;
        final num? latNum = coords?.latitude;
        final num? lngNum = coords?.longitude;
        if (latNum != null && lngNum != null) {
          c.complete({'lat': latNum.toDouble(), 'lng': lngNum.toDouble()});
        } else {
          c.complete(null);
        }
      }).catchError((_) {
        c.complete(null);
      });
    }
  } catch (_) {
    c.complete(null);
  }
  return c.future;
}
