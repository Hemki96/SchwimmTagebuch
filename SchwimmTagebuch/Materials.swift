import SwiftUI

@available(iOS 17, *)
extension Material {
    /// Zentrales Alias für den neuen iOS-"Liquid Glass" Look.
    /// Bis das echte Material verfügbar ist, mappen wir auf ein passendes Systemmaterial.
    static var liquidGlass: Material {
        if #available(iOS 26, *) {
            // TODO: Ersetze durch das echte Liquid-Glass-Material, sobald verfügbar
            return .thinMaterial
        } else {
            return .ultraThinMaterial
        }
    }
}
