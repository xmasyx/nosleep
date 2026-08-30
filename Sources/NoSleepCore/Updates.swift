import Foundation

/// **Le decisioni pure dell'aggiornamento: niente rete, niente processi, niente interfaccia.**
///
/// Qui si decide se una versione è più nuova, se è ora di controllare, se l'app è arrivata da
/// Homebrew e che cosa deve fare il bottone. Chi esegue davvero (la GET su GitHub, il processo
/// `brew`, il riavvio) sta in `NoSleepApp/Updater.swift` e chiama queste funzioni: così la parte
/// che può sbagliare in silenzio è coperta da `UpdatesTests`, e la parte che parla col mondo è
/// corta e si prova a mano con lo shim.
///
/// Il contratto è questo file più `Tests/NoSleepCoreTests/UpdatesTests.swift`: i corpi qui sotto
/// sono segnaposto che fanno uscire i test ROSSI, e la consegna è verde.
public enum Updates {
    /// Il repo GitHub da cui si legge l'ultima release.
    public static let repo = "xmasyx/nosleep"
    /// Il token del cask nel tap.
    public static let caskToken = "nosleep"
    /// Il tap Homebrew della famiglia (`brew tap xmasyx/tap` → repo `xmasyx/homebrew-tap`).
    public static let tap = "xmasyx/tap"

    /// Come l'app è arrivata sul Mac: dal cask, o a mano (zip, DMG, `install.sh`).
    public enum Source: Equatable {
        case homebrew
        case manual
    }

    /// Cosa fa il bottone quando c'è una versione nuova.
    public enum Action: Equatable {
        /// Lancia `brew` con questi argomenti (senza il binario), poi riavvia l'app.
        case upgradeAndRelaunch(arguments: [String])
        /// Apre la pagina della release nel browser.
        case openReleasePage(URL)
    }

    /// La versione nuova ("1.3.0") se `latestTag` (`v1.3.0` o `1.3.0`) è più recente di `current`;
    /// `nil` se è uguale, più vecchia, o non si legge. Il confronto è numerico per componente:
    /// 1.10.0 batte 1.9.0.
    public static func newerVersion(current: String, latestTag: String) -> String? {
        func components(_ raw: String, acceptsPrefix: Bool) -> [Int]? {
            let version: Substring
            if acceptsPrefix, raw.first == "v" {
                version = raw.dropFirst()
            } else {
                version = raw[...]
            }
            guard !version.isEmpty else { return nil }
            let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
            guard !pieces.isEmpty else { return nil }
            let numbers = pieces.compactMap { piece -> Int? in
                guard !piece.isEmpty, piece.allSatisfy(\.isNumber) else { return nil }
                return Int(piece)
            }
            return numbers.count == pieces.count ? numbers : nil
        }

        guard let installed = components(current, acceptsPrefix: false),
              let released = components(latestTag, acceptsPrefix: true) else { return nil }
        let count = max(installed.count, released.count)
        for index in 0..<count {
            let old = index < installed.count ? installed[index] : 0
            let new = index < released.count ? released[index] : 0
            if new != old { return new > old ? released.map(String.init).joined(separator: ".") : nil }
        }
        return nil
    }

    /// `true` se non c'è mai stato un controllo, o se sono passati almeno `interval` secondi.
    public static func isDue(lastCheck: Date?, now: Date, interval: TimeInterval = 86_400) -> Bool {
        guard let lastCheck else { return true }
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed < 0 || elapsed >= interval
    }

    /// `.homebrew` quando esiste `<root>/<token>/` in una delle radici del Caskroom E il bundle
    /// sta in `/Applications/<Nome>.app` o `~/Applications/<Nome>.app`; altrimenti `.manual`.
    /// `fileExists` è iniettato così il test non tocca il disco.
    public static func source(bundlePath: String,
                              caskroomRoots: [String],
                              homeDirectory: String,
                              token: String = caskToken,
                              fileExists: (String) -> Bool) -> Source {
        let bundle = URL(fileURLWithPath: bundlePath).standardized.path
        let appName = URL(fileURLWithPath: bundle).lastPathComponent
        let systemApp = URL(fileURLWithPath: "/Applications")
            .appendingPathComponent(appName).standardized.path
        let userApp = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent("Applications")
            .appendingPathComponent(appName).standardized.path
        guard bundle == systemApp || bundle == userApp else { return .manual }

        let installed = caskroomRoots.contains { root in
            fileExists(URL(fileURLWithPath: root).appendingPathComponent(token).standardized.path)
        }
        return installed ? .homebrew : .manual
    }

    /// Gli argomenti per `brew`, senza il binario.
    public static func upgradeArguments(token: String = caskToken, tap: String = tap) -> [String] {
        // Niente `--no-quarantine`: Homebrew 6 non ha più quel flag («invalid option», misurato
        // sulla 6.0.20) e lascia comunque il contrassegno sull'app installata. Lo toglie
        // l'`Updater` dal proprio bundle, dopo un upgrade riuscito.
        ["upgrade", "--cask", "\(tap)/\(token)"]
    }

    /// L'azione per una versione nuova, data la provenienza.
    public static func action(for source: Source, version: String, repo: String = repo) -> Action {
        switch source {
        case .homebrew:
            return .upgradeAndRelaunch(arguments: upgradeArguments())
        case .manual:
            return .openReleasePage(
                URL(string: "https://github.com/\(repo)/releases/tag/v\(version)")!
            )
        }
    }

    /// Il `tag_name` dal JSON di `GET /repos/<repo>/releases/latest`; `nil` se manca o non è JSON.
    public static func latestTag(fromReleaseJSON data: Data) -> String? {
        struct Release: Decodable { let tagName: String }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(Release.self, from: data).tagName
    }
}
