# DESIGN.md

Interface rules for every RuleRef screen. RuleRef has no visual identity of its own until m4 (`docs/build-brief.md`, Non-goals): these rules are about using Apple's components well, not about colors or branding.

## Source

- Apple's Human Interface Guidelines and standard SwiftUI controls. No custom colors, fonts, materials or components until m4.
- Check every API and its iOS 26.0 availability as `AGENTS.md` says (Cupertino MCP or developer.apple.com).

## Buttons and symbols

- A button outside an alert is a `Label` with a title and an SF Symbol. The title stays a catalog key: VoiceOver reads it, and the system shows it where it fits.
- In a toolbar, an item shows only its symbol, unless the action has no clear symbol (for example Edit, as the HIG says).
- Closing, confirming or cancelling a sheet uses a standard button role (`.close`, `.confirm`, `.cancel`; `.close` and `.confirm` need iOS 26.0) instead of a custom title. The spec decides which role fits: cancel discards what the user entered, close does not.
- Alert buttons are text.
- An empty or unavailable state is a `ContentUnavailableView` with a symbol.
- The spec names every symbol, taken from the SF Symbols catalog for iOS 26.0; never guess a name. The user confirms it renders in the previews.

## Previews

- Every file that declares a SwiftUI view has at least one `#Preview`, and one named preview for each state the view can show (for example "Empty", "Loaded", "Importing" or "Error").
- Previews use sample data only: plain values, or an in-memory `ModelContainer` seeded with sample models, shared through a `PreviewModifier` when several previews need it. Never the app's persistent store, a stored rulebook file or the network.
- Sample data lives in the app target, in `RuleRef/Shared/`, inside `#if DEBUG`.
- A view receives only the data it shows. When a state is reachable only at run time (a `@State` flag, an alert), split the view: a content view takes plain values and has a preview for each state; a thin wrapper owns `@Query`, `@State`, the environment and the actions.
- Previews are not validation evidence: the user checks them in Xcode, and the validator lists them in `not_verified`.
