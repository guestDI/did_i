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
                    } else if !trimmed.isEmpty && !Workspace.isNameAvailable(trimmed, among: store.workspaces) {
                        Text(Copy.Workspaces.nameAlreadyUsed).foregroundStyle(Palette.amber)
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
    @State private var workspaceError: String?

    private var renameIsValid: Bool {
        guard let renaming else { return false }
        return Workspace.isNameAvailable(rename, among: store.workspaces, excluding: renaming.id)
    }

    var body: some View {
        List {
            Section {
                ForEach(store.activeWorkspaces) { workspace in
                    HStack(spacing: 8) {
                        Button { storeSelection(workspace.id) } label: {
                            Text(workspace.name).foregroundStyle(Palette.text)
                            Spacer()
                            if workspace.id == store.selectedWorkspaceID {
                                Image(systemName: "checkmark").foregroundStyle(Palette.amber)
                            }
                        }
                        .buttonStyle(.plain)
                        Menu {
                            if workspace.id != store.selectedWorkspaceID {
                                Button(Copy.Workspaces.select, systemImage: "checkmark") {
                                    storeSelection(workspace.id)
                                }
                            }
                            Button(Copy.Workspaces.rename, systemImage: "pencil") {
                                beginRename(workspace)
                            }
                            if store.activeWorkspaces.first?.id != workspace.id {
                                Button(Copy.moveUp, systemImage: "arrow.up") {
                                    save { $0.moveWorkspaceUp(workspace.id) }
                                }
                            }
                            if store.activeWorkspaces.count > 1 {
                                Button(Copy.Workspaces.archive, systemImage: "archivebox") {
                                    save { $0.archiveWorkspace(workspace.id, at: .now) }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Copy.moreActions)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if store.activeWorkspaces.count > 1 {
                            Button(Copy.Workspaces.archive) {
                                save { $0.archiveWorkspace(workspace.id, at: .now) }
                            }
                            .tint(Palette.amber)
                        }
                        Button(Copy.Workspaces.rename) {
                            beginRename(workspace)
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(Copy.Workspaces.globalHomeFooter)
                    if store.activeWorkspaces.count >= Store.workspaceCap {
                        Text(Copy.Workspaces.cap).foregroundStyle(Palette.amber)
                    }
                }
            }

            if !store.archivedWorkspaces.isEmpty {
                Section(Copy.Workspaces.archived) {
                    ForEach(store.archivedWorkspaces) { workspace in
                        Button {
                            restore(workspace)
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
                .onChange(of: rename) { _, value in
                    if value.count > Workspace.maxNameLength {
                        rename = String(value.prefix(Workspace.maxNameLength))
                    }
                }
            Button(Copy.cancel, role: .cancel) { renaming = nil }
            Button(Copy.done) { finishRename() }
                .disabled(!renameIsValid)
        } message: {
            if !rename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !renameIsValid {
                Text(Copy.Workspaces.nameAlreadyUsed)
            } else if !renameIsValid {
                Text(Copy.Workspaces.nameRequired)
            }
        }
        .alert(Copy.saveFailedTitle, isPresented: $showingSaveError) {
            Button(Copy.ok) {}
        } message: { Text(Copy.saveFailedBody) }
        .alert(Copy.Workspaces.couldNotRestore, isPresented: Binding(
            get: { workspaceError != nil }, set: { if !$0 { workspaceError = nil } }
        )) {
            Button(Copy.ok) { workspaceError = nil }
        } message: {
            if let workspaceError { Text(workspaceError) }
        }
    }

    private func beginRename(_ workspace: Workspace) {
        rename = workspace.name
        renaming = workspace
    }

    private func finishRename() {
        guard let workspace = renaming else { return }
        let value = String(rename.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Workspace.maxNameLength))
        guard Workspace.isNameAvailable(value, among: store.workspaces, excluding: workspace.id) else { return }
        renaming = nil
        save { $0.renameWorkspace(workspace.id, to: value) }
    }

    private func restore(_ workspace: Workspace) {
        guard store.activeWorkspaces.count < Store.workspaceCap else {
            workspaceError = Copy.Workspaces.cap
            return
        }
        guard Workspace.isNameAvailable(workspace.name, among: store.workspaces, excluding: workspace.id) else {
            workspaceError = Copy.Workspaces.restoreNameConflict
            return
        }
        save { $0.restoreWorkspace(workspace.id) }
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
