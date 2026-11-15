nonisolated struct HandPoint: Equatable, Sendable {
    var x: Double
    var y: Double

    func distance(to other: HandPoint) -> Double {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
