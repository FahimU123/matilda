import SwiftUI

struct PrivateNumberRow: View {
    @Environment(AppModel.self) private var model
    let field: ProfileField

    @State private var isEditing = false
    @State private var draft = ""
    @State private var saved = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent(field.label, value: saved ? "Saved" : "Not saved")
            if isEditing {
                SecureField("Full number", text: $draft)
                    .keyboardType(.numberPad)
                HStack {
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .disabled(draft.isEmpty)
                    Button("Cancel", role: .cancel, action: cancel)
                }
            } else {
                Button(saved ? "Replace" : "Add", action: edit)
            }
            if let error {
                Text(error).foregroundStyle(Theme.hangUp)
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        saved = model.vault.hasValue(for: field.key)
    }

    private func edit() {
        draft = ""
        isEditing = true
    }

    private func cancel() {
        draft = ""
        isEditing = false
    }

    private func save() {
        do {
            try model.vault.store(draft, for: field.key)
            error = nil
            isEditing = false
            draft = ""
            refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
