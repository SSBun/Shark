//
//  KeyboardManager.swift
//  Shark
//
//  Created by AI Assistant on 2026/03/26.
//

import SwiftUI

enum KeyboardShortcut: String, CaseIterable {
    case newWorkspace = "New Workspace"
    case openWorkspace = "Open Workspace"
    case search = "Search"
    case delete = "Delete"
    case rename = "Rename"
    case refresh = "Refresh"
    case settings = "Settings"
    case close = "Close"
    case addFolder = "Add Folder"
    case openInTerminal = "Open in Terminal"
    case openInCursor = "Open in Cursor"
    case openInFork = "Open in Fork"
    case openInSourceTree = "Open in SourceTree"
    case showInFinder = "Show in Finder"
    case selectAll = "Select All"
    case escape = "Cancel/Close"
    
    var defaultKeyCode: UInt16 {
        switch self {
        case .newWorkspace: return 6
        case .openWorkspace: return 13
        case .search: return 3
        case .delete: return 51
        case .rename: return 36
        case .refresh: return 15
        case .settings: return 53
        case .close: return 53
        case .addFolder: return 22
        case .openInTerminal: return 17
        case .openInCursor: return 3
        case .openInFork: return 3
        case .openInSourceTree: return 3
        case .showInFinder: return 3
        case .selectAll: return 0
        case .escape: return 53
        }
    }
    
    var modifiers: NSEvent.ModifierFlags {
        switch self {
        case .newWorkspace: return .command
        case .openWorkspace: return .command
        case .search: return .command
        case .delete: return .command
        case .rename: return []
        case .refresh: return .command
        case .settings: return .command
        case .close: return []
        case .addFolder: return [.command, .shift]
        case .openInTerminal: return [.command, .shift]
        case .openInCursor: return [.command, .shift]
        case .openInFork: return [.command, .shift]
        case .openInSourceTree: return [.command, .shift]
        case .showInFinder: return [.command, .shift]
        case .selectAll: return .command
        case .escape: return []
        }
    }
    
    var displayShortcut: String {
        switch self {
        case .newWorkspace: return "⌘N"
        case .openWorkspace: return "⌘O"
        case .search: return "⌘F"
        case .delete: return "⌘⌫"
        case .rename: return "↩"
        case .refresh: return "⌘R"
        case .settings: return "⌘,"
        case .close: return "Esc"
        case .addFolder: return "⌘⇧N"
        case .openInTerminal: return "⌘⇧T"
        case .openInCursor: return "⌘⇧O"
        case .openInFork: return "⌘⇧F"
        case .openInSourceTree: return "⌘⇧S"
        case .showInFinder: return "⌘⇧R"
        case .selectAll: return "⌘A"
        case .escape: return "Esc"
        }
    }
}

@MainActor
final class KeyboardManager: ObservableObject {
    static let shared = KeyboardManager()
    
    @Published var isSearchFieldFocused: Bool = false
    @Published var searchText: String = ""
    @Published var isShowingSearch: Bool = false
    
    private var focusRect: CGRect = .zero
    
    private init() {}
    
    func focusSearch() {
        isShowingSearch = true
        isSearchFieldFocused = true
    }
    
    func blurSearch() {
        isSearchFieldFocused = false
        searchText = ""
    }
    
    func toggleSearch() {
        if isShowingSearch && isSearchFieldFocused {
            blurSearch()
            isShowingSearch = false
        } else {
            focusSearch()
        }
    }
}

struct KeyboardShortcutModifier: ViewModifier {
    let shortcut: KeyboardShortcut
    let action: () -> Void
    
    @StateObject private var keyboardManager = KeyboardManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(
                KeyboardShortcutHandler(shortcut: shortcut, action: action)
            )
    }
}

struct KeyboardShortcutHandler: NSViewRepresentable {
    let shortcut: KeyboardShortcut
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyEventView()
        view.onKeyDown = { event in
            if matchesEvent(event) {
                action()
                return true
            }
            return false
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    private func matchesEvent(_ event: NSEvent) -> Bool {
        if event.type != .keyDown { return false }
        
        let modifiers = event.modifierFlags.intersection(.command.union(.shift).union(.option).union(.control))
        let expectedModifiers = shortcut.modifiers.intersection(.command.union(.shift).union(.option).union(.control))
        
        return event.keyCode == shortcut.defaultKeyCode && modifiers == expectedModifiers
    }
}

class KeyEventView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        if !(onKeyDown?(event) ?? false) {
            super.keyDown(with: event)
        }
    }
}

struct FocusableModifier: ViewModifier {
    let tag: Int
    @Binding var focusedTag: Int?
    
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    focusedTag = tag
                }
            }
            .onTapGesture {
                focusedTag = tag
            }
    }
}

extension View {
    func keyboardShortcut(_ shortcut: KeyboardShortcut, action: @escaping () -> Void) -> some View {
        modifier(KeyboardShortcutModifier(shortcut: shortcut, action: action))
    }
    
    func focusable(tag: Int, focusedTag: Binding<Int?>) -> some View {
        modifier(FocusableModifier(tag: tag, focusedTag: focusedTag))
    }
}

struct KeyboardNavigationList<Item: Identifiable & Hashable>: View {
    let data: [Item]
    @Binding var selection: Item?
    let onSelect: (Item) -> Void
    let onDelete: ((Item) -> Void)?
    let onOpen: ((Item) -> Void)?
    let content: (Item, Bool) -> AnyView
    
    init(
        data: [Item],
        selection: Binding<Item?>,
        onSelect: @escaping (Item) -> Void,
        onDelete: ((Item) -> Void)? = nil,
        onOpen: ((Item) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item, Bool) -> some View
    ) {
        self.data = data
        self._selection = selection
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onOpen = onOpen
        self.content = { item, isSelected in AnyView(content(item, isSelected)) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(data) { item in
                content(item, selection?.id == item.id)
                    .onTapGesture {
                        onSelect(item)
                    }
            }
        }
        .onKeyPress(.upArrow) {
            moveSelection(direction: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(direction: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if let sel = selection {
                onOpen?(sel)
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if let sel = selection {
                onDelete?(sel)
            }
            return .handled
        }
    }
    
    private func moveSelection(direction: Int) {
        guard !data.isEmpty else { return }
        
        let currentIndex: Int
        if let selection = selection,
           let index = data.firstIndex(where: { $0.id == selection.id }) {
            currentIndex = index
        } else {
            currentIndex = -1
        }
        
        var newIndex = currentIndex + direction
        if newIndex < 0 { newIndex = data.count - 1 }
        if newIndex >= data.count { newIndex = 0 }
        
        let newSelection = data[newIndex]
        onSelect(newSelection)
    }
}

extension View {
    func handleKeyEvents(
        onUpArrow: @escaping () -> Void,
        onDownArrow: @escaping () -> Void,
        onReturn: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onEscape: @escaping () -> Void
    ) -> some View {
        self
            .onKeyPress(.upArrow) { onUpArrow(); return .handled }
            .onKeyPress(.downArrow) { onDownArrow(); return .handled }
            .onKeyPress(.return) { onReturn(); return .handled }
            .onKeyPress(.delete) { onDelete(); return .handled }
            .onKeyPress(.escape) { onEscape(); return .handled }
    }
}
