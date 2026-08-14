import AppKit

/// Una sola NoSleep per volta.
///
/// Senza questa guardia, ogni lancio aggiunge un'icona nella barra dei menu: due icone identiche,
/// due pannelli, e due processi che scrivono lo stesso file di richiesta all'helper. Se n'è accorto
/// lui vedendone due in cima allo schermo (2026-08-07), ed erano le mie sonde `--scatta` sommate
/// all'app installata.
///
/// **Il problema vero non è l'estetica, è che due processi litigano.** Il secondo scrive il proprio
/// battito sopra quello del primo, quindi lo stato del coperchio dipende da chi ha scritto per
/// ultimo, e nessuno dei due sa dell'altro.
enum SingleInstance {

    /// Se un'altra NoSleep è già viva, questa esce **subito e in silenzio**, e porta in primo piano
    /// quella che c'era già: è il comportamento che chiunque si aspetta ricliccando l'icona.
    ///
    /// Il confronto è sull'identificatore del bundle, non sul nome del processo: il nome lo può
    /// portare anche una copia in una cartella di sviluppo, e ne abbiamo appena viste due.
    static func enforceOrExit() {
        guard let me = Bundle.main.bundleIdentifier else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: me)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let first = others.first else { return }
        first.activate()
        exit(0)
    }
}
