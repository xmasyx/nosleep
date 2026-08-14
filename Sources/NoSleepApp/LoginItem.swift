import Foundation
import ServiceManagement

/// L'avvio automatico all'accesso.
///
/// Passa da `SMAppService.mainApp`, che è l'API moderna: macOS registra l'app in **Elementi
/// login** e l'utente la vede e la può togliere da lì. Il vecchio LaunchAgent scritto a mano
/// funzionerebbe anche, ma macOS lo cataloga come *legacy agent* e ci mette sopra l'avviso
/// «Attività app in background», che è la stessa lezione già pagata su Otium.
///
/// **Registra da sé alla prima apertura**, perché un'app che deve esserci sempre e che l'utente
/// deve ricordarsi di lanciare è un'app che un giorno non c'è. L'interruttore nel pannello serve a
/// disdire, non a concedere.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// `true` se lo stato è cambiato davvero.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on {
                guard SMAppService.mainApp.status != .enabled else { return false }
                try SMAppService.mainApp.register()
            } else {
                guard SMAppService.mainApp.status == .enabled else { return false }
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }

    /// Alla prima apertura in assoluto si registra; dopo, la scelta è dell'utente e non si tocca.
    ///
    /// Il segno di «prima volta» è un file, non lo stato del servizio: se guardassi solo lo stato,
    /// ogni volta che l'utente toglie l'app dagli elementi login io gliela rimetterei, il che è il
    /// modo di far disinstallare un'app.
    static func registerOnceIfNeeded(marker: URL) {
        guard !FileManager.default.fileExists(atPath: marker.path) else { return }
        set(true)
        try? Data("1".utf8).write(to: marker, options: .atomic)
    }
}
