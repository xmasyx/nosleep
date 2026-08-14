import Foundation
import Testing
@testable import NoSleepCore

// La superficie che l'helper espone da root, e il registro delle prenotazioni.
//
// Questi sono i test che contano di più: qui non si sta provando che una funzione fa la cosa
// giusta, si sta provando che **non la fa** quando l'ingresso è rotto, vecchio o ostile.

@Suite("La richiesta all'helper — tutto ciò che non è un sì fresco è un no")
struct HelperRequestTests {

    private func json(_ s: String) -> Data { Data(s.utf8) }

    @Test("il caso normale: richiesta accesa e battito fresco")
    func freshYes() {
        let d = json("{\"lidAwake\":true,\"heartbeat\":1000}")
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1005) == true)
    }

    @Test("ISC-14 — sei ingressi rotti, sei no")
    func brokenInputsAreNo() {
        let now = 1000.0
        let cases: [Data?] = [
            nil,                                       // file assente
            json(""),                                  // vuoto
            json("non è json"),                        // spazzatura
            json("{}"),                                // campi mancanti
            json("{\"lidAwake\":true}"),               // battito mancante
            json("[1,2,3]"),                           // tipo sbagliato
        ]
        for c in cases {
            #expect(HelperRequest.shouldDisableSleep(rawJSON: c, now: now) == false)
        }
    }

    @Test("ISC-20 — un battito vecchio è un no: è il cane da guardia")
    func staleHeartbeatIsNo() {
        let d = json("{\"lidAwake\":true,\"heartbeat\":1000}")
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1000 + 29) == true)
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1000 + 31) == false)
    }

    @Test("un battito nel futuro è sospetto, non fresco")
    func futureHeartbeatIsNo() {
        let d = json("{\"lidAwake\":true,\"heartbeat\":2000}")
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1000) == false)
        // Due secondi di deriva d'orologio sono tollerati, e non uno di più.
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1999) == true)
    }

    @Test("richiesta spenta con battito fresco: comunque no")
    func explicitOffIsNo() {
        let d = json("{\"lidAwake\":false,\"heartbeat\":1000}")
        #expect(HelperRequest.shouldDisableSleep(rawJSON: d, now: 1001) == false)
    }
}

@Suite("Prenotazioni")
struct LeaseTests {

    private func tempStore() -> LeaseStore {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nosleep-test-\(UUID().uuidString)")
        return LeaseStore(directory: dir)
    }

    @Test("ISC-30 — si prende e si restituisce")
    func holdAndRelease() {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.directory) }
        #expect(s.hold(id: "a", ttl: 60, label: "prova", now: 1000) == true)
        #expect(s.count(now: 1000) == 1)
        #expect(s.release(id: "a") == true)
        #expect(s.count(now: 1000) == 0)
    }

    @Test("ISC-31 — si contano: due sessioni, la prima che esce non azzera")
    func counted() {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.directory) }
        s.hold(id: "uno", ttl: 60, label: "", now: 1000)
        s.hold(id: "due", ttl: 60, label: "", now: 1000)
        #expect(s.count(now: 1000) == 2)
        s.release(id: "uno")
        #expect(s.count(now: 1000) == 1)
    }

    @Test("ISC-32 — una prenotazione scaduta sparisce anche se nessuno l'ha restituita")
    func expiryCollects() {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.directory) }
        s.hold(id: "morta", ttl: 30, label: "", now: 1000)
        #expect(s.count(now: 1029) == 1)
        #expect(s.count(now: 1031) == 0)
        // E il file è stato tolto davvero, non solo scartato dal conteggio.
        let f = s.directory.appendingPathComponent(LeaseStore.fileName(for: "morta"))
        #expect(FileManager.default.fileExists(atPath: f.path) == false)
    }

    @Test("un identificatore ostile non esce dalla cartella")
    func idCannotEscape() {
        let name = LeaseStore.fileName(for: "../../../etc/passwd")
        #expect(name.contains("/") == false)
        #expect(name.contains("..") == false)
        #expect(name.hasSuffix(".json") == true)
    }

    @Test("un file illeggibile non può tenere sveglio il Mac per il fatto di essere rotto")
    func garbageIsNotALease() throws {
        let s = tempStore()
        defer { try? FileManager.default.removeItem(at: s.directory) }
        try FileManager.default.createDirectory(at: s.directory, withIntermediateDirectories: true)
        try Data("spazzatura".utf8).write(to: s.directory.appendingPathComponent("x.json"))
        #expect(s.count(now: 1000) == 0)
    }
}

@Suite("Contrasto — ISC-43")
struct ContrastTests {

    @Test("il testo passa AA su entrambe le facce")
    func textPassesAA() {
        for p in Surface.both {
            #expect(p.text.contrast(with: p.paper) >= 4.5, "testo su \(p.name)")
            #expect(p.text.contrast(with: p.card) >= 4.5, "testo su scheda \(p.name)")
        }
    }

    @Test("il testo tenue e gli accenti passano AA per testo piccolo")
    func dimAndAccentsPassAA() {
        for p in Surface.both {
            #expect(p.dim.contrast(with: p.paper) >= 4.5, "tenue su \(p.name)")
            #expect(p.accent.contrast(with: p.paper) >= 4.5, "accento su \(p.name)")
            #expect(p.active.contrast(with: p.paper) >= 4.5, "attivo su \(p.name)")
        }
    }

    @Test("il polo negativo: un colore sbagliato viene bocciato davvero")
    func gateWouldFail() {
        // Grigio chiaro su carta: sotto AA, e serve a provare che il cancello non dice sempre sì.
        #expect(RGB(hex: "#CCCCCC").contrast(with: Surface.giorno.paper) < 4.5)
    }
}
