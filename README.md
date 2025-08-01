# 📱 At00 - 大学生向け授業欠席管理アプリ

大学生の単位管理をサポートし、「あと何回休める？」という不安を解消するiOSアプリケーションです。

## ✨ 主要機能

### 🗓️ 時間割機能
- 平日（月〜金）の1〜5限に対応
- 2学期分の時間割を保存可能
- 各授業の現在の欠席回数を表示
- 視覚的ステータス表示（緑・オレンジ・赤）

### 📝 欠席記録機能
- **ワンタップ欠席記録**: 時間割のマスをタップで即座に記録
- **詳細記録**: 長押しで種別選択（欠席・遅刻・早退・公欠）とメモ機能
- **誤操作対応**: 簡単な取り消し機能

### 📊 出席管理機能
- 授業回数の自動計算（祝日考慮）
- 欠席可能回数の管理（デフォルト: 総授業回数の1/3）
- 視覚的アラート（色分け表示）

### 📈 統計表示
- 月別/週別の欠席グラフ
- 授業別の出席率
- 学期全体の出席状況サマリー

### ⚙️ 設定機能
- 学期管理（新学期作成・切り替え）
- 授業管理（追加・編集・削除）
- 通知設定
- データアーカイブ機能

## 🎨 UI/UX設計

### デザインシステム
- **統一カラーパレット**: 12色の美しいカラーシステム
- **モダンカード設計**: 角丸16px + 微細なシャドウ
- **インタラクティブフィードバック**: タップ時のスケール効果
- **レスポンシブレイアウト**: デバイスサイズに自動対応

### ユーザビリティ
- シンプルで直感的な設計
- ワンタップ操作を最優先
- 情報の視認性重視
- 誤操作防止と簡単な修正

## 🏗️ 技術仕様

### 基本仕様
- **対応OS**: iOS 15.0以上
- **フレームワーク**: SwiftUI
- **アーキテクチャ**: MVVM パターン
- **データ管理**: Core Data（ローカルストレージ）

### プロジェクト構造
```
At00/
├── At00App.swift                    # メインアプリエントリポイント
├── Models/
│   └── AttendanceType.swift         # 出席記録タイプ定義
├── Services/
│   └── PersistenceController.swift  # Core Data管理
├── ViewModels/
│   └── AttendanceViewModel.swift    # メインビジネスロジック
├── Views/
│   ├── MainTabView.swift           # タブベースメインUI
│   ├── TimetableView.swift         # 時間割表示画面
│   ├── CourseDetailView.swift      # 授業詳細画面
│   ├── StatisticsView.swift        # 統計表示画面
│   └── SettingsView.swift          # 設定画面
├── Utils/
│   ├── DesignSystem.swift          # 統一デザインシステム
│   └── JapaneseHolidays.swift      # 日本祝日計算
└── AttendanceModel.xcdatamodeld    # Core Dataモデル
```

## 🚀 セットアップ

### 必要環境
- Xcode 15.0以上
- macOS 13.0以上
- iOS 15.0以上のシミュレーター/実機

### インストール手順
1. リポジトリをクローン
```bash
git clone https://github.com/[your-username]/At00.git
cd At00
```

2. Xcodeでプロジェクトを開く
```bash
open At00.xcodeproj
```

3. シミュレーター/実機でビルド・実行

### 開発コマンド
```bash
# ビルド（シミュレーター）
xcodebuild -scheme At00 -destination 'platform=iOS Simulator,name=iPhone 16' build

# クリーンビルド（問題発生時）
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/At00-*
```

## 🧪 テスト

### 単体テスト
```bash
xcodebuild test -scheme At00 -destination 'platform=iOS Simulator,name=iPhone 16'
```

### UI テスト
- 基本的な画面遷移
- タップ操作とフィードバック
- データの永続化

## 📚 開発ガイド

### コーディング規約
- Swift言語のベストプラクティスに従う
- MVVMアーキテクチャパターンを維持
- SwiftUIの宣言的UIパラダイムを活用
- Core Dataのベストプラクティスに従う

### エラー解決
プロジェクトには包括的なエラー解決ログが含まれています：
- `ERROR_RESOLUTION_LOG.md`: 発生したエラーと解決方法を記録
- 同じ問題の再発を防ぐための知識ベース

### 開発者向けドキュメント
- `CLAUDE.md`: Claude Code開発時の指針
- デザインシステムの詳細仕様
- Core Dataモデルの関係図

## 🎯 開発優先順位

1. ✅ 基本的な時間割作成と表示
2. ✅ ワンタップ欠席記録
3. ✅ 欠席可能回数の計算と視覚的表示
4. ✅ 詳細記録機能（遅刻/早退/公欠）
5. ✅ 統計表示
6. ✅ 設定機能とデータ管理
7. 🔄 通知機能（今後の実装予定）
8. 🔄 データエクスポート機能（今後の実装予定）

## 🤝 コントリビューション

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 👨‍💻 作者

**山内壮良** - 大学生向けの実用的なアプリケーション開発

## 🙏 謝辞

- SwiftUIコミュニティ
- Core Dataのベストプラクティス
- デザインインスピレーション

---

**「あと何回休める？」の不安を解消し、安心して学生生活を送れるようサポートします！** 🎓