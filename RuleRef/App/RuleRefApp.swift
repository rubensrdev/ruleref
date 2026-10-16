//
//  RuleRefApp.swift
//  RuleRef
//
//  Created by Rubén Segura Romo on 07/10/2026.
//

import SwiftData
import SwiftUI

@main
struct RuleRefApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(for: [Game.self, Rulebook.self, Passage.self])
    }
}
