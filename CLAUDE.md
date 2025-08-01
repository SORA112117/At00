# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Preference

Please communicate in Japanese.

## Mandatory Error Resolution Protocol

**CRITICAL RULE: Every error resolution MUST be logged in ERROR_RESOLUTION_LOG.md**

When any error occurs during development:
1. 📝 Document exact error message and context
2. 🔍 Analyze root cause thoroughly  
3. 🛠️ Record complete solution steps
4. 🛡️ Define prevention strategies
5. 📊 Update ERROR_RESOLUTION_LOG.md immediately

This protocol ensures knowledge accumulation and prevents recurring issues.

## Mandatory Progress Tracking Protocol

**CRITICAL RULE: Every development session MUST update PROJECT_PROGRESS.md**

When any development work is completed:
1. 📈 Document current implementation status
2. ✅ List completed features and components
3. 🔄 Update progress percentage and milestones
4. 🎯 Define next steps and priorities
5. 📋 Record any architectural decisions made
6. 📝 Update PROJECT_PROGRESS.md immediately

This protocol ensures clear visibility of project development status and facilitates continuation of work across sessions.

## Project Overview - University Attendance Management iOS App

大学生向けの授業欠席管理iOSアプリケーション

### Core Features
- **時間割管理**: 月〜金、1〜5限の時間割表示
- **ワンタップ欠席記録**: タップで即座に欠席を記録
- **視覚的ステータス**: 緑・オレンジ・赤での出席状況表示
- **詳細記録**: 欠席・遅刻・早退・公欠の種別とメモ
- **統計表示**: 出席率とグラフによる可視化
- **設定管理**: 学期・授業・通知の管理

### Architecture
- **Pattern**: MVVM with SwiftUI
- **Data**: Core Data for local persistence  
- **Structure**: Modularized into Models/Views/ViewModels/Services/Utils
- **Target**: iOS 15.0+

### Key Files
- `AttendanceViewModel.swift`: Main business logic
- `TimetableView.swift`: Primary UI interface
- `PersistenceController.swift`: Core Data management
- `AttendanceModel.xcdatamodeld`: Data model definitions
- `ERROR_RESOLUTION_LOG.md`: Troubleshooting knowledge base
- `PROJECT_PROGRESS.md`: Development progress tracking

### Development Commands
```bash
# Build for simulator
xcodebuild -scheme At00 -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build (when encountering cache issues)
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/At00-*

# Open in Xcode
open At00.xcodeproj
```

### Common Issues & Prevention
- Always import CoreData when using Core Data types
- Use public interfaces instead of accessing private ViewModel properties
- Separate complex SwiftUI expressions into simpler state variables
- Clean build after Core Data model changes
- Update ERROR_RESOLUTION_LOG.md for every resolved error
- Update PROJECT_PROGRESS.md after every development session

This project serves as both a functional app and a learning resource for iOS development best practices.