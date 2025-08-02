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

## 2025-08-01: AttendanceManager機能移植時のエラー群

### 9. Array extension重複定義エラー
**エラー内容:**
```
Invalid redeclaration of 'subscript(safe:)'
```

**原因:**
- DesignSystem.swiftとEnhancedStatisticsView.swiftの両方で`Array`の`subscript(safe:)`拡張を定義
- Swiftでは同一拡張の重複定義は許可されない

**対策:**
```swift
// EnhancedStatisticsView.swiftから重複定義を削除
// Array安全アクセス用の拡張はDesignSystem.swiftで定義済みのため削除
```

**予防策:**
- プロジェクト全体で拡張は一箇所にまとめる
- 既存の拡張を確認してから新規追加
- 共通ユーティリティは中央集約する

---

### 10. Core Data Boolean属性の型エラー
**エラー内容:**
```
Cannot assign value of type 'Bool' to type 'NSNumber'
```

**原因:**
- Core DataのBoolean属性で`usesScalarValueType="NO"`が設定されている
- これによりSwiftでNSNumber型として扱われ、Bool値の直接代入ができない

**対策:**
```xml
<!-- 修正前 -->
<attribute name="isActive" optional="NO" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="NO"/>

<!-- 修正後 -->
<attribute name="isActive" optional="NO" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
```

**影響範囲:**
- Semester.isActive
- Course.isFullYear  
- Course.isNotificationEnabled

**予防策:**
- Core DataでBoolean属性を作成時は`usesScalarValueType="YES"`を設定
- Xcodeのデータモデルエディタで「Uses Scalar Value Type」をチェック
- 新規属性追加時は既存パターンとの一貫性を確認

---

## 2025-08-02: タップ処理のダブルカウント問題解決

### 11. EnhancedCourseCellのダブルカウント問題
**エラー内容:**
```
1回のタップで欠席回数が2回増加する
recordAbsence()が重複して呼び出される
```

**原因:**
- `Button(action: onTap)`と`TapGesture().onEnded { onTap() }`の両方が同じ処理を実行
- SwiftUIのジェスチャーシステムでアクションとジェスチャーが重複

**根本原因の分析:**
```swift
// 問題のあるコード（TimetableView.swift:329行目）
Button(action: onTap) {  // ← 1回目の呼び出し
    // UI Content
}
.simultaneousGesture(
    TapGesture()
        .onEnded {
            onTap()  // ← 2回目の呼び出し（重複）
        }
)
```

**対策:**
```swift
// 修正後のコード
Button(action: {}) {  // 空のアクションに変更
    // UI Content  
}
.simultaneousGesture(
    TapGesture()
        .onEnded {
            onTap()  // ジェスチャーでのみ処理
        }
)
```

**検証方法:**
1. コママスを1回タップ
2. 欠席回数が1回だけ増加することを確認
3. データベースに1件のみ記録されることを確認

**予防策:**
- SwiftUIでタップ処理を実装する際は、ButtonのactionかTapGestureのどちらか一方のみを使用
- 複数のジェスチャーを組み合わせる場合は処理の重複を避ける
- simultaneousGestureを使用する際は特に注意深くテストする

---

### 12. タップエフェクトの視認性問題
**問題:**
```
タップ時にコママス全体が薄暗くなって内容が見にくい
ダサいカウントエフェクト（+1テキスト、過度なアニメーション）
```

**原因:**
- `Color.black.opacity(0.1)`のオーバーレイで暗くなる
- 複雑なオフセットアニメーションとテキストエフェクト

**対策:**
```swift
// 修正前：暗いオーバーレイ
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(isPressed ? 0.1 : 0))
)

// 修正後：スマートな膨らみエフェクト
.scaleEffect(isPressed ? 1.05 : 1.0)
.animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
```

```swift
// 修正前：複雑なカウントエフェクト
.scaleEffect(showingCountAnimation ? 1.3 : 1.0)
.offset(y: countOffset)
// + "+1"テキスト表示

// 修正後：最小限のエフェクト
.scaleEffect(showingCountAnimation ? 1.1 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.8), value: showingCountAnimation)
```

**改善結果:**
- タップ時にコマ内容が明瞭に見える
- 軽やかで上品な膨らみエフェクト
- 数字の軽微なスケールアップで変更を示唆
- 0.2秒の素早いレスポンス

**予防策:**
- UIエフェクトは最小限に抑えて機能性を重視
- オーバーレイよりもスケールやオフセットでフィードバック提供
- アニメーション時間は短く（0.1-0.3秒）設定

---

## 2025-02-01: 白画面問題とCourseSelectionViewビルドエラー

### 13. 白画面問題とCourseSelectionViewビルドエラー
**🚨 問題の概要:**
- アプリ起動後、初めてコママスをタップして授業登録・編集を行おうとすると、下から真っ白なシートが表示される
- ビルド時にCourseSelectionView.swiftで構文エラーが発生

**🔍 根本原因分析:**
1. **構文エラー**: CourseSelectionView.swiftで重複したNavigationViewとtoolbar定義により余分な`}`が存在
2. **関数呼び出しエラー**: `saveExistingCourse()`でCourseパラメータが不足
3. **初期化問題**: AttendanceViewModelの非同期初期化が完了前にViewが表示される

**🛠️ 解決手順:**

#### 1. 構文エラー修正
```swift
// 削除: 重複したnavigationTitle以下の修飾子 (144-171行目)
.navigationTitle("授業選択")
.navigationBarTitleDisplayMode(.inline)
.toolbar { /* 重複内容 */ }
```

#### 2. 関数呼び出し修正
```swift
// 修正前
Button("保存") {
    saveExistingCourse()  // パラメータ不足
}

// 修正後
Button("保存") {
    if let course = selectedExistingCourse {
        saveExistingCourse(course)  // 正しいパラメータ
    }
}
```

#### 3. 初期化問題対応
```swift
// AttendanceViewModel.swift
init(persistenceController: PersistenceController = .shared) {
    // 非同期で初期化を実行
    DispatchQueue.main.async {
        self.setupSemesters()
        self.loadCurrentSemester()
        self.loadTimetable()
        self.isInitialized = true
    }
}

// EditCourseDetailView.swift
var body: some View {
    Group {
        if !viewModel.isInitialized || viewModel.currentSemester == nil {
            // ローディング状態を表示
            VStack {
                ProgressView()
                Text("読み込み中...")
            }
        } else {
            // メインコンテンツ
        }
    }
}
```

#### 4. NavigationView重複解決
```swift
// TimetableView.swift
.sheet(isPresented: $showingAddCourse) {
    if let timeSlot = selectedTimeSlot {
        NavigationView {  // 新規追加
            CourseSelectionView(/* params */)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
```

**✅ 解決結果:**
- ビルドエラー解決 (BUILD SUCCEEDED)
- 構文エラー完全修正
- 初期化フローの適切な管理

**🛡️ 再発防止策:**
1. **コード重複チェック**: 同じ修飾子や構造の重複を避ける
2. **型安全性**: 関数呼び出し時の引数チェックを徹底
3. **初期化順序管理**: ViewModelの初期化完了を適切に管理
4. **段階的テスト**: 各修正後に個別ビルドテストを実行
5. **ペア構造チェック**: 開き括弧と閉じ括弧の数を定期確認

**📊 修正ファイル一覧:**
- `/Views/CourseSelectionView.swift` - 構文修正、関数呼び出し修正
- `/ViewModels/AttendanceViewModel.swift` - 非同期初期化実装
- `/Views/EditCourseDetailView.swift` - 初期化チェック追加
- `/Views/TimetableView.swift` - NavigationView適切な配置

**🎯 学習ポイント:**
- SwiftUIのNavigationView階層管理の重要性
- ViewModelライフサイクルとView表示タイミングの同期
- 構文エラーの体系的なデバッグ手法

---

*この記録は2025-02-01時点での解決策です。同様の問題が発生した場合はこの手順を参考にしてください。*

---

## 参考リンク
- [SwiftUI ViewBuilder制限について](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Core Data Best Practices](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [MVVM in SwiftUI](https://developer.apple.com/documentation/combine/receiving-and-handling-events-with-combine)
- [SwiftUI Gesture処理のベストプラクティス](https://developer.apple.com/documentation/swiftui/gestures)