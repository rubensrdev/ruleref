import SwiftUI

/// The new-game form. `NewGameSheet` owns the name, the failure and the actions.
struct NewGameForm: View {
    @Binding var name: String
    let failure: NewGameFailure?
    let create: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onSubmit(create)
                } footer: {
                    if let failure {
                        message(for: failure)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // .cancel, not .close: cancelling discards the typed name.
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: create)
                }
            }
        }
    }

    private func message(for failure: NewGameFailure) -> Text {
        switch failure {
        case .blank: Text("Enter a name for the game.")
        case .duplicate: Text("A game with this name already exists.")
        case .saveFailed: Text("The game could not be saved.")
        }
    }
}

#if DEBUG
#Preview("Empty") {
    NewGameForm(name: .constant(""), failure: nil, create: {}, cancel: {})
}

#Preview("Blank Name") {
    NewGameForm(name: .constant(""), failure: .blank, create: {}, cancel: {})
}

#Preview("Duplicate") {
    NewGameForm(name: .constant("Taifa"), failure: .duplicate, create: {}, cancel: {})
}

#Preview("Save Failed") {
    NewGameForm(name: .constant("Taifa"), failure: .saveFailed, create: {}, cancel: {})
}
#endif
