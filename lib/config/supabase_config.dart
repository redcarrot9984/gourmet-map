/// フレンド機能 v2：開発者が持つ Supabase プロジェクトへの接続設定。
///
/// publishable key は「アプリに同梱して公開してよい」ことを前提に設計された
/// 公開情報であり、実際のアクセス制御はデータベース側の RLS
/// （自分の行だけ読み書き可能）で行う。
/// service_role / secret key は RLS を迂回する管理者キーなので、
/// アプリやこのリポジトリには絶対に入れないこと。
class SupabaseConfig {
  static const String url = 'https://drjtcytkctohpecxnmgd.supabase.co';
  static const String publishableKey =
      'sb_publishable_cclrVyauzt88NKQJ3GbTbA_nB0c_PqE';
}
