import 'package:flutter/material.dart';

/// アプリ全体の共通パレット（グレー基調）。
///
/// 方針：色は「意味がある場所」だけに使う。
/// - UIの土台とボタンはグレー系で統一する
/// - 店のランク色（銅・銀・金…）とフレンドの識別色は意味があるので残す
/// - 名刺テーマは利用者が選ぶコンテンツなので対象外
class AppColors {
  AppColors._();

  /// 最も濃いグレー（主要ボタンの背景など）
  static const Color ink = Color(0xFF263238);

  /// 主要色（選択状態・強調）
  static const Color primary = Color(0xFF37474F);

  /// 副次色（アイコン・補助的な強調）
  static const Color slate = Color(0xFF546E7A);

  /// 薄いグレー（バッジ背景など）
  static const Color mist = Color(0xFFECEFF1);

  /// 画面の背景
  static const Color paper = Color(0xFFF7F7F5);

  /// 区切り線
  static const Color line = Color(0xFFE0E0E0);

  /// フレンド識別色のパレット（彩度を落とした色味で揃える）
  static const List<Color> friendPalette = [
    Color(0xFF5E7A68), // セージグリーン
    Color(0xFF546E7A), // スレート
    Color(0xFF7A6A53), // トープ
    Color(0xFF6A7BA2), // ダスティブルー
    Color(0xFF8A6D7B), // モーブ
    Color(0xFF4F7A72), // ティールグレー
    Color(0xFF97795D), // サンド
    Color(0xFF707A56), // オリーブ
  ];
}
