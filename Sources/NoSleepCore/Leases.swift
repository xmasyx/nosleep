import Foundation

/// Una prenotazione: «questo lavoro è vivo, non addormentarti».
///
/// Ha **sempre** una scadenza, e non è un dettaglio: senza, una sessione andata in crash lascerebbe
/// una prenotazione eterna e il Mac non tornerebbe mai a dormire. La scadenza è la ragione per cui
/// una prenotazione non restituita è un ritardo invece che un guasto permanente.
public struct Lease: Codable, Equatable, Sendable {
    public let id: String
    /// Secondi dall'epoca. Oltre questo istante la prenotazione non conta più.
    public let expires: Double
    public let label: String
    public let takenAt: Double

    public init(id: String, expires: Double, label: String, takenAt: Double) {
        self.id = id
        self.expires = expires
        self.label = label
        self.takenAt = takenAt
    }

    public func isAlive(now: Double) -> Bool { expires > now }
}

/// Il registro delle prenotazioni, su disco, un file per prenotazione.
///
/// L'orologio è iniettabile perché la scadenza è la parte che va provata, e provarla aspettando
/// davvero non è una prova, è una pausa.
public struct LeaseStore {
    public let directory: URL
    private let fm = FileManager.default

    public init(directory: URL) {
        self.directory = directory
    }

    /// Il nome del file è derivato dall'identificatore, ripulito: un identificatore che arriva da
    /// fuori non deve poter scrivere in un'altra cartella. Qualunque cosa non sia lettera, cifra,
    /// trattino o underscore diventa un trattino, e i punti spariscono, quindi `../../etc/x` non
    /// esce dalla cartella.
    public static func fileName(for id: String) -> String {
        let safe = id.map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" { return ch }
            return "-"
        }
        let s = String(safe)
        return (s.isEmpty ? "senza-nome" : String(s.prefix(120))) + ".json"
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(Self.fileName(for: id))
    }

    @discardableResult
    public func hold(id: String, ttl: Double, label: String, now: Double) -> Bool {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let lease = Lease(id: id, expires: now + ttl, label: label, takenAt: now)
        guard let data = try? JSONEncoder().encode(lease) else { return false }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    public func release(id: String) -> Bool {
        let u = url(for: id)
        guard fm.fileExists(atPath: u.path) else { return false }
        return (try? fm.removeItem(at: u)) != nil
    }

    /// Le prenotazioni vive, e **come effetto** la raccolta di quelle scadute.
    ///
    /// La raccolta sta qui, e non in un lavoro periodico a parte, perché così avviene ogni volta
    /// che qualcuno chiede il conteggio: un percorso morto non può accumulare spazzatura se il
    /// percorso vivo la porta via passando.
    public func alive(now: Double) -> [Lease] {
        guard let files = try? fm.contentsOfDirectory(at: directory,
                                                      includingPropertiesForKeys: nil) else { return [] }
        var out: [Lease] = []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f),
                  let lease = try? JSONDecoder().decode(Lease.self, from: data) else {
                // Un file illeggibile è spazzatura, non una prenotazione: non può tenere sveglio
                // il Mac per il fatto di essere rotto.
                try? fm.removeItem(at: f)
                continue
            }
            if lease.isAlive(now: now) {
                out.append(lease)
            } else {
                try? fm.removeItem(at: f)
            }
        }
        return out.sorted { $0.takenAt < $1.takenAt }
    }

    public func count(now: Double) -> Int { alive(now: now).count }
}
