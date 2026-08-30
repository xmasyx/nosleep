import Foundation
import Testing
@testable import NoSleepCore

// Il contratto del modulo aggiornamenti: scritto PRIMA del corpo, e ogni regola ha il suo polo
// negativo. Un confronto di versione che dice «più nuova» a una versione uguale, o un
// riconoscimento di brew che dice sì a un'app sul Desktop, farebbero partire un upgrade su un
// Mac che non lo può eseguire: sono i casi che questo file esiste per bloccare.

@Suite("Updates: versione")
struct UpdatesVersionTests {
    @Test func tagConPrefissoPiuNuovo() {
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "v1.3.0") == "1.3.0")
    }

    @Test func tagSenzaPrefisso() {
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "1.2.1") == "1.2.1")
    }

    @Test func ugualeNonEPiuNuova() {
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "v1.2.0") == nil)
    }

    @Test func piuVecchiaNonEPiuNuova() {
        #expect(Updates.newerVersion(current: "1.3.0", latestTag: "v1.2.9") == nil)
    }

    @Test func confrontoNumericoNonLessicale() {
        // "1.10.0" < "1.9.0" come stringhe, > come numeri.
        #expect(Updates.newerVersion(current: "1.9.0", latestTag: "v1.10.0") == "1.10.0")
        #expect(Updates.newerVersion(current: "1.10.0", latestTag: "v1.9.0") == nil)
    }

    @Test func componentiMancantiValgonoZero() {
        #expect(Updates.newerVersion(current: "1.2", latestTag: "v1.2.1") == "1.2.1")
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "v1.2") == nil)
    }

    @Test func spazzaturaNonEUnaVersione() {
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "garbage") == nil)
        #expect(Updates.newerVersion(current: "dev", latestTag: "v1.3.0") == nil)
        #expect(Updates.newerVersion(current: "1.2.0", latestTag: "") == nil)
    }
}

@Suite("Updates: cadenza")
struct UpdatesCadenceTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func maiControllatoEDovuto() {
        #expect(Updates.isDue(lastCheck: nil, now: now) == true)
    }

    @Test func ventitreOreNonBastano() {
        #expect(Updates.isDue(lastCheck: now.addingTimeInterval(-23 * 3600), now: now) == false)
    }

    @Test func venticinqueOreBastano() {
        #expect(Updates.isDue(lastCheck: now.addingTimeInterval(-25 * 3600), now: now) == true)
    }

    @Test func esattamenteUnGiornoEDovuto() {
        #expect(Updates.isDue(lastCheck: now.addingTimeInterval(-86_400), now: now) == true)
    }

    @Test func unOrologioTornatoIndietroNonBlocca() {
        // Un lastCheck nel futuro (orologio spostato) non deve zittire il controllo per sempre.
        #expect(Updates.isDue(lastCheck: now.addingTimeInterval(+3 * 86_400), now: now) == true)
    }
}

@Suite("Updates: provenienza")
struct UpdatesSourceTests {
    let roots = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
    let home = "/Users/prova"

    private func exists(_ present: Set<String>) -> (String) -> Bool {
        { present.contains($0) }
    }

    @Test func caskroomEBundleInApplications() {
        let s = Updates.source(bundlePath: "/Applications/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists(["/opt/homebrew/Caskroom/nosleep"]))
        #expect(s == .homebrew)
    }

    @Test func secondaRadiceIntel() {
        let s = Updates.source(bundlePath: "/Applications/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists(["/usr/local/Caskroom/nosleep"]))
        #expect(s == .homebrew)
    }

    @Test func applicationsDiCasa() {
        let s = Updates.source(bundlePath: "/Users/prova/Applications/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists(["/opt/homebrew/Caskroom/nosleep"]))
        #expect(s == .homebrew)
    }

    @Test func senzaCaskroomEManuale() {
        let s = Updates.source(bundlePath: "/Applications/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists([]))
        #expect(s == .manual)
    }

    @Test func caskroomDiUnAltraAppNonConta() {
        let s = Updates.source(bundlePath: "/Applications/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists(["/opt/homebrew/Caskroom/kalamos"]))
        #expect(s == .manual)
    }

    @Test func bundleFuoriDaApplicationsEManuale() {
        // Una copia sul Desktop non è quella che brew gestisce, anche se il cask è installato.
        let s = Updates.source(bundlePath: "/Users/prova/Desktop/NoSleep.app",
                               caskroomRoots: roots, homeDirectory: home,
                               fileExists: exists(["/opt/homebrew/Caskroom/nosleep"]))
        #expect(s == .manual)
    }
}

@Suite("Updates: azione")
struct UpdatesActionTests {
    @Test func argomentiEsattiPerBrew() {
        #expect(Updates.upgradeArguments()
                == ["upgrade", "--cask", "xmasyx/tap/nosleep"])
    }

    @Test func daBrewSiAggiornaERiavvia() {
        #expect(Updates.action(for: .homebrew, version: "1.3.0")
                == .upgradeAndRelaunch(arguments: ["upgrade", "--cask", "xmasyx/tap/nosleep"]))
    }

    @Test func aManoSiApreLaPaginaDellaRelease() {
        let url = URL(string: "https://github.com/xmasyx/nosleep/releases/tag/v1.3.0")!
        #expect(Updates.action(for: .manual, version: "1.3.0") == .openReleasePage(url))
    }
}

@Suite("Updates: JSON di GitHub")
struct UpdatesJSONTests {
    @Test func leggeIlTag() {
        let data = Data(#"{"tag_name":"v1.3.0","name":"1.3.0","draft":false}"#.utf8)
        #expect(Updates.latestTag(fromReleaseJSON: data) == "v1.3.0")
    }

    @Test func senzaTagNil() {
        #expect(Updates.latestTag(fromReleaseJSON: Data("{}".utf8)) == nil)
    }

    @Test func nonJSONNil() {
        #expect(Updates.latestTag(fromReleaseJSON: Data("<html>".utf8)) == nil)
    }
}
