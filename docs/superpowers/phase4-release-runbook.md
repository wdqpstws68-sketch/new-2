# Phase 4 リリース実行手順 (User-Action Runbook)

これは **AI が代行できない、ユーザー本人による作業** の手順書です。Phase 1–3 で技術的な準備は完了しているので、以下を順に実行すれば App Store 公開まで進めます。

**所要時間目安**: 集中して 3-6 時間 + Apple 審査待ち 1-3 日 + TestFlight 観察 1 週間 (品質優先方針)。

**重要**: v1.0 は **広告なし** で出します。AdMob 関連は v1.1 で追加予定なので、ここでは AdMob 設定は不要です。

---

## ステップ 0: 残作業の確認 (5 分)

- [ ] `git log --oneline -10` で v1.0 リリース commit が揃っていることを確認
- [ ] `xcodebuild test -scheme PixelColoringGame -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` で全テスト green

---

## ステップ 1: Xcode 署名設定 (15 分)

1. Xcode で `PixelColoringGame.xcodeproj` を開く
2. プロジェクトファイル > PixelColoringGame target > **Signing & Capabilities**
3. "Automatically manage signing" を **チェック**
4. Team を選択 (Apple Developer Program に登録済みのアカウント)
5. Bundle Identifier が `com.pixelbloom.app` であることを確認
6. PixelColoringGameTests target も同様に Team を設定 (Bundle: `com.pixelbloom.app.tests`)
7. Xcode が自動で Provisioning Profile を作成するのを待つ
8. `Cmd+B` でビルドが警告なしで通ることを確認 (Real iPhone 接続時は端末でビルド成功を確認)

---

## ステップ 2: 実機ビルド・スモークテスト (30 分)

1. Mac に iPhone を有線で接続 (TestFlight に出す前にまず実機で動作確認)
2. Xcode で Destination を接続デバイスに切り替え
3. `Cmd+R` で実機ビルド・起動
4. 以下を確認:
   - [ ] アプリが正常に起動し、タイトル画面が表示される (v1.0 では ATT ダイアログは出ません)
   - [ ] レベル 1 つを最初から最後までプレイ (タップ、色塗り、完成画面)
   - [ ] confetti 演出が表示される
   - [ ] Reduce Motion を ON にして再プレイ → 演出が静かに縮退する
   - [ ] DebugMenu (TitleScreenView の version ラベル長押し) から各祝福を発火し、ChapterClear/Journey/Monthly 表示確認
   - [ ] 広告がどこにも表示されないこと (v1.0 仕様)
5. パフォーマンス確認: Instruments > Time Profiler で PixelBoardView at 4x zoom 時に 60fps 維持を確認

---

## ステップ 3: GitHub Pages 公開 (15 分)

1. GitHub.com でこのリポジトリ (`new-2`) の **Settings > Pages** へ
2. Source: **Deploy from a branch**
3. Branch: `main` / Folder: `/docs`
4. **Save** をクリック
5. 数分後 `https://<github-username>.github.io/new-2/site/index.html` でランディングページが表示されることを確認
   - もしくは `/docs` 直下に `index.html` をシンボリックリンクで配置するなどして `/site` パスを省略
6. **`docs/superpowers/store-metadata.md` の "サポート URL & プライバシー URL" を実際のページ URL に置き換える**
   - 例: `https://dodoharunori.github.io/new-2/site/privacy.html`
   - 例: `https://dodoharunori.github.io/new-2/site/support.html`

---

## ステップ 4: App Store Connect レコード作成 (30 分)

1. <https://appstoreconnect.apple.com/> にログイン
2. **My Apps > "+" > New App**
3. 以下を入力:
   - Platforms: iOS
   - Name: **Pixel Bloom**
   - Primary Language: 日本語
   - Bundle ID: **com.pixelbloom.app** (Xcode で署名後にここに表示される)
   - SKU: `pixel-bloom-v1`
   - User Access: Full Access
4. App 情報を入力 (詳細は `docs/superpowers/store-metadata.md` 参照):
   - Category: ゲーム > パズル (+ カジュアル)
   - Age Rating: 4+
   - Privacy Policy URL: ステップ 3 で取得した URL
   - Subtitle, Description, Keywords, Support URL を入力
5. App Privacy セクションを入力 (v1.0: 広告なしのため最小限):
   - Data Collected: **Crash Data** (Tracking=No, Linked=No, Purpose=App Functionality)
   - 他に該当データなし → "Data Not Collected" を選択
6. **Pricing and Availability**:
   - Free
   - All countries/regions
7. **Made for Kids: No**
8. Save

---

## ステップ 5: スクリーンショット撮影 (1-2 時間)

メタデータ仕様は `docs/superpowers/store-metadata.md` の最終セクション参照。

1. シミュレータを起動:
   ```bash
   xcrun simctl boot "iPhone 17 Pro Max"  # 6.7"
   xcrun simctl boot "iPad Pro 13-inch (M5)"
   open -a Simulator
   ```
2. アプリを `Cmd+R` で起動 (各シミュレータ別に)
3. 言語切替: アプリ内の設定から jp/en 切替できなければ、シミュレータの言語設定を変更
4. 撮影シナリオ通りに画面を作って `Cmd+S` で保存:
   - **1 枚目**: タイトル画面 (キャッチコピー焼き込みは Figma/Canva で後処理 OK)
   - **2 枚目**: プレイ中 (中ズーム、色を塗ってる瞬間)
   - **3 枚目**: 完成画面 (confetti 出てる瞬間)
   - **4 枚目**: コレクション画面 (並んだ完成済みアート)
   - **5 枚目**: デイリーカレンダー
5. iPhone 17 Pro Max (6.7"/6.9") と iPad Pro 13" (M5) の 2 デバイス × jp/en = 4 セット × 5 枚 = **20 枚** が最低限。iPhone 6.5"・iPad 12.9" は前者から派生でも OK。
6. ASC > App Store > スクリーンショット にアップロード

---

## ステップ 6: TestFlight Internal Test (1 週間)

1. Xcode で archive ビルド:
   - Scheme > Edit Scheme... > Run > Build Configuration: **Release**
   - Product > Destination: Any iOS Device (arm64)
   - **Product > Archive**
2. Archive 完了後、Organizer ウィンドウで **Distribute App > App Store Connect > Upload**
3. Export Compliance: ITSAppUsesNonExemptEncryption=false 設定済みなのでスキップされる
4. ASC でビルドが "processing" → "ready" になるのを待つ (15-30 分)
5. **TestFlight > Internal Testing**:
   - Testers: 自分 + 信頼できる 1-3 名 (Apple Developer Team 内 6 名まで無料)
   - Build を選択して "Add"
6. 1 週間プレイ:
   - 各 Tester は TestFlight App で受信、`docs/superpowers/specs/2026-05-12-v1.0-app-store-release-design.md` の §7.1 のテストプロトコル全項目を確認
   - クラッシュ報告は TestFlight 内のフィードバック機能で受け取れる

---

## ステップ 7: 本番審査提出 (Apple 審査 1-3 日)

最終チェックリスト:

- [ ] DebugMenu が Release ビルドで除外 (`#if DEBUG` で grep)
- [ ] スクリーンショットに「Test」「Debug」「Mock」が映り込んでいない
- [ ] 1024x1024 マーケティングアイコンに透過/角丸なし
- [ ] PrivacyInfo.xcprivacy が含まれている (Archive ログで確認)
- [ ] v1.0 で広告が表示されないこと (実機で念のため確認)

提出:

1. ASC > App Store > Pricing/Availability 確認
2. App Store > Build を Phase 4.6 の Build にリンク
3. **Submit for Review**
4. Release option: **"Manually release this version"** を選択 (Apple 審査 PASS 後すぐ公開せず、自分で公開タイミングをコントロール)

審査期間中:

- Apple から質問が来る可能性あり (Resolution Center)
- 主な棄却原因と対応:
  - Privacy Manifest 不整合 → PrivacyInfo.xcprivacy を実際のコードと整合
  - スクリーンショットに不適切な情報 → 撮り直し
  - 機能不足の指摘 → 通常は来ないが、来たら個別対応

---

## ステップ 8: 公開 (1 分)

審査 PASS の通知を受けたら:

1. ASC > App Store > **Release This Version** をクリック
2. 数時間〜最大 24 時間で App Store に並ぶ
3. 検索: App Store iPhone/iPad アプリで「Pixel Bloom」検索 → 表示確認

---

## ステップ 9: 公開後の必須フォロー

- [ ] App Store ダウンロード → 起動 → ATT → ホーム到達を実機確認
- [ ] AdMob 管理画面で本番広告のインプレッションが計上開始することを確認
- [ ] App Store Connect の Analytics でインストール数を観察
- [ ] クラッシュレポート (Xcode > Window > Organizer > Crashes) の常時監視を開始

---

## ロールバック / 緊急時対応

- App Store 公開後に致命的バグ発覚 → ASC > App Store > このバージョンの可用性をオフ
- 修正版を提出: Marketing Version を 1.0.1 にして再 Archive、再提出 (緊急なら Expedited Review を申請)

---

## 完了!

ここまで来たら「このゲームを App Store でリリースできるところまで完成させて欲しい」のゴールは達成です。お疲れさまでした。
