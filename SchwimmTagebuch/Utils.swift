import SwiftUI

@frozen
enum Zeit {
    static func formatSek(_ s: Int) -> String {
        let m = s / 60
        let sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, default defaultValue: String) {
        self.init(
            get: { source.wrappedValue ?? defaultValue },
            set: { source.wrappedValue = $0 }
        )
    }
}

extension Array where Element == String {
    mutating func updatePresence(of value: String, include: Bool) {
        if include {
            if !contains(value) { append(value) }
        } else {
            removeAll { $0 == value }
        }
    }
}
