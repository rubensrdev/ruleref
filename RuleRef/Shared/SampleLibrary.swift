#if DEBUG
import SwiftData
import SwiftUI

/// Sample data for previews: an in-memory library, never the app's store or a rulebook file.
enum SampleLibrary {
    static let gameNames = ["Taifa", "Catán", "Carcassonne"]

    static func container(gameNames: [String]) throws -> ModelContainer {
        let container = try ModelContainer(
            for: Game.self, Rulebook.self, Passage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let library = Library(context: container.mainContext)
        for name in gameNames {
            try library.createGame(named: name)
        }
        return container
    }
}

/// A library holding `SampleLibrary.gameNames`, without rulebooks.
struct GamesPreview: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        try SampleLibrary.container(gameNames: SampleLibrary.gameNames)
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}

/// A library with no games.
struct EmptyLibraryPreview: PreviewModifier {
    static func makeSharedContext() async throws -> ModelContainer {
        try SampleLibrary.container(gameNames: [])
    }

    func body(content: Content, context: ModelContainer) -> some View {
        content.modelContainer(context)
    }
}
#endif
