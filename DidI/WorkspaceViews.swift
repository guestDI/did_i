import SwiftUI
import WidgetKit
import DidICore

struct WorkspaceCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var store: Store
    @State private var name = ""
    @State private var showingSaveError = false
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canCreate: Bool {
        store.activeWorkspaces.count < Store.workspaceCap
            && Workspace.isNameAvailable(trimmed, among: store.workspaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Copy.nameFieldTitle, text: $name)
                        .focused($focused)
                        .onChange(of: name) { _, value in
                            if value.count > Workspace.maxNameLength {
                                name = String(value.prefix(Workspace.maxNameLength))
                            }
                        }
                        .onSubmit { create() }
                } footer: {
                    if store.activeWorkspaces.count >= Store.workspaceCap {
                        Text(Copy.Workspaces.cap).foregroundStyle(Palette.amber)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.ink)
            .navigationTitle(Copy.Workspaces.new)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Copy.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Copy.Workspaces.create) { create() }.disabled(!canCreate)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear { focused = true }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: { Text(Copy.saveFailedBody) }
    }

    private func create() {
        guard canCreate else { return }
        do {
            try StoreIO.mutate { _ = $0.createWorkspace(named: trimmed, at: .now) }
            store = try StoreIO.load()
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}

struct WorkspaceSettingsView: View {
    @Binding var store: Store
    @State private var creating = false
    @State private var renaming: Workspace?
    @State private var rename = ""
    @State private var showingSaveError = false

    var body: some View {
        List {
            Section {
                ForEach(store.activeWorkspaces) { workspace in
                    Button {
                        storeSelection(workspace.id)
                    } label: {
                        HStack {
                            Text(workspace.name).foregroundStyle(Palette.text)
                            Spacer()
                            if workspace.id == store.selectedWorkspaceID {
                                Image(systemName: "checkmark").foregroundStyle(Palette.amber)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if store.activeWorkspaces.count > 1 {
                            Button(Copy.Workspaces.archive) {
                                save { $0.archiveWorkspace(workspace.id, at: .now) }
                            }
                            .tint(Palette.amber)
                        }
                        Button(Copy.Workspaces.rename) {
                            rename = workspace.name
                            renaming = workspace
                        }
                        .tint(Palette.muted)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if store.activeWorkspaces.first?.id != workspace.id {
                            Button(Copy.moveUp) { save { $0.moveWorkspaceUp(workspace.id) } }
                                .tint(Palette.muted)
                        }
                    }
                }
                Button(Copy.Workspaces.new, systemImage: "plus") { creating = true }
                    .disabled(store.activeWorkspaces.count >= Store.workspaceCap)
            } footer: {
                Text(Copy.Workspaces.globalHomeFooter)
            }

            if !store.archivedWorkspaces.isEmpty {
                Section(Copy.Workspaces.archived) {
                    ForEach(store.archivedWorkspaces) { workspace in
                        Button {
                            save { $0.restoreWorkspace(workspace.id) }
                        } label: {
                            LabeledContent(workspace.name) { Text(Copy.Workspaces.restore) }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.ink)
        .navigationTitle(Copy.Workspaces.section)
        .sheet(isPresented: $creating) { WorkspaceCreateSheet(store: $store) }
        .alert(Copy.Workspaces.rename, isPresented: Binding(
            get: { renaming != nil }, set: { if !$0 { renaming = nil } }
        )) {
            TextField(Copy.nameFieldTitle, text: $rename)
            Button(Copy.cancel, role: .cancel) { renaming = nil }
            Button(Copy.done) { finishRename() }
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: { Text(Copy.saveFailedBody) }
    }

    private func finishRename() {
        guard let workspace = renaming else { return }
        let value = String(rename.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Workspace.maxNameLength))
        guard Workspace.isNameAvailable(value, among: store.workspaces, excluding: workspace.id) else { return }
        renaming = nil
        save { $0.renameWorkspace(workspace.id, to: value) }
    }

    private func storeSelection(_ id: UUID) {
        save { $0.selectWorkspace(id) }
    }

    private func save(_ mutation: (inout Store) -> Void) {
        do {
            try StoreIO.mutate(mutation)
            store = try StoreIO.load()
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.board)
        } catch {
            showingSaveError = true
        }
    }
}
