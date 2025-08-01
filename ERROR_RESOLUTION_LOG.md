# エラー解決ログ

このファイルは開発中に発生したエラーとその解決方法を記録し、同じミスを繰り返さないためのナレッジベースです。

## ルール
- エラーが解決されるたびに、原因・対策・予防策を記録する
- 日付・エラーの種類・影響範囲を明記する
- 将来の開発者（自分含む）が参照しやすいよう詳細に記述する

---

## 2025-08-02: 初回プロジェクト作成時のエラー群

### 1. 一時ファイル競合エラー
**エラー内容:**
```
AddCourseView.swift.tmp.930.1754064482427: No such file or directory (2)
```

**原因:**
- Xcodeのビルドシステムで一時ファイルが適切にクリーンアップされない
- DerivedDataの破損またはキャッシュ競合

**対策:**
```bash
cd "/path/to/project"
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectName-*
find . -name "*.tmp*" -delete
```

**予防策:**
- 大幅なファイル変更後は必ずクリーンビルドを実行
- 一時ファイルの存在を定期的にチェック

---

### 2. ViewModelの内部プロパティアクセスエラー
**エラー内容:**
```swift
'persistenceController' is inaccessible due to 'private' protection level
```

**原因:**
- ViewからViewModelの`private`プロパティに直接アクセス
- MVVMアーキテクチャの設計原則違反

**対策:**
ViewModelに適切なpublicインターフェースを追加:
```swift
// ViewModel側
var managedObjectContext: NSManagedObjectContext { return context }
func save() { saveContext() }

// View側（修正前）
viewModel.persistenceController.container.viewContext
// View側（修正後）
viewModel.managedObjectContext
```

**予防策:**
- ViewModelの設計時に必要なpublicインターフェースを事前に定義
- `private`プロパティへの直接アクセスは絶対に避ける
- カプセル化の原則を常に意識する

---

### 3. SwiftUIの複雑な式コンパイルエラー
**エラー内容:**
```
The compiler is unable to type-check this expression in reasonable time
```

**原因:**
- SwiftUIの`.alert()`修飾子で複雑な条件式を使用
- 特に`.constant(viewModel.errorMessage != nil)`のような動的評価

**対策:**
専用の`@State`変数で制御を分離:
```swift
@State private var showingErrorAlert = false

.alert("エラー", isPresented: $showingErrorAlert)
.onChange(of: viewModel.errorMessage) { _, newValue in
    showingErrorAlert = newValue != nil
}
```

**予防策:**
- SwiftUI修飾子では単純なBinding変数を使用
- 複雑なロジックは`onChange`や計算プロパティに分離
- ViewBuilderの制限を常に意識する

---

### 4. Core Data初期化再利用エラー
**エラー内容:**
```
invalid reuse after initialization failure
```

**原因:**
- Core Dataモデルファイルの変更後、古いキャッシュが残存
- ビルドシステムが新しいモデル定義を正しく認識していない

**対策:**
```bash
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/ProjectName-*
# Core Dataモデルファイルの再生成を強制
```

**予防策:**
- `.xcdatamodeld`ファイル変更後は必ずクリーンビルド
- Core Dataのマイグレーション戦略を事前に計画
- モデル変更時のバージョン管理を適切に実施

---

### 5. NSFetchRequestスコープエラー
**エラー内容:**
```swift
Cannot find type 'NSFetchRequest' in scope
```

**原因:**
- `import CoreData`の不足
- Core Dataの型定義が見つからない

**対策:**
```swift
import SwiftUI
import CoreData  // 追加が必要
```

**予防策:**
- Core Dataを使用するファイルには必ず`import CoreData`を追加
- プロジェクトテンプレート作成時にimport文を事前定義

---

## エラー解決の一般的なワークフロー

1. **エラーメッセージの正確な把握**
   - コンパイラの出力を完全に読む
   - エラーの種類（コンパイル/ランタイム/リンク）を特定

2. **原因の分類**
   - 構文エラー
   - アーキテクチャ設計の問題
   - ビルドシステムの問題
   - 依存関係の問題

3. **修正の実施**
   - 最小限の変更で解決を試行
   - 変更内容を明確に記録

4. **検証とテスト**
   - クリーンビルドでの確認
   - 関連機能の動作テスト

5. **このログファイルの更新**
   - 毎回必ず記録する
   - 将来の参考になるよう詳細に記述

---

---

## 2025-08-02: プロジェクト整理時の軽微な問題

### 6. 未使用のContentView.swiftファイル
**問題:**
- デフォルトの「Hello, world!」画面が残存
- MainTabViewを使用しているのにContentView.swiftが不要
- Xcodeプレビューで関係ない画面が表示される

**対策:**
```bash
rm "/path/to/project/ContentView.swift"
```

**予防策:**
- プロジェクト作成時にテンプレートファイルの要否を確認
- メインエントリポイントを変更したら古いファイルを削除
- プロジェクト構造の整合性を定期的にチェック

---

### 7. 未使用変数の警告
**警告内容:**
```
initialization of immutable value 'calendar' was never used
```

**原因:**
- 変数を宣言したが実際には使用していない
- コードの最適化不足

**対策:**
```swift
// 修正前
let calendar = Calendar.current // 使用していない

// 修正後
// 不要な変数宣言を削除
```

**予防策:**
- コード作成時に必要性を十分検討
- 定期的にwarningを確認・修正
- 静的解析ツールの活用

---

## 2025-08-02: UI強化時のオプショナル値エラー

### 8. Optional Courseの強制アンラップエラー
**エラー内容:**
```
value of optional type 'Course?' must be unwrapped to a value of type 'Course'
```

**原因:**
- メソッドの引数でオプショナル値（Course?）を非オプショナル値（Course）が必要な関数に渡している
- SwiftUIのビューでオプショナルチェーンを適切に処理していない

**対策:**
```swift
// エラーのあるコード
getCourseColor(course).opacity(0.3)

// 修正後
course != nil ? getCourseColor(course!).opacity(0.3) : Color.clear
```

**予防策:**
- オプショナル値を扱う際は常にnilチェックを先に実行
- 強制アンラップ（!）の使用前に必ずnilでないことを確認
- オプショナルバインディング（if let, guard let）の積極的な使用

---

## 参考リンク
- [SwiftUI ViewBuilder制限について](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Core Data Best Practices](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [MVVM in SwiftUI](https://developer.apple.com/documentation/combine/receiving-and-handling-events-with-combine)