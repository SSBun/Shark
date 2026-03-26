//
//  ComponentSearchFilter.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onClear: () -> Void
    let onSearch: () -> Void
    
    @FocusState private var isFocused: Bool
    @StateObject private var keyboardManager = KeyboardManager.shared
    
    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onClear: @escaping () -> Void = {},
        onSearch: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onClear = onClear
        self.onSearch = onSearch
    }
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        onSearch()
                    }
                    .onChange(of: text) { _, _ in
                        keyboardManager.searchText = text
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onClear()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            
            if isFocused {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                    keyboardManager.blurSearch()
                }
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            }
        }
        .onAppear {
            if keyboardManager.isSearchFieldFocused {
                isFocused = true
            }
        }
    }
}

struct SearchableListView<Item: Identifiable & Hashable, Content: View>: View {
    let items: [Item]
    @Binding var selection: Item?
    let searchPlaceholder: String
    let filterOptions: [String]
    @Binding var selectedFilter: String?
    let onSearch: ((String) -> [Item])?
    let content: (Item, Bool) -> Content
    
    @State private var searchText: String = ""
    @State private var filteredItems: [Item] = []
    
    init(
        items: [Item],
        selection: Binding<Item?>,
        searchPlaceholder: String = "Search...",
        filterOptions: [String] = [],
        selectedFilter: Binding<String?> = .constant(nil),
        onSearch: ((String) -> [Item])? = nil,
        @ViewBuilder content: @escaping (Item, Bool) -> Content
    ) {
        self.items = items
        self._selection = selection
        self.searchPlaceholder = searchPlaceholder
        self.filterOptions = filterOptions
        self._selectedFilter = selectedFilter
        self.onSearch = onSearch
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                SearchBar(text: $searchText, placeholder: searchPlaceholder) {
                    filteredItems = items
                }
                
                if !filterOptions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(filterOptions, id: \.self) { filter in
                                FilterChip(
                                    title: filter,
                                    isSelected: selectedFilter == filter
                                ) {
                                    if selectedFilter == filter {
                                        selectedFilter = nil
                                    } else {
                                        selectedFilter = filter
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayItems) { item in
                            content(item, selection?.id == item.id)
                                .id(item.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selection = item
                                    }
                                }
                        }
                    }
                }
                .onChange(of: selection) { _, newSelection in
                    if let selected = newSelection {
                        withAnimation {
                            proxy.scrollTo(selected.id, anchor: .center)
                        }
                    }
                }
            }
            
            if displayItems.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private var displayItems: [Item] {
        if searchText.isEmpty {
            return items
        }
        
        if let onSearch = onSearch {
            return onSearch(searchText)
        }
        
        let lowercasedSearch = searchText.lowercased()
        return items.filter { item in
            if let item = item as? Workspace {
                return item.name.lowercased().contains(lowercasedSearch) ||
                       item.filePath.lowercased().contains(lowercasedSearch)
            }
            if let item = item as? Folder {
                return item.name.lowercased().contains(lowercasedSearch) ||
                       item.path.lowercased().contains(lowercasedSearch)
            }
            return true
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }
}

struct QuickOpenView: View {
    @Binding var isPresented: Bool
    let items: [QuickOpenItem]
    let onSelect: (QuickOpenItem) -> Void
    
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    var filteredItems: [QuickOpenItem] {
        if searchText.isEmpty {
            return Array(items.prefix(10))
        }
        let lowercased = searchText.lowercased()
        return Array(items.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.subtitle.lowercased().contains(lowercased)
        }.prefix(10))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search workspaces...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !filteredItems.isEmpty {
                            selectItem(filteredItems[selectedIndex])
                        }
                    }
                
                Button(action: { isPresented = false }) {
                    Text("Esc")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                        QuickOpenRow(item: item, isSelected: index == selectedIndex)
                            .onTapGesture {
                                selectItem(item)
                            }
                    }
                }
            }
            .frame(maxHeight: 300)
            
            if filteredItems.isEmpty {
                Text("No results found")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(width: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.2), radius: 20)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onChange(of: filteredItems.count) { _, newCount in
            if selectedIndex >= newCount {
                selectedIndex = max(0, newCount - 1)
            }
        }
    }
    
    private func selectItem(_ item: QuickOpenItem) {
        onSelect(item)
        isPresented = false
    }
}

struct QuickOpenRow: View {
    let item: QuickOpenItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundColor(item.iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct QuickOpenItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void
    
    static func == (lhs: QuickOpenItem, rhs: QuickOpenItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview("Search Bar") {
    VStack(spacing: 20) {
        SearchBar(text: .constant(""), placeholder: "Search workspaces...")
        SearchBar(text: .constant("My workspace"), placeholder: "Search workspaces...")
    }
    .padding()
    .frame(width: 400)
}

#Preview("Filter Chips") {
    HStack {
        FilterChip(title: "All", isSelected: true) {}
        FilterChip(title: "Recent", isSelected: false) {}
        FilterChip(title: "Favorites", isSelected: false) {}
    }
    .padding()
}

#Preview("Quick Open") {
    QuickOpenView(
        isPresented: .constant(true),
        items: [
            QuickOpenItem(id: "1", title: "My Workspace", subtitle: "/path/to/workspace", icon: "folder.fill", iconColor: .blue, action: {}),
            QuickOpenItem(id: "2", title: "Another Workspace", subtitle: "/path/to/another", icon: "folder.fill", iconColor: .green, action: {}),
        ],
        onSelect: { _ in }
    )
    .padding()
}
