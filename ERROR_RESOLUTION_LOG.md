# エラー解決ログ

このファイルは開発中に発生したエラーとその解決方法を記録し、同じミスを繰り返さないためのナレッジベースです。

## ルール
- エラーが解決されるたびに、原因・対策・予防策を記録する
- 日付・エラーの種類・影響範囲を明記する
- 将来の開発者（自分含む）が参照しやすいよう詳細に記述する

---

## 2025-08-03 (最終): データエクスポート削除・時間割シート管理実装

### 🎯 要求の概要
- **タスクの種類**: 機能削除・時間割管理システム刷新
- **影響範囲**: データ管理システム全体・学期管理機能
- **要求内容**: エクスポート機能削除、時間割シート管理、通年科目同期システム実装

### 🔧 実装内容
1. **データエクスポート・インポート機能完全削除**
2. **TimetableSheetManagementView実装**: 時間割シート追加・削除管理
3. **AddTimetableSheetView実装**: 年度・学期選択ピッカー付き追加画面
4. **通年科目同期システム**: ペア学期間での自動同期機能
5. **設定画面のデータ管理セクション刷新**

### ✅ 解決方法
```swift
// 時間割シート管理
struct TimetableSheetManagementView: View {
    // シート一覧表示・削除機能
}

// 時間割シート追加
struct AddTimetableSheetView: View {
    @State private var selectedYear: Int // 年度選択
    @State private var selectedSemesterType: SemesterType // 学期選択
    // ピッカーロールによる直感的な選択UI
}

// 通年科目同期システム
func syncFullYearCourses() {
    // 年度別・学期タイプ別グループ化
    // ペア学期間での通年科目自動同期
}

func deleteFullYearCourseFromPair(course: Course) {
    // 通年科目削除時のペア同期削除
}
```

### 🛠️ 技術的解決策
1. **年度ピッカー**: 現在年度から前後3年の選択範囲
2. **学期ペア検索**: 同一年度の前期・後期自動検出
3. **通年科目同期**: Core Dataレベルでの自動同期
4. **データ整合性**: 削除・追加時のペア連携保証
5. **UI一貫性**: SegmentedPickerとWheelPickerの組み合わせ

### 🛡️ 予防策
1. **重複チェック**: 同一年度・学期の重複防止
2. **ペア関係表示**: 関連シートの視覚的表示
3. **削除確認**: 重要データ削除時の確認ダイアログ
4. **同期ログ**: 通年科目同期状況のデバッグ出力

---

## 2025-08-03 (続き): 通知機能・データエクスポート機能完全実装

### 🎯 要求の概要
- **タスクの種類**: 新機能実装・システム拡張
- **影響範囲**: 通知システム全体・データエクスポートシステム
- **要求内容**: 完全な通知機能とCSVエクスポート機能の実装

### 🔧 実装内容
1. **NotificationManagerクラス作成**: 包括的な通知管理システム
2. **欠席上限アラート通知**: 残り回数に応じた段階的警告システム
3. **授業開始前リマインダー**: 15分前の自動通知
4. **定期リマインダー通知**: カスタマイズ可能な入力促進通知
5. **DataExportManagerクラス作成**: 複数形式のデータエクスポート
6. **CSVエクスポート機能**: 出席記録・授業一覧・統計データの個別エクスポート
7. **統合エクスポート機能**: 全データの一括エクスポート

### ✅ 解決方法
```swift
// NotificationManager - 通知システム
class NotificationManager: ObservableObject {
    func scheduleAbsenceLimitWarning(...) // 欠席上限警告
    func scheduleClassReminders(...) // 授業開始前通知
    func scheduleReminderNotifications() // 定期リマインダー
}

// DataExportManager - エクスポートシステム  
class DataExportManager: ObservableObject {
    func exportAttendanceDataToCSV(...) // 出席記録CSV
    func exportCourseDataToCSV(...) // 授業一覧CSV
    func exportStatisticsToCSV(...) // 統計データCSV
    func exportAllDataToZip(...) // 全データ統合エクスポート
}

// AttendanceViewModel統合
private func checkAndSendAbsenceLimitNotification(for course: Course, newAbsenceCount: Int) {
    if remainingAbsences <= 2 {
        notificationManager.scheduleAbsenceLimitWarning(...)
    }
}
```

### 🛠️ 技術的解決策
1. **UNUserNotificationCenter統合**: iOS標準の通知システム活用
2. **非同期処理**: async/awaitによる効率的なデータ処理
3. **CSV生成**: UTF-8エンコードによる汎用性の高いデータフォーマット
4. **ファイル共有**: UIActivityViewControllerによるシステム統合
5. **エラーハンドリング**: Result型による安全なエラー管理

### 🛡️ 予防策
1. **通知権限管理**: 適切な権限チェックと失敗時の処理
2. **ファイル安全性**: 一時ファイルの適切な削除とパス管理
3. **データ整合性**: エクスポート前のデータ検証
4. **メモリ管理**: 大量データ処理時の効率的なリソース使用

---

## 2025-08-03: SettingsView機能削除・コード品質向上

### 🎯 要求の概要
- **タスクの種類**: UI機能削除・ユーザビリティ改善
- **影響範囲**: 設定画面のみ
- **要求内容**: 設定タブから学期管理・利用規約等の不要機能削除、データインポート準備中表示

### 🔧 実装内容
1. **学期管理セクション完全削除**: 学期別時間割リセット機能の除去
2. **法的情報セクション削除**: 利用規約・プライバシーポリシー・サポート項目除去
3. **データインポート準備中表示**: エクスポート機能と同様の「準備中」アラート実装
4. **コード品質改善**: CourseSelectionView.swiftの未使用戻り値警告修正

### ✅ 解決方法
```swift
// 削除前: 学期管理セクション
Section("学期管理") {
    NavigationLink("学期を追加") { NewSemesterView() }
    NavigationLink("現在の学期変更") { SemesterSwitchView() }
}

// 削除後: セクション自体を完全除去

// 追加: データインポート準備中表示
Button("データをインポート") {
    showingDataImportNotReady = true
}
.alert("準備中", isPresented: $showingDataImportNotReady) {
    Button("OK") { }
} message: {
    Text("データインポート機能は現在開発中です。\\n\\n今後のアップデートでご利用いただけるようになります。")
}

// 未使用戻り値警告修正
_ = viewModel.addCourse(...)  // 戻り値を明示的に無視
```

### 🛡️ 予防策
1. **機能要求の明確化**: 不要機能の早期特定・削除要求の正確な実装
2. **警告対応の徹底**: ビルド時の全警告チェック・即座対応
3. **UIシンプル化**: ユーザビリティを重視した機能選別

---

## 2025-08-02: 同名科目の欠席履歴同期問題・1日1カウント制限問題

### 🐛 問題の概要
- **エラーの種類**: 機能設計・ロジック問題
- **影響範囲**: 時間割管理・欠席記録機能
- **発生状況**: 同じ名前の科目を複数コマ追加した際の欠席履歴同期の不具合

### 🔍 根本原因
1. **1日1カウント制限**: `AttendanceViewModel.recordAbsence`で同名科目の今日の記録をチェックし、既存記録がある場合は新しい記録を作成しない仕様
2. **同期メカニズムの不完全性**: 新しい授業追加時に既存記録を複製する機能はあったが、リアルタイムでの完全な同期は実装されていない

### 🛠️ 実装した解決策

#### 1. 1日1カウント制限の廃止
```swift
// 修正前: 同名科目の今日の記録をチェックして重複を防ぐ
let checkRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
checkRequest.predicate = NSPredicate(/* 複雑な日付・科目名チェック */)
if !existingRecords.isEmpty { return } // 記録を作成しない

// 修正後: シンプルに記録を作成
let record = AttendanceRecord(context: context)
// ... 記録設定
saveContext()
```

#### 2. 欠席日数一括設定機能の追加
- `AttendanceViewModel.addAbsenceRecords`メソッド追加
- `EditCourseDetailView`に一括追加UIを実装
- アラートダイアログで日数指定・ワンタップで複数日分の欠席記録追加

### 🎯 修正箇所
- `AttendanceViewModel.swift:100-122` - `recordAbsence`メソッドの簡略化
- `AttendanceViewModel.swift:398-421` - `addAbsenceRecords`メソッド追加
- `EditCourseDetailView.swift:23-24` - 状態変数追加
- `EditCourseDetailView.swift:236-249` - 一括追加ボタンUI
- `EditCourseDetailView.swift:79-91` - アラートダイアログ
- `EditCourseDetailView.swift:424-438` - 一括追加処理メソッド

### ✅ テスト結果
- ビルド成功（警告4件は修正済み）
- 1日1カウント制限廃止により同名科目でも自由に欠席記録可能
- 授業編集画面から簡単に過去分の欠席を一括追加可能

### 🛡️ 予防策
1. **機能要件の明確化**: 「1日1カウント」のような制限は要件定義時に慎重に検討する
2. **同期機能のテスト**: 同名科目の機能は必ず複数コマで動作確認する
3. **UI/UX配慮**: 過去分の欠席追加など、実用性を考慮した機能を最初から組み込む

### 📝 学習ポイント
- 過度な制限は使いやすさを損なう場合がある
- リアルタイム同期よりもシンプルなデータ管理の方が保守性が高い
- ユーザーの実際の使用パターンを想定した機能設計が重要

---

## 2025-08-02: 同名科目の完全同期システム構築・日付指定機能実装

### 🐛 問題の概要
- **エラーの種類**: データ構造・同期ロジック・UX設計問題
- **影響範囲**: 時間割管理・欠席記録・統計表示全体
- **発生状況**: 同名科目の複数コマ追加時の欠席カウント不一致・統計データ不整合

### 🔍 根本原因の再分析
1. **記録作成の不完全同期**: 単一Courseにのみ記録作成、同名科目間で未同期
2. **統計計算の不整合**: 表示時は同名科目統合するが記録作成は個別
3. **データ重複問題**: 同名科目で同日記録が重複する可能性
4. **UX設計問題**: 欠席回数指定より日付指定の方が直感的

### 🛠️ 実装した根本的解決策

#### 1. 完全同期システム構築
```swift
// 記録作成時: 同名科目の全Courseに同じ記録を作成
func recordAbsence(for course: Course, type: AttendanceType = .absent, memo: String = "", date: Date = Date()) {
    let sameCourses = getAllCoursesWithSameName(courseName)
    
    // 重複防止チェック
    if hasAbsenceRecord(courseName: courseName, startDate: dayStart, endDate: dayEnd) {
        return
    }
    
    // 全同名科目に同期作成
    for sameCourse in sameCourses {
        let record = AttendanceRecord(context: context)
        // ... 同じ記録を全てに作成
    }
}
```

#### 2. 重複排除ロジック
```swift
// 統計計算: 日付ベースで重複排除
func getAbsenceCount(for course: Course) -> Int {
    // 同名科目の全記録を取得
    let allRecords = try context.fetch(request)
    
    // 日付ベースで重複排除
    var uniqueDates: Set<String> = []
    for record in allRecords {
        let dateString = "\(year)-\(month)-\(day)"
        uniqueDates.insert(dateString)
    }
    return uniqueDates.count
}
```

#### 3. 日付指定UI実装
- Sheetベースのモーダル採用（GraphicalDatePickerStyle）
- 直感的な日付選択・ワンタップ追加
- `AddAbsenceRecordSheet`カスタムコンポーネント

### 🎯 修正箇所詳細
- **AttendanceViewModel.swift**
  - `recordAbsence`: 完全同期システム（101-133行）
  - `undoLastRecord`: 同期削除（136-184行）
  - `getAbsenceCount`: 重複排除統計（187-221行）
  - ヘルパーメソッド追加: `getAllCoursesWithSameName`, `hasAbsenceRecord`（584-619行）
  - `addAbsenceRecord`: 日付指定対応（433-435行）

- **EditCourseDetailView.swift**
  - UIState変更: 回数→日付指定（23-24行）
  - Sheet UI実装（79-90行）
  - `AddAbsenceRecordSheet`コンポーネント（495-553行）
  - メソッド修正: `addAbsenceRecord`（425-439行）

- **EnhancedStatisticsView.swift**
  - 統計計算の重複排除対応（405-450行）

### ✅ テスト結果・改善効果
- **ビルド**: 成功・警告なし
- **データ整合性**: 同名科目間で完全同期・重複排除
- **統計精度**: 統計タブで正確な欠席数表示
- **UX向上**: 日付指定による直感的な操作

### 🛡️ アーキテクチャ改善
1. **完全同期**: 記録作成時に全同名科目に同期作成
2. **重複排除**: 統計計算で日付ベース重複排除
3. **データ整合性**: 作成・削除・統計で一貫したロジック
4. **モジュラーUI**: 再利用可能なコンポーネント設計

### 📝 技術的学習ポイント
- データ同期は記録作成時に行う方が確実
- 統計計算での重複排除は日付ベースが効果的
- SwiftUIのSheetとCustom Componentで優れたUX実現
- Core Dataでの複雑なクエリと整合性管理

### 🔄 今後の拡張性
- 同期システムは他の記録タイプにも適用可能
- 重複排除ロジックは期間指定機能にも活用
- カスタムコンポーネントは他の日付入力にも再利用可能

---

## 2025-08-02: 重複記録問題・リアルタイム反映問題の最終修正

### 🐛 問題の概要
- **エラーの種類**: データ記録重複・UI反映遅延問題
- **影響範囲**: タップ機能・履歴表示・設定反映
- **発生状況**: 同名科目複数コマで履歴重複、設定リセット反映遅延

### 🔍 根本原因の解明
1. **記録重複**: 同名科目全コマに記録作成→履歴リストで同日記録が複数表示
2. **UI非同期**: 設定タブのリセット後、他タブへの反映が遅延
3. **データ不整合**: カウント表示は正確だが履歴表示で重複問題

### 🛠️ 実装した最終解決策

#### 1. 代表Course記録方式
```swift
// 修正前: 全同名科目に記録作成（重複原因）
for sameCourse in sameCourses {
    let record = AttendanceRecord(context: context)
    // ... 全てに作成
}

// 修正後: 代表Course 1つのみに記録作成
let representativeCourse = sameCourses.first
let record = AttendanceRecord(context: context)
record.course = representativeCourse
```

#### 2. リアルタイム通知システム
```swift
// 設定リセット後即座通知
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
    NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
    NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
}

// TimetableView通知受信
.onReceive(NotificationCenter.default.publisher(for: .courseDataDidChange)) { _ in
    viewModel.loadTimetable()
    viewModel.objectWillChange.send()
}
```

### 🎯 修正箇所詳細
- **AttendanceViewModel.swift**
  - `recordAbsence`: 代表Course記録方式（100-131行）
  - `undoLastRecord`: 最新記録1つのみ削除（134-163行）
  - `getAbsenceCount`: 簡略化統計計算（165-186行）

- **SettingsView.swift**
  - リセット後通知送信（587-592行）

- **TimetableView.swift**
  - 通知受信処理追加（131-143行）

- **EnhancedStatisticsView.swift**
  - 重複排除ロジック簡略化（405-432行）

### ✅ 解決効果
- **履歴表示**: 同名科目でも重複なし・1日1記録のみ表示
- **カウント精度**: 同名科目統合で正確な欠席数表示
- **リアルタイム反映**: 設定リセット後即座に全タブ更新
- **データ整合性**: 記録・統計・表示で一貫したロジック

### 🏗️ アーキテクチャ改善
1. **代表Course方式**: 重複を根本的に防止
2. **統一通知システム**: NotificationCenterで即座反映
3. **シンプル統計**: 複雑な重複排除ロジック不要
4. **UI即応性**: ユーザー操作後の即座フィードバック

### 📝 学習・改善ポイント
- 同期問題は記録作成段階で解決が効果的
- NotificationCenterによる疎結合なリアルタイム更新
- 複雑なロジックより単純な設計の方が保守性高い
- UX向上のための細かな配慮（ハプティック・アニメーション）

### 🔮 今後の展望
- 代表Course方式は他機能にも適用可能
- 通知システムはリアルタイム同期の基盤として活用
- シンプルなデータ設計により新機能追加が容易

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

## 2025-02-01 (続き): 設定機能・UI改善・入力エラー解決

### 14. 設定タブの学期リセット機能の不完全同期問題
**🚨 問題の概要:**
- 設定画面で学期リセットを実行すると中途半端に授業が削除される
- 同名科目の同期削除が適切に機能していない
- 通年科目の他学期への影響が考慮されていない

**🔍 根本原因分析:**
- `resetSemesterTimetable`関数で該当学期の授業のみを削除
- 同名科目が他学期に存在する場合の連携処理が不足
- 通年科目の場合、前期・後期両方の削除が必要

**🛠️ 解決手順:**
```swift
// 修正前：該当学期のみ削除
let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
courseRequest.predicate = NSPredicate(format: "semester == %@", semester)

// 修正後：同名科目を全て削除
// 1. 削除対象の科目名を収集
var courseNamesToDelete = Set<String>()
for course in courses {
    if let courseName = course.courseName {
        courseNamesToDelete.insert(courseName)
    }
}

// 2. 同名科目のすべてのコースと記録を削除
for courseName in courseNamesToDelete {
    let allSameCourseRequest: NSFetchRequest<Course> = Course.fetchRequest()
    allSameCourseRequest.predicate = NSPredicate(format: "courseName == %@", courseName)
    // 関連するすべての記録を削除
}
```

**✅ 解決結果:**
- 学期リセット時の完全な同期削除を実現
- 通年科目の適切な処理
- データ整合性の確保

---

### 15. コママス表示改善要求への対応
**🎯 要求内容:**
1. 科目名を7文字目で改行し、12文字まで表示
2. カラーボックスの予定エリアを薄い色で表示
3. レイアウトは従来通り（半期:1行5列、通年:2行5列）

**🛠️ 実装内容:**

#### 科目名表示の改善
```swift
// 修正前：6文字で切り捨て
private func limitCourseName(_ name: String) -> String {
    if name.count <= 6 {
        return name
    }
    let index = name.index(name.startIndex, offsetBy: 6)
    return String(name[..<index])
}

// 修正後：6文字目まで表示し、7文字目で改行
private func limitCourseName(_ name: String) -> String {
    if name.count <= 6 {
        return name
    } else if name.count <= 12 {
        let firstLineEnd = name.index(name.startIndex, offsetBy: 6)
        let firstLine = String(name[..<firstLineEnd])
        let secondLine = String(name[firstLineEnd...])
        return firstLine + "\n" + secondLine
    } else {
        // 12文字を超える場合は12文字で切り捨て
        let firstLineEnd = name.index(name.startIndex, offsetBy: 6)
        let secondLineEnd = name.index(name.startIndex, offsetBy: 12)
        let firstLine = String(name[..<firstLineEnd])
        let secondLine = String(name[firstLineEnd..<secondLineEnd])
        return firstLine + "\n" + secondLine
    }
}
```

#### カラーボックス予定エリアの視覚化
```swift
// カウントされていない予定エリア
} else {
    // まだ欠席していない部分：薄い灰色で予定エリアを表示
    return Color.gray.opacity(0.3)
}
```

**✅ 実装結果:**
- 科目名の可読性向上（最大12文字表示）
- カラーボックスの予定エリア可視化
- ユーザビリティの大幅改善

---

### 16. 授業編集画面のトランザクション管理問題
**🚨 問題の概要:**
- 編集画面で欠席履歴を削除後、キャンセルボタンを押してもデータが削除されたまま
- 保存時のみ変更を反映すべきところ、即座にCore Dataに保存している

**🔍 根本原因分析:**
```swift
// 問題のあるコード
private func deleteAbsenceRecord(_ record: AttendanceRecord) {
    viewModel.managedObjectContext.delete(record)
    try viewModel.managedObjectContext.save() // 即座に保存
}
```

**🛠️ 解決手順:**
```swift
// 1. 削除予定を一時保持する状態を追加
@State private var deletedRecords: Set<AttendanceRecord> = []

// 2. 削除時は予定として記録のみ
private func deleteAbsenceRecord(_ record: AttendanceRecord) {
    deletedRecords.insert(record)
    if let index = absenceRecords.firstIndex(of: record) {
        absenceRecords.remove(at: index)
    }
}

// 3. 保存時に実際に削除実行
private func saveChanges() {
    for record in deletedRecords {
        viewModel.managedObjectContext.delete(record)
    }
    // その他の保存処理
}

// 4. キャンセル時は削除予定をリセット
Button("キャンセル") {
    deletedRecords.removeAll()
    dismiss()
}
```

**✅ 解決結果:**
- 適切なトランザクション管理
- キャンセル時の変更破棄機能
- 保存時のみ変更反映

---

### 17. TextFieldのRTIInputSystemClientエラー
**🚨 問題の概要:**
```
-[RTIInputSystemClient remoteTextInputSessionWithID:performInputOperation:] 
perform input operation requires a valid sessionID. 
inputModality = Keyboard, inputOperation = <null selector>, customInfoType = UIEmojiSearchOperations
```

**🔍 根本原因分析:**
- SwiftUIのTextFieldでキーボード関連の修飾子の競合
- `keyboardType(.default)`の重複設定による問題

**🛠️ 解決手順:**
```swift
// 修正前：重複する修飾子
TextField("授業名を入力", text: $courseName)
    .keyboardType(.default)  // 削除
    .autocorrectionDisabled()
    .textInputAutocapitalization(.words)
    .submitLabel(.done)

// 修正後：競合を回避
TextField("授業名を入力", text: $courseName)
    .autocorrectionDisabled()
    .textInputAutocapitalization(.words)
    .submitLabel(.done)
    .onTapGesture {
        // TextFieldを確実にアクティブにする
    }
```

**✅ 解決結果:**
- RTIInputSystemClientエラーの解消
- スムーズなテキスト入力体験

---

### 18. カウントエフェクトの発動不具合
**🚨 問題の概要:**
- コママスのカウントエフェクトがまれに発動しない
- タップしてもスケールエフェクトが表示されない場合がある

**🔍 根本原因分析:**
- `previousCount`の初期化タイミングの問題
- エフェクト発動条件が曖昧（`!=`による比較）

**🛠️ 解決手順:**
```swift
// 修正前：曖昧な条件
.onChange(of: absenceCount) { oldValue, newValue in
    if newValue != previousCount {  // 不正確
        // エフェクト処理
    }
    previousCount = newValue
}

// 修正後：厳密な条件と初期化
.onChange(of: absenceCount) { oldValue, newValue in
    if newValue > previousCount {  // 増加時のみ
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            showingCountAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                showingCountAnimation = false
            }
        }
    }
    previousCount = newValue
}
.onAppear {
    previousCount = absenceCount  // 確実な初期化
}
```

**✅ 解決結果:**
- カウントエフェクトの確実な発動
- アニメーション体験の安定化

---

### 19. UI簡素化とクリーンアップ
**🎯 実施内容:**
- 時間割タブの不要な設定ボタンを削除
- ナビゲーション領域のスッキリ化

```swift
// 削除されたコード
ToolbarItem(placement: .navigationBarTrailing) {
    Button("設定") {
        // 設定画面を表示
    }
}
```

**✅ 効果:**
- シンプルなUI
- ユーザーの混乱回避

---

**🛡️ 再発防止策:**
1. **トランザクション管理**: 編集画面では一時状態管理を確実に実装
2. **TextField設定**: 修飾子の重複を避け、必要最小限の設定
3. **アニメーション**: 初期化タイミングとトリガー条件を明確化
4. **UI設計**: 機能の必要性を常に検証

**📊 修正ファイル一覧:**
- `AttendanceViewModel.swift` - リセット機能の同期改善
- `TimetableView.swift` - UI表示とエフェクト改善
- `EditCourseDetailView.swift` - トランザクション管理とTextField修正
- `CourseSelectionView.swift` - TextField問題修正

**🎯 学習ポイント:**
- Core Dataのトランザクション境界の重要性
- SwiftUI修飾子の適切な組み合わせ
- アニメーション状態管理のベストプラクティス

---

*この記録は2025-02-01セッション完了時点での解決策です。*

---

## 2025-08-03: アーキテクチャレベルの品質問題

### 🐛 問題の概要
- **エラーの種類**: アーキテクチャ・パフォーマンス・クラッシュリスク
- **影響範囲**: アプリ全体のデータ同期・安定性・パフォーマンス
- **発生状況**: コード品質分析により発見された複数の重大問題

### 🔍 根本原因
1. **複数ViewModelインスタンス**: 各ビューが独自のViewModelを生成し、データ不整合
2. **fatalError使用**: エラー時にアプリがクラッシュ
3. **メインスレッドCore Data操作**: UIフリーズのリスク
4. **N+1クエリ問題**: 時間割の25マスそれぞれで個別クエリ実行
5. **通知の不統一**: 一部の操作のみNotificationCenter使用

### 🛠️ 実装した解決策

#### 1. 環境オブジェクトによるViewModel共有
```swift
// At00App.swift
@StateObject private var attendanceViewModel = AttendanceViewModel()
.environmentObject(attendanceViewModel)

// 各View
@EnvironmentObject private var viewModel: AttendanceViewModel
```

#### 2. fatalErrorの除去
```swift
// 修正前
fatalError("Core Data error: \(error)")

// 修正後
print("Core Data error: \(error)")
NotificationCenter.default.post(name: .coreDataError, object: nil, userInfo: ["error": error])
```

#### 3. 非同期Core Data処理
```swift
// 修正後
Task {
    await initializeData()
}

@MainActor
private func initializeData() async {
    await context.perform {
        self.setupSemesters()
        self.loadCurrentSemester()
        self.loadTimetable()
    }
}
```

#### 4. キャッシュシステムの実装
```swift
@Published var absenceCountCache: [String: Int] = [:]

func loadAllAbsenceCounts() {
    // 一括取得してキャッシュ
}

func getCachedAbsenceCount(for course: Course) -> Int {
    // キャッシュから取得
}
```

#### 5. 共通UIスタイル定義
```swift
// CommonStyles.swift
struct PrimaryButtonStyle: ButtonStyle { }
struct SecondaryButtonStyle: ButtonStyle { }
struct NavigationCancelButton: View { }
```

### 🎯 修正箇所
- `At00App.swift:14,20` - 環境オブジェクト設定
- `TimetableView.swift:12` - @StateObject → @EnvironmentObject
- `SettingsView.swift:14` - @StateObject → @EnvironmentObject
- `EnhancedStatisticsView.swift:12` - @StateObject → @EnvironmentObject
- `StatisticsView.swift:12` - @StateObject → @EnvironmentObject
- `PersistenceController.swift:62,78` - fatalError削除
- `AttendanceViewModel.swift:36-60` - 非同期初期化
- `AttendanceViewModel.swift:63-118` - キャッシュシステム
- `AttendanceViewModel.swift:749-777` - バッチ保存
- `CommonStyles.swift` - 新規ファイル作成

### 📊 改善効果
- **クラッシュリスク**: fatalError削除により大幅削減
- **パフォーマンス**: N+1クエリ解消により最大25倍高速化
- **データ整合性**: 単一ViewModelによる完全同期
- **保守性**: 共通スタイルによるコード重複削減
- **ユーザー体験**: より安定した動作とスムーズなレスポンス

### 🛡️ 今後の予防策
1. **アーキテクチャレビュー**: 定期的なコード品質分析
2. **パフォーマンステスト**: クエリ効率の監視
3. **エラーハンドリング標準**: fatalError禁止ルール
4. **UI標準化**: CommonStylesの活用徹底
5. **非同期処理原則**: Core Data操作は常に非同期

---

## 参考リンク
- [SwiftUI ViewBuilder制限について](https://developer.apple.com/documentation/swiftui/viewbuilder)
- [Core Data Best Practices](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [MVVM in SwiftUI](https://developer.apple.com/documentation/combine/receiving-and-handling-events-with-combine)
- [SwiftUI Gesture処理のベストプラクティス](https://developer.apple.com/documentation/swiftui/gestures)