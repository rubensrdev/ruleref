//
//  RuleRefTests.swift
//  RuleRefTests
//
//  Created by Rubén Segura Romo on 07/10/2026.
//

import Foundation
import Testing

struct RuleRefTests {

    // Hosted tests: Bundle.main is the app bundle, not the test runner.
    @Test func appBundleShipsSpanishLocalization() throws {
        let bundle = Bundle.main
        try #require(bundle.bundleIdentifier == "dev.ruben.RuleRef")
        #expect(bundle.localizations.contains("es"))
    }

}
