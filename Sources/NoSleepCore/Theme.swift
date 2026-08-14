import Foundation

/// Un colore in componenti, senza SwiftUI: il nucleo non conosce l'interfaccia, e così i rapporti
/// di contrasto si calcolano in un test invece che a occhio in una revisione.
public struct RGB: Equatable, Sendable, Codable {
    public let r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { (self.r, self.g, self.b) = (r, g, b) }

    public init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        r = Double((v >> 16) & 0xFF) / 255
        g = Double((v >> 8) & 0xFF) / 255
        b = Double(v & 0xFF) / 255
    }

    /// Luminanza relativa secondo WCAG 2.1.
    public var luminance: Double {
        func lin(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// Il rapporto di contrasto con un altro colore. Si calcola, non si stima.
    public func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        let hi = max(a, b), lo = min(a, b)
        return (hi + 0.05) / (lo + 0.05)
    }
}

/// La carta e l'inchiostro di famiglia: le stesse prese di Kalamos e Otium, perché sono tre app
/// dello stesso principale e devono leggersi come sorelle.
public struct SurfacePalette: Equatable, Sendable {
    public let paper: RGB
    public let card: RGB
    public let text: RGB
    public let dim: RGB
    public let rule: RGB
    public let accent: RGB
    /// L'accento quando NoSleep sta tenendo sveglio il Mac: è l'unico colore che dice «sto agendo».
    public let active: RGB
    public let name: String
}

public enum Surface {
    /// Giorno: la carta di Kalamos.
    public static let giorno = SurfacePalette(
        paper: RGB(hex: "#FAF7F0"),
        card: RGB(hex: "#FFFFFF"),
        text: RGB(hex: "#1E2B3A"),
        dim: RGB(hex: "#5C6672"),
        rule: RGB(hex: "#D9D3C7"),
        accent: RGB(hex: "#2F5C8A"),
        // Ambra scura: sveglio, ma non l'arancione d'allarme di Sveglia e Promemoria.
        active: RGB(hex: "#8A5A1E"),
        name: "Carta"
    )

    /// Sera: Inchiostro.
    public static let sera = SurfacePalette(
        paper: RGB(hex: "#141A22"),
        card: RGB(hex: "#1A222C"),
        text: RGB(hex: "#EFE7D6"),
        dim: RGB(hex: "#9AA3AE"),
        rule: RGB(hex: "#263140"),
        accent: RGB(hex: "#8FB4D9"),
        active: RGB(hex: "#E5B168"),
        name: "Inchiostro"
    )

    public static let both: [SurfacePalette] = [giorno, sera]
}
