//
//  TournamentListView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md
//  INPUT: TournamentListViewModel 提供的赛事列表状态。
//  OUTPUT: 赛事主页（搜索、筛选、创建与进入管理）。
//  POS: 赛事 Tab 根页面。
//

import SwiftUI

struct TournamentListView: View {
    @StateObject private var viewModel: TournamentListViewModel
    private let store: AppStore

    @State private var navigationPath: [UUID] = []
    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var selectedFilter: TournamentFilter = .open

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TournamentListViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    AppTopBar(
                        title: "赛事",
                        style: .tournament,
                        showsLeadingIcon: false,
                        addAccessibilityTitle: "创建赛事",
                        addAccessibilityId: "tournament_add_button",
                        onAdd: { showCreateSheet = true }
                    )

                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.l) {
                            AppSearchBar(
                                text: $searchText,
                                placeholder: "输入赛事名称",
                                style: .standard
                            )

                            ScrollView(.horizontal) {
                                HStack(spacing: AppSpacing.s) {
                                    ForEach(TournamentFilter.allCases) { filter in
                                        TournamentFilterChip(
                                            title: filter.title,
                                            isSelected: filter == selectedFilter
                                        ) {
                                            selectedFilter = filter
                                        }
                                    }
                                }
                                .padding(.trailing, AppSpacing.s)
                            }
                            .scrollIndicators(.hidden)

                            if filteredCards.isEmpty {
                                AppCard {
                                    AppEmptyState(
                                        title: emptyTitle,
                                        subtitle: emptySubtitle,
                                        systemImage: "trophy"
                                    )
                                }
                            } else {
                                VStack(spacing: AppSpacing.m) {
                                    ForEach(filteredCards) { card in
                                        AppRowTapButton {
                                            navigationPath.append(card.id)
                                        } label: {
                                            TournamentListCard(card: card)
                                        }
                                    }
                                }

                                Text("共 \(filteredCards.count) 场")
                                    .font(AppFont.caption())
                                    .tracking(AppFont.tracking)
                                    .foregroundStyle(AppColor.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.horizontal, AppSpacing.inset)
                        .padding(.top, AppSpacing.l)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { tournamentId in
                TournamentDetailView(store: store, tournamentId: tournamentId)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appSheet(isPresented: $showCreateSheet) {
                CreateTournamentView { name, intro, status in
                    let tournament = viewModel.createTournament(name: name, intro: intro, status: status)
                    navigationPath.append(tournament.id)
                }
            }
        }
    }

    private var filteredCards: [TournamentListViewModel.TournamentCard] {
        viewModel.filteredCards(searchText: searchText, filter: selectedFilter)
    }

    private var emptyTitle: String {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? "暂无赛事" : "没有匹配赛事"
    }

    private var emptySubtitle: String {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return keyword.isEmpty ? "点击右上角创建第一场赛事" : "试试更短的关键词"
    }
}

#Preview {
    TournamentListView(store: AppStore())
}
