import 'dart:math' as math;
import 'dart:ui';

import 'package:latlong2/latlong.dart';

import '../models/friend_profile.dart';
import '../models/restaurant_record.dart';
import 'place_match.dart';

/// 地図上の1店舗分のピン要素（自分の記録 or フレンドの記録）。
class PinEntry {
  final RestaurantRecord record;
  final FriendProfile? friend; // null なら自分の記録

  const PinEntry({required this.record, this.friend});

  bool get isMine => friend == null;
  LatLng get point => record.latLng;
}

/// 近い場所にあるピンをまとめたグループ（F1：合体ピンの単位）。
class PinGroup {
  final List<PinEntry> entries;

  const PinGroup(this.entries);

  /// グループの代表座標（先頭要素の座標）。
  LatLng get point => entries.first.point;
  bool get hasMine => entries.any((e) => e.isMine);
  bool get isMerged => entries.length > 1;
}

/// ピンを「近い場所同士」でグループ化する。
///
/// 各ピンは、代表座標が [thresholdMeters] 以内にある既存グループのうち
/// 最初のものへ入る。無ければ新しいグループを作る。
List<PinGroup> groupPins(
  List<PinEntry> entries, {
  double thresholdMeters = PlaceMatch.samePlaceThresholdMeters,
}) {
  final groups = <List<PinEntry>>[];
  for (final entry in entries) {
    List<PinEntry>? target;
    for (final group in groups) {
      final rep = group.first;
      if (PlaceMatch.isSamePlace(
        entry.point.latitude,
        entry.point.longitude,
        rep.point.latitude,
        rep.point.longitude,
        thresholdMeters: thresholdMeters,
      )) {
        target = group;
        break;
      }
    }
    if (target != null) {
      target.add(entry);
    } else {
      groups.add([entry]);
    }
  }
  return groups.map(PinGroup.new).toList();
}

/// このズームでクラスタリング（F2）を有効にするか。
bool clusteringEnabled(double zoom) => zoom < 15;

/// クラスタリングのセルサイズ（度）。ズームが小さいほどセルは広い。
double clusterCellDegreesForZoom(double zoom) {
  // 画面上で約90px四方に相当する地理範囲をセルにする。
  return 360 * 90 / (256 * math.pow(2, zoom));
}

/// グループを格子セルでクラスタリングする。
/// 戻り値は「セルのリスト」で、各セルはその中にあるグループのリスト。
List<List<PinGroup>> clusterGroups(List<PinGroup> groups, double cellDegrees) {
  final cells = <String, List<PinGroup>>{};
  for (final group in groups) {
    final cx = (group.point.latitude / cellDegrees).floor();
    final cy = (group.point.longitude / cellDegrees).floor();
    cells.putIfAbsent('$cx:$cy', () => []).add(group);
  }
  return cells.values.toList();
}

/// クラスタの代表座標（内包する全ピンの平均）。
LatLng clusterCenter(List<PinGroup> cell) {
  var lat = 0.0;
  var lng = 0.0;
  var count = 0;
  for (final group in cell) {
    for (final entry in group.entries) {
      lat += entry.point.latitude;
      lng += entry.point.longitude;
      count++;
    }
  }
  return LatLng(lat / count, lng / count);
}

/// 合体グループのピンを扇状に広げるためのオフセット（px）を返す。
/// 2件なら左右、3件以上は円形に配置する。先頭は上方向。
List<Offset> fanOutOffsets(int count, {double radius = 36}) {
  if (count <= 1) return const [Offset.zero];
  if (count == 2) {
    final r = radius * 0.8;
    return [Offset(-r, 0), Offset(r, 0)]; // 2件は左右に分ける
  }
  return List.generate(count, (i) {
    final angle = -math.pi / 2 + (2 * math.pi * i / count);
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  });
}
