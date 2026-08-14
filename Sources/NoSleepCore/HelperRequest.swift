import Foundation

/// Tutto ciò che l'app può chiedere all'helper da root: **un booleano e un battito.**
///
/// La superficie è volutamente minuscola. L'helper gira come root, quindi ogni campo in più qui è
/// un campo in più che un processo locale ostile potrebbe scrivere. Con due campi il caso peggiore
/// di un abuso è «il Mac resta sveglio»: non è esecuzione di codice, non è lettura di dati, e il
/// cane da guardia lo cancella comunque dopo mezzo minuto di silenzio.
public struct HelperRequest: Codable, Equatable, Sendable {
    /// Lo stato voluto per `SleepDisabled`.
    public var lidAwake: Bool
    /// Secondi dall'epoca dell'ultimo battito dell'app.
    public var heartbeat: Double

    public init(lidAwake: Bool, heartbeat: Double) {
        self.lidAwake = lidAwake
        self.heartbeat = heartbeat
    }

    /// Quanto silenzio basta perché l'helper decida che l'app non c'è più.
    ///
    /// Trenta secondi, con l'app che batte ogni dieci: due battiti persi sono tolleranza per una
    /// macchina sotto carico, tre sono la morte. Più corto renderebbe fragile il caso normale, più
    /// lungo lascerebbe il Mac sveglio troppo a lungo dopo un crash.
    public static let staleAfter: Double = 30

    /// La domanda che l'helper si fa a ogni giro: **devo tenere disattivato il sonno adesso?**
    ///
    /// Fail-safe per costruzione: qualunque risposta che non sia un sì esplicito e fresco è un no.
    /// Richiesta assente, JSON rotto, campo mancante, battito vecchio, battito nel futuro: tutti no.
    public static func shouldDisableSleep(rawJSON: Data?, now: Double) -> Bool {
        guard let data = rawJSON,
              let req = try? JSONDecoder().decode(HelperRequest.self, from: data) else { return false }
        guard req.lidAwake else { return false }
        let age = now - req.heartbeat
        // Un battito nel futuro è un orologio manomesso o un file costruito a mano: non è fresco,
        // è sospetto. Tolleriamo due secondi di deriva e non un secondo di più.
        guard age >= -2, age <= staleAfter else { return false }
        return true
    }
}
