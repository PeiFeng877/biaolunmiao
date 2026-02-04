//
//  TournamentListView.swift
//  BianLunMiao
//
//  [PROTOCOL]: 变更时更新此头部，然后检查 AGENTS.md
//  INPUT: TournamentListViewModel 提供的赛事瀑布流卡片。
//  OUTPUT: Clubhouse 风格赛事主页。
//  POS: 赛事 Tab 根页面。
//

import SwiftUI

struct TournamentListView: View {
    @StateObject private var viewModel: TournamentListViewModel
    private let store: AppStore
    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var selectedFilter: TournamentFilter = .hot

    private let filters: [TournamentFilter] = [.hot, .open, .upcoming, .campus, .regional]

    init(store: AppStore) {
        self.store = store
        _viewModel = StateObject(wrappedValue: TournamentListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.eventBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TournamentTopBar(
                        onAdd: { showCreateSheet = true }
                    )

                    ScrollView {
                        VStack(spacing: AppSpacing.l) {
                            TournamentSearchBar(text: $searchText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.s) {
                                    ForEach(filters) { filter in
                                        TournamentFilterChip(
                                            title: filter.title,
                                            isSelected: filter == selectedFilter
                                        ) {
                                            selectedFilter = filter
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.l)
                            }

                            if let featured = featuredCard {
                                TournamentFeaturedCard(card: featured)
                            }

                            VStack(spacing: AppSpacing.l) {
                                ForEach(listCards) { card in
                                    NavigationLink {
                                        TournamentDetailView(store: store, card: card)
                                    } label: {
                                        TournamentListCard(card: card)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, AppSpacing.s)
                        }
                        .padding(.top, AppSpacing.m)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreateSheet) {
                CreateTournamentView { name, intro in
                    viewModel.createTournament(name: name, intro: intro)
                }
            }
        }
    }
}

private extension TournamentListView {
    var featuredCard: TournamentListViewModel.TournamentCard? {
        viewModel.cards.first(where: { $0.isFeatured }) ?? viewModel.cards.first
    }

    var listCards: [TournamentListViewModel.TournamentCard] {
        guard let featuredId = featuredCard?.id else { return viewModel.cards }
        return viewModel.cards.filter { $0.id != featuredId }
    }
}

#Preview {
    TournamentListView(store: AppStore())
}
