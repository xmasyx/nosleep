import Foundation

/// Dove vivono le cose. Un posto solo, perché tre processi diversi (l'app, l'helper da root, la
/// riga di comando) devono guardare esattamente gli stessi file, e un percorso ricopiato a mano in
/// tre punti diverge senza che niente fallisca.
public enum Paths {
    /// Dirotta TUTTI i percorsi altrove. Serve ai banchi, e solo a loro.
    ///
    /// **Nato da un difetto vero (2026-08-07):** `--selftest-thermal` costruiva un `AppModel` che
    /// scriveva nella cartella VERA, quindi il banco spegneva davvero l'interruttore dell'utente e
    /// lasciava nel registro tre righe «disattivato perché il Mac è caldo» che raccontavano un
    /// surriscaldamento **mai avvenuto**. Un registro che mente è peggio di un registro assente:
    /// la notte dopo avrei letto quelle righe come prova di un evento termico reale.
    ///
    /// La regola generale: un banco che costruisce l'oggetto vero deve prima dirottarne lo stato.
    public static var homeOverride: URL?

    public static var home: URL {
        homeOverride ?? URL(fileURLWithPath: NSHomeDirectory())
    }
    /// L'identificatore del bundle, che è anche il nome del daemon e della sua etichetta launchd.
    public static let bundleID = "app.nosleep.mac"
    public static let helperLabel = "app.nosleep.helper"

    /// La cartella dell'utente. L'helper gira da root e quindi NON può derivarla da `NSHomeDirectory()`:
    /// per lui il percorso arriva come argomento, deciso all'installazione.
    public static func support(home: URL = Paths.home) -> URL {
        home.appendingPathComponent("Library/Application Support/NoSleep", isDirectory: true)
    }

    public static func config(home: URL = Paths.home) -> URL {
        support(home: home).appendingPathComponent("config.json")
    }

    /// Una prenotazione per file: due processi che ne prendono una insieme non si pestano i piedi,
    /// e una sessione morta lascia un file con una scadenza invece di un contatore sbagliato.
    public static func leases(home: URL = Paths.home) -> URL {
        support(home: home).appendingPathComponent("leases", isDirectory: true)
    }

    /// Il file che l'app scrive e l'helper legge: lo stato voluto più il battito.
    public static func request(home: URL = Paths.home) -> URL {
        support(home: home).appendingPathComponent("request.json")
    }

    /// Il segno che l'app è già stata aperta almeno una volta. Serve a registrarsi negli elementi
    /// login **una volta sola**, invece di rimettercisi ogni avvio dopo che l'utente l'ha tolta.
    public static func firstRunMarker(home: URL = Paths.home) -> URL {
        support(home: home).appendingPathComponent("first-run")
    }

    public static func log(home: URL = Paths.home) -> URL {
        support(home: home).appendingPathComponent("log.jsonl")
    }

    // ── Lato sistema, percorsi fissi ─────────────────────────────────────────
    public static let helperBinary = "/Library/PrivilegedHelperTools/app.nosleep.helper"
    public static let helperPlist = "/Library/LaunchDaemons/app.nosleep.helper.plist"

    /// Crea le cartelle se non ci sono. Silenzioso: se fallisce, fallirà rumorosamente la scrittura
    /// che viene dopo, con un errore che dice qualcosa.
    @discardableResult
    public static func ensureSupport(home: URL = Paths.home) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: support(home: home), withIntermediateDirectories: true)
            try fm.createDirectory(at: leases(home: home), withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
