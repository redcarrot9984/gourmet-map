import 'package:latlong2/latlong.dart';

/// 「同じ店かどうか」の判定ユーティリティ。
///
/// ピンの合体表示（F1）では距離のみで判定し、行きたいリストの重複判定や
/// 卒業判定では「距離＋店名の一致度」を使う。
class PlaceMatch {
  /// 同一地点とみなす距離（メートル）。
  static const double samePlaceThresholdMeters = 50;

  static const Distance _distance = Distance();

  static double metersBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return _distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  }

  static bool isSamePlace(
    double lat1,
    double lng1,
    double lat2,
    double lng2, {
    double thresholdMeters = samePlaceThresholdMeters,
  }) {
    return metersBetween(lat1, lng1, lat2, lng2) <= thresholdMeters;
  }

  /// 店名の表記ゆれを吸収する（空白除去・小文字化）。
  static String normalizeName(String name) {
    return name.replaceAll(RegExp(r'[\s　]+'), '').toLowerCase();
  }

  /// 店名が一致／類似しているか（完全一致、または一方が他方を含む）。
  static bool nameSimilar(String a, String b) {
    final na = normalizeName(a);
    final nb = normalizeName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.length >= 2 && nb.length >= 2) {
      return na.contains(nb) || nb.contains(na);
    }
    return false;
  }

  /// 距離が近く、店名も一致／類似していれば「同じ店」とみなす。
  static bool matches({
    required double lat,
    required double lng,
    required String name,
    required double otherLat,
    required double otherLng,
    required String otherName,
    double thresholdMeters = samePlaceThresholdMeters,
  }) {
    return isSamePlace(lat, lng, otherLat, otherLng,
            thresholdMeters: thresholdMeters) &&
        nameSimilar(name, otherName);
  }
}
