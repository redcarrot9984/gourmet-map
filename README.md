# グルメマップ (Gourmet Map)

自分が行った飲食店を爆速（10秒〜1分以内）で記録し、リピート回数に応じて「チャージ」が溜まり、友達とマップを共有したり称号（名刺）を獲得できるグルメマップアプリです。

---

## 実装済みロードマップ（ステップ①〜⑤）

### ①〜③ 初期設定・無料地図表示・高精度GPS現在地ピン
- `flutter_map` + OpenStreetMap によるAPIキー不要・完全無料の地図表示。
- `geolocator` による高精度GPS現在地取得＆パルスアニメーション付き現在地マーカー。

### ④ 周辺の飲食店検索（モック＋Yahoo!ローカルサーチAPI切り替え対応）
- [`lib/services/restaurant_search_service.dart`](lib/services/restaurant_search_service.dart)
- **モック自動生成モード（デフォルト・APIキー不要）**:
  - 現在地のすぐ近く（半径35m〜85m圏内）に架空の飲食店3件（**「絶品ラーメン店」「駅前カフェ」「隠れ家カレー」**）を自動生成して返します。
- **Yahoo!ローカルサーチAPI (YOLP) モード**:
  - `RestaurantSearchService.yahooAppId`（または画面上部の設定アイコン）にClient IDを設定するだけで、本番のYOLP API通信に自動切り替え可能です。

### ⑤ 1分以内で終わる爆速登録UI ＆ チャージ（リピート）機能
- [`lib/widgets/quick_register_sheet.dart`](lib/widgets/quick_register_sheet.dart) / [`lib/services/storage_service.dart`](lib/services/storage_service.dart)
- **画面下部中央の「＋ 店を登録（カメラ）」ボタン**:
  1. ボタンを押すと現在地周辺の店名候補が自動で選ばれ、ワンタップで切り替え可能（自由手入力にも対応）。
  2. **料理の写真**: `image_picker` でカメラ撮影またはアルバムから選択。
  3. **価格帯タグ**: 「〜1,000円」「1,000〜2,000円」「2,000円〜」をワンタップ選択。
  4. **良かった点タグ**: 「神コスパ」「味が最高」「提供が早い」「1人でも入りやすい」などを複数タップ選択。
- **リピート訪問による「チャージ」進化システム**:
  - `shared_preferences` によりスマホ内にローカル永続化。
  - すでに登録済みの店と同じ店を登録すると、新規ピンを増やさず **「来店チャージ数（chargeCount）」が +1** されます。
  - **チャージ数に応じた店舗ピンの豪華化** ([`lib/widgets/restaurant_pin_marker.dart`](lib/widgets/restaurant_pin_marker.dart)):
    - **1回 ＝ 銅色（ブロンズ・通常サイズ）**
    - **2回 ＝ 銀色（シルバー・少し大きいサイズ＋スター）**
    - **3回以上 ＝ 金色＋炎アイコン（ゴールド・特大サイズ＋MAX炎オーラ演出）**
  - マップ上の店舗ピンをタップすると詳細シート ([`lib/widgets/restaurant_detail_sheet.dart`](lib/widgets/restaurant_detail_sheet.dart)) が開き、登録写真やタグの確認、およびワンタップでの追加チャージが可能です。

### ⑥ 他の人へのシェア、X（旧Twitter）への名刺・店舗投稿機能
- [`lib/services/share_service.dart`](lib/services/share_service.dart) / [`lib/widgets/gourmet_card_sheet.dart`](lib/widgets/gourmet_card_sheet.dart)
- **Yahoo!ローカルサーチAPI (YOLP) 本番連携完了**:
  - Client ID をデフォルト設定し、現在地周辺のリアルな飲食店を自動取得します（設定アイコンからモック3店舗モードへの切り替えも可能）。
- **個別店舗のX投稿＆カード画像シェア**:
  - 登録直後のSnackBar、およびマップ上の店舗ピンをタップした詳細画面から **「𝕏 に店舗をポスト」** または **「カード画像をシェア」** がワンタップで行えます。
- **マイ・グルメ名刺の自動生成＆SNSシェア**:
  - 画面右下の **「🪪 名刺・シェア」** ボタンから、開拓店舗数・総チャージ数・現在の称号・マイベスト常連店TOP3がデザインされた「グルメ名刺」を表示。
  - 名刺を高解像度PNG画像としてキャプチャし、LINE・X・Instagram等へ画像＋テキスト付きでシェアできます。

### ⑦ フレンド機能（Supabase連携で友達のマップ共有）
- [`lib/services/friend_supabase_service.dart`](lib/services/friend_supabase_service.dart) / [`lib/widgets/friend_management_sheet.dart`](lib/widgets/friend_management_sheet.dart)
- **自分のフレンドコード自動発行 ＆ Supabaseクラウド同期**:
  - 固有のフレンドコード（例：`GM-XXXX`）を発行し、ワンタップでコピー・招待シェア可能。
  - Supabaseの `shared_maps` テーブルへのクラウドUpsert同期に対応。
- **フレンドのマップ追加 ＆ 重ね合わせ・個別切替表示**:
  - フレンドコード入力による友達追加に加え、今すぐ試せる **3人のサンプル友達（🍜メンマ先輩 / ☕カフェ巡り葵 / 🥩肉とスパイスの健）** をワンタップで現在地周辺に追加可能。
  - 画面上部の切替ピルバーで **「👥 自分＋友達」「📍 自分のマップ」「各フレンド個別マップ」** を瞬時に切り替えられます。
  - フレンドの店舗ピン ([`lib/widgets/friend_pin_marker.dart`](lib/widgets/friend_pin_marker.dart)) をタップすると詳細 ([`lib/widgets/friend_restaurant_detail_sheet.dart`](lib/widgets/friend_restaurant_detail_sheet.dart)) が開き、**「自分も行った！（マイマップにチャージ）」** で自分のマップへワンタップで取り込めます。

### ⑧ ゲーム性の強化（レベル＆EXP・全12称号コレクション・ピン豪華化演出・名刺テーマ変更）
- [`lib/models/gamification_data.dart`](lib/models/gamification_data.dart) / [`lib/widgets/charge_celebration_dialog.dart`](lib/widgets/charge_celebration_dialog.dart)
- **プレイヤーレベル ＆ EXPゲージ**: 開拓・チャージ・写真記録・フレンド追加に応じてEXPを獲得しレベルアップ。
- **全12種類の称号コレクション図鑑**: 解放した実績バッジを自由に「グルメ名刺」の二つ名として装備可能。
- **名刺デザインテーマ切替**: 「👑 ロイヤル黒金」「⚡ サイバー青」「🌸 和風朱雅（PRO限定）」の3テーマに切り替え可能。
- **チャージ＆ランクアップ祝賀ダイアログ**: 登録・チャージ完了時に獲得EXPとランク昇格を祝うポップアップ＋触覚バイブレーション演出。

### ⑨ UI/UXの全面ブラッシュアップ・広告（AdMob）と課金導線（PROパス）の実装
- [`lib/widgets/premium_paywall_sheet.dart`](lib/widgets/premium_paywall_sheet.dart) / [`lib/widgets/shop_list_sheet.dart`](lib/widgets/shop_list_sheet.dart)
- **統合ボトムアクションドック**: 片手親指で迷わず操作できる「名刺・称号」「＋ 店を登録」「フレンド」の一体型フローティングドック。
- **スマートヘッダー＆登録店リスト図鑑**: GPSデバッグ表示を折りたたみ式に整理し、登録店をランク別（金・銀・銅）に一覧・検索・ジャンプできる「マイグルメ図鑑」を追加。
- **AdMobスマートバナー ＆ PROパス課金導線**: 無料プラン時のバナー表示と、ワンタップで広告非表示＆限定名刺テーマを解放できるPROパス体験導線を実装。
