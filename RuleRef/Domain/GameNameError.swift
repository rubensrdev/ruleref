import Foundation

nonisolated enum GameNameError: Error, Equatable {
    case blank
    case duplicate
}
