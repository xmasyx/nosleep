import Foundation

/// Il registro: una riga per ogni volta che una presa si apre o si chiude, e **perché**.
///
/// Serve a una cosa sola e concreta: quando il Mac non si è addormentato, o si è addormentato
/// mentre non doveva, questo file dice chi ha deciso. Senza, resterebbe solo un'impressione.
public struct LogEntry: Codable, Equatable, Sendable {
    public let at: Double
    public let who: String        // "app", "helper", "cli"
    public let event: String
    public let screenAwake: Bool
    public let lidAwake: Bool
    public let leases: Int
    public let thermal: String
    /// I gradi misurati, quando il termometro risponde. Servono a tarare le soglie su dati veri
    /// invece che su un'opinione, e a rispondere a «il Mac era caldo?» con un numero.
    public let board: Double?
    public let battery: Double?
    /// Chi altro impediva il sonno in quel momento, per nome di processo. Non si mostra più nel
    /// pannello, ma resta qui: è la riga che spiega un «non ha dormito» letto il giorno dopo.
    public let others: [String]?

    public init(at: Double, who: String, event: String,
                screenAwake: Bool, lidAwake: Bool, leases: Int, thermal: String,
                board: Double? = nil, battery: Double? = nil, others: [String]? = nil) {
        self.at = at
        self.who = who
        self.event = event
        self.screenAwake = screenAwake
        self.lidAwake = lidAwake
        self.leases = leases
        self.thermal = thermal
        self.board = board
        self.battery = battery
        self.others = others
    }
}

public enum Log {
    /// Aggiunge in coda. Se il file non c'è lo crea; se la scrittura fallisce non si fa niente,
    /// perché un registro che non si scrive non è una buona ragione per non tenere sveglio il Mac.
    public static func append(_ entry: LogEntry, to url: URL) {
        guard var data = try? JSONEncoder().encode(entry) else { return }
        data.append(0x0A)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
