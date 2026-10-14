//
//  ContentView.swift
//  RuleRef
//
//  Created by Rubén Segura Romo on 07/10/2026.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var isCreatingGame = false

    var body: some View {
        Button("New Game") { isCreatingGame = true }
            .buttonStyle(.borderedProminent)
            .sheet(isPresented: $isCreatingGame) {
                NewGameSheet()
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Game.self, inMemory: true)
}
