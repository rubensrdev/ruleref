import SwiftData
import SwiftUI

struct NewGameSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var failure: Failure?

    private enum Failure {
        case blank
        case duplicate
        case saveFailed
    }

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: create)
                }
            }
        }
    }

    private func message(for failure: Failure) -> Text {
        switch failure {
        case .blank: Text("Enter a name for the game.")
        case .duplicate: Text("A game with this name already exists.")
        case .saveFailed: Text("The game could not be saved.")
        }
    }

    private func create() {
        do {
            try Library(context: modelContext).createGame(named: name)
            dismiss()
        } catch GameNameError.blank {
            failure = .blank
        } catch GameNameError.duplicate {
            failure = .duplicate
        } catch {
            failure = .saveFailed
        }
    }
}

#Preview {
    NewGameSheet()
        .modelContainer(for: Game.self, inMemory: true)
}
