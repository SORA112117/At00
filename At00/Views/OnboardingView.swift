//
//  OnboardingView.swift
//  At00
//
//  初回起動時のオンボーディング画面
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages = [
        OnboardingPage(
            imageName: "calendar.badge.clock",
            title: "At00へようこそ",
            subtitle: "大学生向け授業欠席管理アプリ",
            description: "授業の出席状況を簡単に管理し、欠席回数を把握して単位取得をサポートします。"
        ),
        OnboardingPage(
            imageName: "grid.3x3",
            title: "時間割を作成",
            subtitle: "簡単セットアップ",
            description: "月〜金の1〜5限までの時間割を作成し、履修している授業を登録しましょう。"
        ),
        OnboardingPage(
            imageName: "minus.circle.fill",
            title: "ワンタップで記録",
            subtitle: "シンプルな操作",
            description: "授業をタップするだけで欠席を記録。色分けで出席状況が一目でわかります。"
        ),
        OnboardingPage(
            imageName: "chart.bar.fill",
            title: "統計で確認",
            subtitle: "安心の管理",
            description: "出席率をグラフで確認し、欠席回数の上限に近づいたら通知でお知らせします。"
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [
                    Color(.systemBlue).opacity(0.1),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ページインジケーター
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == currentPage ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 20)
                
                // ページコンテンツ
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // ボタンエリア
                VStack(spacing: 16) {
                    if currentPage < pages.count - 1 {
                        // 次へボタン
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }) {
                            Text("次へ")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .accessibilityLabel("次のページへ進む")
                        .accessibilityHint("\(currentPage + 1)番目の説明ページに進みます")
                        
                        // スキップボタン
                        Button(action: {
                            completeOnboarding()
                        }) {
                            Text("スキップ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .accessibilityLabel("オンボーディングをスキップ")
                        .accessibilityHint("説明をスキップしてアプリを開始します")
                    } else {
                        // 開始ボタン
                        Button(action: {
                            completeOnboarding()
                        }) {
                            Text("はじめる")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .accessibilityLabel("アプリを開始")
                        .accessibilityHint("At00アプリの使用を開始します")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            isPresented = false
        }
    }
}

struct OnboardingPage {
    let imageName: String
    let title: String
    let subtitle: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // アイコン
            Image(systemName: page.imageName)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(.blue)
                .padding(.bottom, 20)
            
            // テキストコンテンツ
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                Text(page.subtitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}