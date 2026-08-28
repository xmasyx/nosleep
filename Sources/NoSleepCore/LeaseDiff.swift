/// I cambiamenti leggibili fra due fotografie delle prenotazioni vive.
public enum LeaseDiff {

    /// Produce le righe del registro senza leggere il disco né l'orologio.
    ///
    /// L'identità è `Lease.id`: una prenotazione nuova viene prima, nell'ordine di `after`; quelle
    /// sparite seguono, nell'ordine di `before`, distinguendo la scadenza dalla restituzione. Un
    /// rinnovo non è un evento. Resta un punto cieco accettato: se una prenotazione scade e viene
    /// ripresa con lo stesso identificatore fra due giri, non compare alcuna riga; il giro è ogni
    /// cinque secondi e le due fotografie non possono raccontare ciò che è successo in mezzo.
    public static func events(before: [Lease], after: [Lease], now: Double) -> [String] {
        let beforeIDs = Set(before.map(\.id))
        let afterIDs = Set(after.map(\.id))
        var seenTaken: Set<String> = []
        var seenVanished: Set<String> = []
        var lines: [String] = []

        for lease in after
            where !beforeIDs.contains(lease.id) && seenTaken.insert(lease.id).inserted {
            let ttl = Int((lease.expires - lease.takenAt).rounded())
            lines.append(S.logLeaseTaken(lease.id, ttl: ttl))
        }
        for lease in before
            where !afterIDs.contains(lease.id) && seenVanished.insert(lease.id).inserted {
            lines.append(lease.expires <= now
                         ? S.logLeaseExpired(lease.id)
                         : S.logLeaseReleased(lease.id))
        }
        return lines
    }
}
