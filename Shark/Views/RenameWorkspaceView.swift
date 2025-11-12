//
//  RenameWorkspaceView.swift
//  Shark
//
//  Created by caishilin on 2025/11/12.
//

import SwiftUI

struct RenameWorkspaceView: View {
    @Binding var isPresented: Bool
    @State private var newName: String
    let currentName: String
    let onRename: (String) -> Void
    
    init(isPresented: Binding<Bool>, currentName: String, onRename: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.currentName = currentName
        self.onRename = onRename
        self._newName = State(initialValue: currentName)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Workspace")
                .font(.headline)
            
            TextField("Workspace name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    rename()
                }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Rename") {
                    rename()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(newName.isEmpty || newName == currentName)
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear {
            newName = currentName
        }
    }
    
    private func rename() {
        guard !newName.isEmpty && newName != currentName else {
            return
        }
        onRename(newName)
        isPresented = false
    }
}

#Preview {
    @Previewable @State var isPresented = true
    
    RenameWorkspaceView(
        isPresented: $isPresented,
        currentName: "My Workspace"
    ) { newName in
        print("Renamed to: \(newName)")
    }
}

