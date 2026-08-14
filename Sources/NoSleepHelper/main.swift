import Foundation
import NoSleepCore

// NoSleep helper — gira da root, lanciato da launchd, e non fa che una cosa: decidere se
// `SleepDisabled` deve valere 1 o 0, e farlo valere.
//
// **Perché esiste, in una riga.** Perché il ritorno al sonno non può dipendere dal processo che ha
// chiesto di restare sveglio: se ne dipendesse, il caso «l'app è morta» sarebbe proprio quello
// scoperto, e il Mac resterebbe sveglio per sempre senza dirlo a nessuno.
//
// Argomenti (fissati all'installazione, mai presi dall'ambiente):
//   --uid <n>        l'utente che ha diritto di chiedere
//   --request <path> il file di richiesta di quell'utente

// ── Argomenti ────────────────────────────────────────────────────────────────

func arg(_ name: String) -> String? {
    let a = CommandLine.arguments
    guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
    return a[i + 1]
}

guard let uidString = arg("--uid"), let allowedUID = UInt32(uidString),
      let requestPath = arg("--request") else {
    FileHandle.standardError.write(Data("nosleep-helper: servono --uid e --request\n".utf8))
    exit(2)
}

let requestURL = URL(fileURLWithPath: requestPath)

// ── La leva ──────────────────────────────────────────────────────────────────

/// Legge lo stato reale della chiave dal sistema. **Sempre dal sistema, mai da una variabile
/// nostra**: se qualcuno cambia `disablesleep` da un terminale, chi ha ragione è il disco.
func currentSleepDisabled() -> Bool? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    p.arguments = ["read", "/Library/Preferences/com.apple.PowerManagement", "SystemPowerSettings"]
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return nil }
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    guard let range = out.range(of: "SleepDisabled") else { return nil }
    let tail = out[range.upperBound...]
    guard let eq = tail.firstIndex(of: "=") else { return nil }
    let value = tail[tail.index(after: eq)...].prefix(while: { $0 != ";" })
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return value == "1"
}

/// L'unico punto in cui questo processo cambia qualcosa nel sistema.
///
/// Nessuna shell, nessuna stringa costruita: `pmset` viene invocato con due argomenti costanti e
/// un terzo che è `"1"` o `"0"` e nient'altro (ISC-13). Non esiste un input esterno che possa
/// arrivare fin qui.
@discardableResult
func setSleepDisabled(_ on: Bool) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["-a", "disablesleep", on ? "1" : "0"]
    p.standardOutput = FileHandle.nullDevice
    p.standardError = FileHandle.nullDevice
    do { try p.run() } catch { return false }
    p.waitUntilExit()
    return p.terminationStatus == 0
}

func note(_ s: String) {
    // launchd raccoglie stdout nel file dichiarato nel plist.
    print("[\(ISO8601DateFormatter().string(from: Date()))] \(s)")
    fflush(stdout)
}

// ── Lo stato sicuro, prima di qualunque altra cosa (ISC-21) ──────────────────
//
// Se il Mac si è riavviato mentre `SleepDisabled` valeva 1, nessuno lo rimetterebbe a posto: il
// primo atto del daemon è quindi riportarlo a 0, sempre, senza guardare la richiesta.

note("avvio: porto SleepDisabled a 0 prima di leggere qualunque richiesta")
setSleepDisabled(false)
var applied = false

// ── Il giro ──────────────────────────────────────────────────────────────────

/// La richiesta conta solo se il file appartiene all'utente autorizzato (ISC-15).
///
/// Senza questo controllo, un altro utente della macchina potrebbe piazzare un file al posto giusto
/// e decidere per lui.
func requestIsOwnedByAllowedUser() -> Bool {
    var st = stat()
    guard stat(requestPath, &st) == 0 else { return false }
    return st.st_uid == allowedUID
}

while true {
    let now = Date().timeIntervalSince1970
    var wanted = false

    if requestIsOwnedByAllowedUser() {
        let raw = try? Data(contentsOf: requestURL)
        wanted = HelperRequest.shouldDisableSleep(rawJSON: raw, now: now)
    }

    // Il confronto è con lo stato **reale**, non con quello che credo di aver applicato: così una
    // modifica fatta da fuori viene ripresa al giro dopo invece di restare disallineata.
    let real = currentSleepDisabled() ?? applied

    if wanted != real {
        if setSleepDisabled(wanted) {
            applied = wanted
            note(wanted
                 ? "sonno disattivato: l'app lo chiede e sta battendo"
                 : "sonno riattivato: \(requestIsOwnedByAllowedUser() ? "richiesta caduta o battito fermo" : "nessuna richiesta valida")")
        } else {
            note("pmset ha fallito puntando a \(wanted ? 1 : 0)")
        }
    }

    Thread.sleep(forTimeInterval: 5)
}
