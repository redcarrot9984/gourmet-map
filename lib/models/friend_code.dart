import 'dart:math';

/// フレンド機能 v2 のフレンドコード（形式：GM-XXXXX-XXXXX）。
///
/// - 紛らわしい文字（0 / O / 1 / I）を除いた32種の文字から10文字を生成する
///   ため、組み合わせは 32^10 ≈ 1.1×10^15 通りあり総当たりは現実的に不可能。
/// - 生成には暗号論的に安全な [Random.secure] を使う。
/// - 旧形式（GM-＋4桁）はこの形式では無効。
class FriendCode {
  /// 使用する文字種（0/O/1/I を除外した32種）。
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static final RegExp _pattern =
      RegExp(r'^GM-[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$');

  /// 新しいフレンドコードを生成する。
  /// テスト用に [random] を差し替え可能（省略時は Random.secure()）。
  static String generate([Random? random]) {
    final rand = random ?? Random.secure();
    String part() =>
        List.generate(5, (_) => alphabet[rand.nextInt(alphabet.length)]).join();
    return 'GM-${part()}-${part()}';
  }

  /// 入力されたコードを正規形（GM-XXXXX-XXXXX）に整える。
  ///
  /// - 前後の空白除去・大文字化
  /// - ハイフンや空白が抜けていても、GM＋10文字が正しければ整形する
  /// 整形できない入力は、検証で弾けるよう大文字化した文字列をそのまま返す。
  static String normalize(String input) {
    final compact = input
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s\-]'), '')
        .replaceAll('　', '');
    if (compact.startsWith('GM') && compact.length == 12) {
      final body = compact.substring(2);
      final allInAlphabet = body.split('').every((c) => alphabet.contains(c));
      if (allInAlphabet) {
        return 'GM-${body.substring(0, 5)}-${body.substring(5)}';
      }
    }
    return input.trim().toUpperCase();
  }

  /// 正規形のフレンドコードかどうか。
  static bool isValidFormat(String code) => _pattern.hasMatch(code);
}
