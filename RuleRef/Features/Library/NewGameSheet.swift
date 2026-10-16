import SwiftData
import SwiftUI

/// Creates a game in the library; `NewGameForm` shows it.
struct NewGameSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var failure: NewGameFailure?

    var body: some View {
        NewGameForm(name: $name, failure: failure, create: create, cancel: { dismiss() })
    }

    private func create() {
        do {
            try Library(context: modelContext).createGame(named: name)
            dismiss()
        } catch {
            failure = NewGameFailure(error: error)
        }
    }
}

#if DEBUG
#Preview("Sheet", traits: .modifier(EmptyLibraryPreview())) {
    NewGameSheet()
}
#endif
