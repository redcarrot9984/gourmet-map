import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/restaurant_record.dart';

/// ステップ⑥：他の人へのシェア、X（旧Twitter）への名刺・店舗投稿サービス
class ShareService {
  /// 登録店舗数と総チャージ数から現在の「グルメ称号」を算出
  static String calculateGourmetTitle(List<RestaurantRecord> records) {
    final totalCharges =
        records.fold<int>(0, (sum, item) => sum + item.chargeCount);
    final goldCount = records.where((r) => r.chargeCount >= 3).length;

    final diamondCount = records.where((r) => r.chargeCount >= 7).length;

    if (diamondCount >= 2 || totalCharges >= 40) {
      return '🌈 グルメ界の頂点';
    } else if (goldCount >= 5 || totalCharges >= 25) {
      return '💎 至高のグルメ皇帝';
    } else if (goldCount >= 3 || totalCharges >= 15) {
      return '👑 伝説のグルメ覇王';
    } else if (records.length >= 12) {
      return '🗺️ エリア開拓の覇者';
    } else if (goldCount >= 1 || totalCharges >= 7) {
      return '🔥 街の常連マスター';
    } else if (records.length >= 6) {
      return '🧭 味覚の探検家';
    } else if (records.length >= 3 || totalCharges >= 3) {
      return '⚡ 爆速グルメハンター';
    } else if (records.isNotEmpty) {
      return '🍴 期待のグルメ開拓者';
    }
    return '🌱 駆け出しグルメ旅人';
  }

  /// 個別店舗の投稿・シェア用テキストを生成
  static String buildRestaurantShareText(RestaurantRecord record) {
    final tagsText = record.goodPoints.isNotEmpty
        ? record.goodPoints.map((t) => '#$t').join(' ')
        : '#おすすめグルメ';
    final mapUrl =
        'https://www.google.com/maps/search/?api=1&query=${record.latitude},${record.longitude}';

    final chargeEmoji = record.chargeCount >= 10
        ? '🔥'
        : record.chargeCount >= 2
            ? '⚡'
            : '📍';

    return '$chargeEmoji【グルメマップ記録】\n'
        '「${record.name}」（${record.category}）に${record.chargeCount}回目のチャージ！\n'
        '🏅 ランク：${record.rankTitle}\n'
        '💰 価格帯：${record.priceRange}\n'
        '👍 推し点：$tagsText\n'
        '🗺️ 場所：$mapUrl\n'
        '#グルメマップ #俺のグルメマップ';
  }

  /// グルメ名刺の投稿・シェア用テキストを生成
  static String buildGourmetCardShareText({
    required String userName,
    required List<RestaurantRecord> records,
  }) {
    final title = calculateGourmetTitle(records);
    final totalCharges =
        records.fold<int>(0, (sum, item) => sum + item.chargeCount);
    final goldCount = records.where((r) => r.chargeCount >= 3).length;

    // チャージ回数順のTOP3店舗
    final sorted = [...records]
      ..sort((a, b) => b.chargeCount.compareTo(a.chargeCount));
    final top3 = sorted.take(3).toList();

    final topShopsBuffer = StringBuffer();
    if (top3.isEmpty) {
      topShopsBuffer.writeln('・これから名店を開拓中！');
    } else {
      for (var i = 0; i < top3.length; i++) {
        final r = top3[i];
        final medal = i == 0 ? '🥇' : (i == 1 ? '🥈' : '🥉');
        topShopsBuffer.writeln('$medal ${r.name}（${r.chargeCount}回チャージ）');
      }
    }

    return '🪪【$userName のグルメ名刺】\n'
        '称号：$title\n'
        '📊 開拓店舗：${records.length}店 ／ 総チャージ：⚡$totalCharges回（金ピン🔥：$goldCount店）\n\n'
        '👑 マイベスト常連店：\n'
        '${topShopsBuffer.toString().trim()}\n\n'
        '#グルメマップ #グルメ名刺 #俺のグルメマップ';
  }

  /// X（旧Twitter）の投稿画面を直接起動してテキストをセットする
  static Future<bool> postToX(String text) async {
    final encoded = Uri.encodeComponent(text);

    // 1. まずXネイティブアプリスキームを試行
    final appUri = Uri.parse('twitter://post?message=$encoded');
    try {
      if (!kIsWeb && await canLaunchUrl(appUri)) {
        final launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    } catch (_) {
      // ネイティブスキーム失敗時はWeb Intentへフォールバック
    }

    // 2. X Web Intent URL (https://x.com/intent/tweet) を外部ブラウザまたはXアプリで開く
    final webUri = Uri.parse('https://x.com/intent/tweet?text=$encoded');
    try {
      return await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// OS標準のシェアシートでテキストをシェア（LINE / X / Discord / メール等）
  static Future<void> shareTextOnly(String text) async {
    await Share.share(text);
  }

  /// RepaintBoundaryで囲まれたカードWidgetを高解像度PNG画像に変換し、画像＋テキストで他アプリへシェア
  static Future<void> captureAndShareCard({
    required GlobalKey boundaryKey,
    required String shareText,
    String fileName = 'gourmet_share_card.png',
  }) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        await Share.share(shareText);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        await Share.share(shareText);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        // Web環境ではXFile.fromDataでシェアまたはテキストシェア
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: fileName,
        );
        await Share.shareXFiles([xFile], text: shareText);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
      );
    } catch (_) {
      // 画像書き出しに失敗した場合はテキストシェアへフォールバック
      await Share.share(shareText);
    }
  }
}
