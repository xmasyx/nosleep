import Foundation
import NoSleepCore

/// Il lato app dell'helper privilegiato: installarlo, sapere se c'è, battere il cuore.
///
/// Nota su cosa **non** c'è qui: nessun modo per l'app di scrivere `SleepDisabled` da sé. L'app
/// esprime un desiderio in un file, e a decidere resta l'helper. È la stessa ragione per cui il
/// cane da guardia funziona: se l'app potesse scrivere quella chiave direttamente, morendo la
/// lascerebbe scritta.
enum HelperControl {

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: Paths.helperBinary)
            && FileManager.default.fileExists(atPath: Paths.helperPlist)
    }

    /// Lo stato **vero**, letto dal sistema (ISC-41). L'app non si fida di quello che ha chiesto.
    static func sleepDisabledNow() -> Bool? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["read", "/Library/Preferences/com.apple.PowerManagement", "SystemPowerSettings"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        guard let r = out.range(of: "SleepDisabled"),
              let eq = out[r.upperBound...].firstIndex(of: "=") else { return nil }
        let v = out[out.index(after: eq)...].prefix(while: { $0 != ";" })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return v == "1"
    }

    /// Scrive la richiesta e il battito. Chiamata a ogni giro, anche quando niente è cambiato:
    /// **è il battito a essere il segnale**, non il contenuto.
    static func beat(lidAwake: Bool) {
        Paths.ensureSupport()
        let req = HelperRequest(lidAwake: lidAwake, heartbeat: Date().timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(req) else { return }
        try? data.write(to: Paths.request(), options: .atomic)
    }

    /// Toglie la richiesta. L'helper la leggerà come «no» al giro dopo, senza aspettare i trenta
    /// secondi del battito: l'uscita pulita non deve costare mezzo minuto di Mac sveglio.
    static func clearRequest() {
        try? FileManager.default.removeItem(at: Paths.request())
    }

    // ── Installazione ────────────────────────────────────────────────────────

    enum InstallResult {
        case installed
        case cancelled          // ha chiuso la finestra della password
        case failed(String)
    }

    /// Installa il daemon chiedendo la password **una volta sola** (ISC-10).
    ///
    /// Il percorso passa da uno script dentro il bundle invece che da una riga di comando costruita
    /// qui: una sequenza lunga dentro `do shell script` è esattamente il posto dove nasce un difetto
    /// di quoting, e qui quel difetto girerebbe da root.
    static func install() -> InstallResult {
        guard let script = Bundle.main.url(forResource: "install-helper", withExtension: "sh") else {
            return .failed(S.helperInstallScriptMissing)
        }
        let uid = getuid()
        let request = Paths.request().path

        // I tre valori sono nostri e non arrivano da fuori, ma le virgolette singole ci vanno
        // comunque: il percorso della home può contenere spazi, e la regola non è «questo input è
        // fidato», è «una stringa che finisce in una shell si cita sempre».
        let cmd = "'\(script.path)' '\(uid)' '\(request)'"
        let osa = "do shell script \"\(cmd.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", osa]
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        do { try p.run() } catch { return .failed(S.cannotLaunchOsascript) }
        let errText = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()

        if p.terminationStatus == 0 { return isInstalled ? .installed : .failed(S.helperPartlyInstalled) }
        // -128 è il codice con cui AppleScript dice «l'utente ha annullato».
        if errText.contains("-128") { return .cancelled }
        return .failed(errText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func uninstall() -> InstallResult {
        guard let script = Bundle.main.url(forResource: "install-helper", withExtension: "sh") else {
            return .failed(S.helperScriptMissing)
        }
        let cmd = "'\(script.path)' --remove"
        let osa = "do shell script \"\(cmd)\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", osa]
        p.standardError = FileHandle.nullDevice
        p.standardOutput = FileHandle.nullDevice
        do { try p.run() } catch { return .failed(S.cannotLaunchOsascript) }
        p.waitUntilExit()
        return p.terminationStatus == 0 ? .installed : .failed(S.helperRemovalFailed)
    }
}
