# At00 - 大学生向け授業欠席管理アプリ 詳細仕様書

## 目次
1. [アプリ概要](#アプリ概要)
2. [アーキテクチャと設計思想](#アーキテクチャと設計思想)
3. [ディレクトリ構成](#ディレクトリ構成)
4. [データモデル（Core Data）](#データモデルcore-data)
5. [主要コンポーネント詳細](#主要コンポーネント詳細)
6. [重要な機能と実装](#重要な機能と実装)
7. [初心者向けSwift解説](#初心者向けswift解説)

---

## アプリ概要

### アプリの目的
大学生が授業の欠席状況を効率的に管理し、単位取得に必要な出席率を維持するためのiOSアプリケーションです。

### 主要機能
- **時間割表示**: 月〜金、1〜5限の時間割をグリッド形式で表示
- **ワンタップ欠席記録**: セルをタップするだけで欠席を記録
- **視覚的ステータス表示**: 緑・オレンジ・赤のカラーボックスで出席状況を可視化
- **学期管理**: 前期・後期の時間割を別々に管理
- **通年科目サポート**: 通年科目の場合、前期・後期両方に自動配置
- **統計表示**: 出席率とグラフによる詳細な統計情報
- **設定管理**: 時限時間、通知設定等のカスタマイズ

### 技術スタック
- **言語**: Swift 5.0+
- **フレームワーク**: SwiftUI（UIフレームワーク）
- **データ管理**: Core Data（永続化）
- **アーキテクチャ**: MVVM (Model-View-ViewModel)
- **対象OS**: iOS 15.0+

---

## アーキテクチャと設計思想

### MVVM パターンの採用

```swift
// At00App.swift - アプリのエントリーポイント
@main
struct At00App: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var attendanceViewModel = AttendanceViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(attendanceViewModel)
        }
    }
}
```

**初心者向け解説:**
- `@main`: このアプリの開始点を示すSwiftの属性
- `@StateObject`: アプリ全体で共有されるViewModelのインスタンスを作成
- `.environment()` と `.environmentObject()`: 子ビューにデータを渡すSwiftUIの仕組み

### 設計思想
1. **単一責任の原則**: 各クラスは1つの明確な責任を持つ
2. **データの流れの明確化**: View → ViewModel → Model の一方向データフロー
3. **状態管理の集中化**: AttendanceViewModelで全ての状態を管理
4. **コンポーネント分割**: 再利用可能な小さなViewコンポーネントに分割

---

## ディレクトリ構成

```
At00/
├── At00App.swift                    # アプリエントリーポイント
├── AttendanceModel.xcdatamodeld/    # Core Dataモデル定義
├── Models/                          # データモデル
│   ├── AttendanceType.swift         # 出席記録種別（欠席、遅刻等）
│   └── SemesterType.swift           # 学期種別（前期、後期）
├── Services/                        # サービス層
│   ├── NotificationManager.swift    # 通知管理
│   └── PersistenceController.swift  # Core Data制御
├── ViewModels/                      # ビジネスロジック
│   └── AttendanceViewModel.swift    # メインビューモデル
├── Views/                           # UI層
│   ├── MainTabView.swift            # メインタブコンテナ
│   ├── TimetableView.swift          # 時間割表示
│   ├── CourseSelectionView.swift    # 授業選択画面
│   ├── EditCourseDetailView.swift   # 授業編集画面
│   ├── EnhancedStatisticsView.swift # 統計表示
│   ├── SettingsView.swift           # 設定画面
│   └── Components/                  # 再利用可能コンポーネント
│       └── ColorBlockGrid.swift    # カラーブロック表示
└── Utils/                           # ユーティリティ
    ├── DesignSystem.swift           # デザインシステム
    ├── CommonStyles.swift           # 共通スタイル
    └── JapaneseHolidays.swift       # 祝日管理
```

**各フォルダの役割:**
- **Models**: データの構造と振る舞いを定義
- **Views**: ユーザーに表示されるUI要素
- **ViewModels**: UIとデータを繋ぐロジック
- **Services**: 外部サービス（通知、データベース）との連携
- **Utils**: アプリ全体で使用される共通機能

---

## データモデル（Core Data）

### Core Dataとは
Core DataはAppleが提供するデータ永続化フレームワークです。SQLiteをベースとしながら、オブジェクト指向的にデータを扱えます。

### エンティティ関係図

```
Semester (学期)
├── semesterId: UUID (主キー)
├── name: String (学期名)
├── semesterType: String (前期/後期)
├── startDate/endDate: Date (期間)
└── courses: [Course] (関連授業)

Course (授業)
├── courseId: UUID (主キー)
├── courseName: String (授業名)
├── dayOfWeek: Int16 (曜日 1=月〜5=金)
├── period: Int16 (時限 1〜5)
├── totalClasses: Int16 (総授業回数)
├── maxAbsences: Int16 (最大欠席可能回数)
├── isFullYear: Bool (通年科目フラグ)
├── colorIndex: Int16 (表示色インデックス)
├── semester: Semester (所属学期)
└── attendanceRecords: [AttendanceRecord] (出席記録)

AttendanceRecord (出席記録)
├── recordId: UUID (主キー)
├── date: Date (記録日)
├── type: String (記録種別)
├── memo: String (メモ)
├── createdAt: Date (作成日時)
└── course: Course (対象授業)

PeriodTime (時限時間)
├── period: Int16 (時限番号)
├── startTime/endTime: Date (開始/終了時間)
└── semesterId: UUID (所属学期ID)
```

### 実装例

```swift
// AttendanceType.swift - 出席記録の種別を定義するenum
enum AttendanceType: String, CaseIterable {
    case absent = "absent"              // 欠席
    case late = "late"                  // 遅刻  
    case earlyLeave = "early_leave"     // 早退
    case officialAbsent = "official_absent" // 公欠
    
    var displayName: String {
        switch self {
        case .absent: return "欠席"
        case .late: return "遅刻"
        case .earlyLeave: return "早退"
        case .officialAbsent: return "公欠"
        }
    }
    
    // 単位に影響するかどうか（欠席のみカウント）
    var affectsCredit: Bool {
        switch self {
        case .absent: return true
        case .late, .earlyLeave, .officialAbsent: return false
        }
    }
}
```

**初心者向け解説:**
- `enum`: 固定された選択肢を定義するSwiftの機能
- `String` rawValue: 文字列として保存される値
- `CaseIterable`: 全ケースを配列として取得可能にする
- `switch文`: 各ケースに応じた処理を分岐

---

## 主要コンポーネント詳細

### 1. AttendanceViewModel - 中核ビジネスロジック

AttendanceViewModelはアプリの中心的なビジネスロジックを担当します。

```swift
class AttendanceViewModel: ObservableObject {
    // MARK: - Published Properties (UIが監視する状態)
    @Published var timetable: [[Course?]] = Array(repeating: Array(repeating: nil, count: 5), count: 5)
    @Published var currentSemester: Semester?
    @Published var availableSemesters: [Semester] = []
    @Published var isInitialized = false
    
    // Core Dataコンテキスト
    var managedObjectContext: NSManagedObjectContext
    
    // MARK: - 主要メソッド
    
    // 欠席記録の作成
    func recordAbsence(for course: Course, type: AttendanceType = .absent, 
                      memo: String = "", date: Date = Date()) -> RecordResult {
        
        // 1. 重複チェック
        if hasRecordForDate(course: course, date: date) {
            return .alreadyRecorded
        }
        
        // 2. 1日制限チェック  
        if getRecordCountForSameDay(courseName: course.courseName ?? "", date: date) >= 5 {
            return .dailyLimitReached
        }
        
        // 3. 新しい記録を作成
        let record = AttendanceRecord(context: managedObjectContext)
        record.recordId = UUID()
        record.date = date
        record.type = type.rawValue
        record.memo = memo
        record.course = course
        record.createdAt = Date()
        
        // 4. 通年科目の場合、ペア学期にも記録
        if course.isFullYear {
            createPairSemesterRecord(course: course, date: date, type: type, memo: memo)
        }
        
        // 5. 保存
        save()
        
        // 6. 通知処理
        checkAndSendAbsenceLimitNotification(for: course, 
                                           newAbsenceCount: getAbsenceCount(for: course))
        
        return .success
    }
}
```

**初心者向け解説:**
- `@Published`: この値が変更されるとUIが自動更新される
- `ObservableObject`: ViewModelがUIに変更を通知できるようにする
- `NSManagedObjectContext`: Core Dataでデータを操作するためのインターface
- `enum RecordResult`: 処理結果を表現する列挙型

### 2. TimetableView - メイン時間割画面

```swift
struct TimetableView: View {
    @EnvironmentObject private var viewModel: AttendanceViewModel
    @State private var selectedCourse: Course?
    @State private var showingAddCourse = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    semesterInfoView
                    timetableGridView(geometry: geometry)
                    Spacer()
                }
            }
            .navigationTitle("授業欠席管理")
            .toolbar {
                // 学期選択メニュー
                ToolbarItem(placement: .navigationBarLeading) {
                    semesterSelectionMenu
                }
            }
            .sheet(isPresented: $showingAddCourse) {
                // 授業追加画面のシート表示
                if let timeSlot = selectedTimeSlot {
                    NavigationView {
                        CourseSelectionView(
                            dayOfWeek: timeSlot.day,
                            period: timeSlot.period,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
    }
    
    // 時間割セルの処理
    private func handleCourseTap(_ course: Course) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            let result = viewModel.recordAbsence(for: course)
            
            switch result {
            case .success:
                // 成功時のフィードバック
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
            case .alreadyRecorded:
                // 重複記録時のアラート表示
                showingDuplicateAlert = true
                
            case .dailyLimitReached:
                // 制限到達時のアラート表示
                showingDailyLimitAlert = true
            }
        }
    }
}
```

**初心者向け解説:**
- `@EnvironmentObject`: 親から渡されたViewModelを取得
- `@State`: そのView内だけで使用される状態
- `GeometryReader`: 画面サイズに応じたレイアウト調整
- `.sheet()`: モーダル画面の表示制御
- `withAnimation()`: アニメーション付きの状態変更

### 3. EnhancedCourseCell - 時間割セルコンポーネント

```swift
struct EnhancedCourseCell: View {
    let course: Course?
    let absenceCount: Int
    let statusColor: Color
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var showingCountAnimation = false
    
    var body: some View {
        Button(action: {}) {
            VStack(spacing: 0) {
                if let course = course {
                    // 授業名表示（6文字まで2行）
                    Text(limitCourseName(course.courseName ?? ""))
                        .font(.system(size: 9, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    // 欠席数の大きな表示
                    Text("\(absenceCount)")
                        .font(.system(size: 22, weight: .bold))
                        .scaleEffect(showingCountAnimation ? 1.1 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), 
                                 value: showingCountAnimation)
                        .onChange(of: absenceCount) { oldValue, newValue in
                            if newValue > oldValue {
                                // カウント増加時のエフェクト
                                showingCountAnimation = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    showingCountAnimation = false
                                }
                            }
                        }
                    
                    // カラーボックスグリッド表示
                    createColorBoxGrid(course: course, 
                                     absenceCount: absenceCount, 
                                     cellWidth: cellWidth)
                }
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { onTap() }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8)
                .onEnded { _ in onLongPress() }
        )
    }
}
```

**初心者向け解説:**
- `@State private var`: そのコンポーネント内だけの状態管理
- `.onChange()`: 値の変更を監視してアクションを実行
- `.simultaneousGesture()`: 複数のジェスチャーを同時に処理
- `DispatchQueue.main.asyncAfter()`: 遅延実行の仕組み

---

## 重要な機能と実装

### 1. 通年科目の自動同期

通年科目は前期・後期両方の学期に同じ授業を配置し、欠席記録も同期します。

```swift
// AttendanceViewModel.swift
private func createPairSemesterRecord(course: Course, date: Date, 
                                    type: AttendanceType, memo: String) {
    guard course.isFullYear,
          let courseName = course.courseName,
          let currentSemester = currentSemester else { return }
    
    // 現在の学期タイプを判定
    let currentType = SemesterType(rawValue: currentSemester.semesterType ?? "") ?? .firstHalf
    let otherType: SemesterType = (currentType == .firstHalf) ? .secondHalf : .firstHalf
    
    // ペア学期を取得
    guard let otherSemester = availableSemesters.first(where: { 
        $0.semesterType == otherType.rawValue 
    }) else { return }
    
    // ペア学期の同名授業を検索
    let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
    courseRequest.predicate = NSPredicate(
        format: "courseName == %@ AND semester == %@ AND dayOfWeek == %@ AND period == %@",
        courseName, otherSemester, course.dayOfWeek, course.period
    )
    
    do {
        let pairCourses = try managedObjectContext.fetch(courseRequest)
        
        for pairCourse in pairCourses {
            // ペア授業にも同じ記録を作成
            let pairRecord = AttendanceRecord(context: managedObjectContext)
            pairRecord.recordId = UUID()
            pairRecord.date = date
            pairRecord.type = type.rawValue
            pairRecord.memo = memo + " (通年同期)"
            pairRecord.course = pairCourse
            pairRecord.createdAt = Date()
        }
    } catch {
        print("ペア学期記録作成エラー: \(error)")
    }
}
```

### 2. 視覚的ステータス表示システム

欠席状況を色分けで直感的に表示します。

```swift
// AttendanceViewModel.swift
func getStatusColor(for course: Course) -> Color {
    let absenceCount = getAbsenceCount(for: course)
    let maxAbsences = Int(course.maxAbsences)
    
    if absenceCount == 0 {
        return Color(red: 0.4, green: 0.8, blue: 0.4) // 優秀な緑
    } else if absenceCount >= maxAbsences {
        return .red // 危険な赤
    } else if absenceCount == maxAbsences - 1 {
        return .orange // 警告のオレンジ
    } else {
        return Color(red: 0.4, green: 0.8, blue: 0.4) // 安全な緑
    }
}

// カラーボックスの色決定ロジック
private func getColorBoxColor(course: Course, index: Int, absenceCount: Int) -> Color {
    let maxAbsences = Int(course.maxAbsences)
    
    if index < absenceCount {
        // 欠席した回数分を色付け
        if absenceCount >= maxAbsences {
            return .red // 限界到達
        } else if absenceCount == maxAbsences - 1 {
            return .orange // 危険圏
        } else {
            return Color(red: 0.4, green: 0.8, blue: 0.4) // 安全圏
        }
    } else {
        // 未欠席部分は薄い灰色
        return Color.gray.opacity(0.3)
    }
}
```

### 3. リアルタイムデータ更新システム

NotificationCenterを使用してデータ変更をリアルタイムで各画面に通知します。

```swift
// NotificationCenter拡張
extension Notification.Name {
    static let courseDataDidChange = Notification.Name("courseDataDidChange")
    static let attendanceDataDidChange = Notification.Name("attendanceDataDidChange")
    static let statisticsDataDidChange = Notification.Name("statisticsDataDidChange")
}

// TimetableViewでの監視
.onReceive(NotificationCenter.default.publisher(for: .courseDataDidChange)) { _ in
    DispatchQueue.main.async {
        viewModel.loadTimetable()
        viewModel.objectWillChange.send()
    }
}
.onReceive(NotificationCenter.default.publisher(for: .attendanceDataDidChange)) { _ in
    DispatchQueue.main.async {
        viewModel.objectWillChange.send()
    }
}

// データ更新時の通知送信
func saveChanges() {
    // ... データ保存処理 ...
    
    // 変更通知を送信
    NotificationCenter.default.post(name: .courseDataDidChange, object: nil)
    NotificationCenter.default.post(name: .statisticsDataDidChange, object: nil)
    NotificationCenter.default.post(name: .attendanceDataDidChange, object: nil)
}
```

### 4. パフォーマンス最適化

N+1クエリ問題を解決し、効率的なデータ取得を実装しています。

```swift
// AttendanceViewModel.swift
func loadAllAbsenceCounts() {
    guard let semester = currentSemester else { return }
    
    // 1回のクエリでそのシーズンの全授業を取得
    let courseRequest: NSFetchRequest<Course> = Course.fetchRequest()
    courseRequest.predicate = NSPredicate(format: "semester == %@", semester)
    
    do {
        let courses = try managedObjectContext.fetch(courseRequest)
        let courseNames = courses.compactMap { $0.courseName }
        
        // 1回のクエリで全授業の欠席記録を取得
        let recordRequest: NSFetchRequest<AttendanceRecord> = AttendanceRecord.fetchRequest()
        recordRequest.predicate = NSPredicate(
            format: "course.courseName IN %@ AND type == %@",
            courseNames, AttendanceType.absent.rawValue
        )
        
        let records = try managedObjectContext.fetch(recordRequest)
        
        // メモリ内でカウントを計算
        var counts: [String: Int] = [:]
        for record in records {
            if let courseName = record.course?.courseName {
                counts[courseName, default: 0] += 1
            }
        }
        
        // キャッシュに保存
        self.absenceCountCache = counts
        
    } catch {
        print("欠席数読み込みエラー: \(error)")
    }
}
```

---

## 初心者向けSwift解説

### 1. `@Published` と `@State` の違い

```swift
// ViewModel内: 複数のViewで共有される状態
class AttendanceViewModel: ObservableObject {
    @Published var currentSemester: Semester? // 全画面で共有
}

// View内: そのViewでのみ使用される状態  
struct TimetableView: View {
    @State private var showingAddCourse = false // このViewのみ
}
```

**使い分け:**
- `@Published`: ViewModelで、複数の画面で共有したいデータ
- `@State`: 特定のView内でのみ使用する一時的な状態

### 2. Optional（オプショナル）の扱い

```swift
// Optionalの安全な取り扱い
func getCourse() -> Course? {
    // nilの可能性がある値を返す
}

// guard let文での安全な展開
guard let course = getCourse() else {
    print("コースが取得できません")
    return
}
// ここでcourseは確実にnilではない

// if let文での条件付き展開
if let courseName = course.courseName {
    print("授業名: \(courseName)")
} else {
    print("授業名が設定されていません")
}
```

### 3. Core Dataの基本操作

```swift
// 新しいデータの作成
let newCourse = Course(context: managedObjectContext)
newCourse.courseName = "プログラミング"
newCourse.dayOfWeek = 1
newCourse.period = 1

// データの検索
let request: NSFetchRequest<Course> = Course.fetchRequest()
request.predicate = NSPredicate(format: "courseName == %@", "プログラミング")
let courses = try? managedObjectContext.fetch(request)

// データの保存
try? managedObjectContext.save()

// データの削除
managedObjectContext.delete(course)
try? managedObjectContext.save()
```

### 4. SwiftUIのライフサイクル

```swift
struct SampleView: View {
    var body: some View {
        Text("Hello")
            .onAppear {
                // Viewが表示された時に実行
                print("画面が表示されました")
            }
            .onChange(of: someValue) { oldValue, newValue in
                // someValueが変更された時に実行
                print("値が\(oldValue)から\(newValue)に変更されました")
            }
            .onDisappear {
                // Viewが非表示になった時に実行
                print("画面が非表示になりました")
            }
    }
}
```

### 5. エラーハンドリング

```swift
// do-catch文でのエラー処理
do {
    let courses = try managedObjectContext.fetch(request)
    print("データ取得成功: \(courses.count)件")
} catch {
    print("データ取得エラー: \(error.localizedDescription)")
}

// Result型でのエラー処理
enum RecordResult {
    case success
    case alreadyRecorded
    case dailyLimitReached
}

func recordAbsence() -> RecordResult {
    // 処理...
    if error {
        return .alreadyRecorded
    }
    return .success
}
```

---

## まとめ

このアプリは以下の技術的特徴を持っています：

1. **MVVM アーキテクチャ**: 責任の分離と保守性の向上
2. **Core Data**: 効率的なローカルデータ管理
3. **SwiftUI**: 宣言的UIとリアクティブプログラミング
4. **パフォーマンス最適化**: N+1クエリ問題の回避とキャッシング
5. **リアルタイム更新**: NotificationCenterによるデータ同期
6. **ユーザビリティ**: 直感的な操作とビジュアルフィードバック

これらの技術を組み合わせることで、大学生の出席管理という実用的な問題を解決する、保守性が高く拡張可能なアプリケーションを実現しています。