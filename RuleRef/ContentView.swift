//
//  ContentView.swift
//  RuleRef
//
//  Created by Rubén Segura Romo on 07/10/2026.
//

import SwiftData
import SwiftUI

/// The library screen.
struct ContentView: View {
    @Query(Library.alphabeticalGames) private var games: [Game]
    @State private var isCreatingGame = false

    var body: some View {
        NavigationStack {
            Group {
                if games.isEmpty {
                    ContentUnavailableView(
                        "No Games",
                        systemImage: "books.vertical",
                        description: Text("Create a game to start your library.")
                    )
                } else {
                    List(games) { game in
                        NavigationLink(value: game) {
                            // StringProtocol overload: the name is user data, never a catalog key.
                            Text(game.name)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Game") { isCreatingGame = true }
                }
            }
            .navigationDestination(for: Game.self) { game in
                GameView(game: game)
            }
            .sheet(isPresented: $isCreatingGame) {
                NewGameSheet()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Game.self, inMemory: true)
}
