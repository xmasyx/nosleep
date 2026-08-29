import Foundation

/// I quattro livelli che macOS dichiara. **Non sono temperature.**
///
/// Il numero sul die non è la domanda giusta: un Apple Silicon sotto carico sta a cento gradi ed è
/// normale, perché il chip si difende da solo abbassando la frequenza. La domanda giusta è «il
/// sistema sta già rallentando per raffreddarsi?», e quella la risponde `ProcessInfo.thermalState`.
public enum ThermalLevel: Int, Comparable, Sendable, Codable {
    case nominal = 0
    case fair = 1
    /// Da qui in giù il sistema **sta già** abbassando le frequenze.
    case serious = 2
    case critical = 3

    public static func < (a: ThermalLevel, b: ThermalLevel) -> Bool { a.rawValue < b.rawValue }

    /// La soglia oltre la quale NoSleep molla tutto.
    ///
    /// È `serious` e non `critical` per una ragione che non è la paura del guasto: a `serious` stai
    /// già pagando calore per **meno** lavoro, quindi tenere sveglio il Mac ha smesso di servire
    /// allo scopo per cui l'hai acceso. Aspettare `critical` significa aspettare che macOS chieda
    /// alle app di fermarsi.
    public static let releaseThreshold: ThermalLevel = .serious

    public var forcesRelease: Bool { self >= ThermalLevel.releaseThreshold }

    /// Chiave del campo `thermal` in `log.jsonl`: è congelata apposta, perché righe scritte in
    /// lingue e mesi diversi devono restare confrontabili byte per byte.
    public var logKey: String {
        switch self {
        case .nominal: return "normale"
        case .fair: return "tiepido"
        case .serious: return "caldo"
        case .critical: return "critico"
        }
    }

    public var name: String {
        switch self {
        case .nominal: return S.thermalNormal
        case .fair: return S.thermalWarm
        case .serious: return S.thermalHot
        case .critical: return S.thermalCritical
        }
    }

    /// Dalla enum di Foundation alla nostra. Sta qui e non nell'app perché è la parte che i test
    /// devono poter esercitare senza scaldare davvero un Mac.
    public static func from(processInfo raw: ProcessInfo.ThermalState) -> ThermalLevel {
        switch raw {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .serious   // sconosciuto si sbaglia verso il sicuro
        }
    }
}


/// La soglia sulla temperatura **misurata**, che è un'altra cosa dalla pressione termica.
///
/// **Perché serve anche questa.** `ThermalLevel` risponde a «il sistema sta rallentando?», e la
/// notte del 7/08 ha risposto no per sei ore mentre il Mac era caldo al tatto. Un portatile chiuso
/// e quasi fermo scalda senza mai mettere in difficoltà il chip: il calore non se ne va, ma nessuno
/// fatica. Questa soglia guarda i gradi.
///
/// **È un secondo paio d'occhi, non la guardia.** Quando il sensore tace, la regola tace e
/// `ThermalLevel` resta al suo posto. Un fail-safe che dipende da una lettura opzionale non è un
/// fail-safe.
///
/// **Il sensore è uno solo, ed è la batteria — la scocca è stata tolta il 2026-08-10.** Il gruppo
/// che il codice chiamava «scocca» non è la scocca: il suo sensore più caldo è `PMU tdev7`, che sta
/// **due gradi** dal die (misurati 59,9 contro 61,9). Sul pannello e sul telaio non esiste alcun
/// sensore, verificato elencandoli tutti e 46, quindi quella soglia guardava il chip con il nome
/// sbagliato. E il chip a 81 gradi sotto carico è normale: nelle due volte in cui la rete è
/// scattata davvero, il registro dice `board 81` e `thermal "normale"`, cioè macOS non stava
/// nemmeno abbassando le frequenze, e l'app ha mollato la presa con **quattro lavori in corso**.
/// Sul die i gradi non sono mai stati la domanda giusta: a quella risponde `ThermalLevel`.
public enum Temperature {
    /// La batteria è il pezzo che invecchia col caldo, ed è lento a scaldarsi: quando arriva qui,
    /// il calore è lì da un pezzo. È la soglia che conta a coperchio chiuso, cioè nel caso vero —
    /// il portatile in uno zaino senza aria — ed è l'unica che misura un danno che macOS non copre.
    /// Il numero arriva da `AppleSmartBattery`, che è API pubblica: a Mac fermo legge 31.
    public static let batteryCeiling = 45.0

    /// `board` resta nella firma perché finisce nel registro, e serve a tarare: non decide più
    /// niente. Toglierlo dal log renderebbe cieca la prossima taratura.
    public static func exceeded(board: Double?, battery: Double?) -> String? {
        _ = board
        if let b = battery, b >= batteryCeiling {
            return S.batteryTemperatureReason(b)
        }
        return nil
    }
}
