import Testing
@testable import NoSleepCore

@Suite("Il registro delle prenotazioni, una riga per cambiamento")
struct LeaseDiffTests {

    private func lease(id: String, takenAt: Double = 80, ttl: Double) -> Lease {
        Lease(id: id, expires: takenAt + ttl, label: "prova", takenAt: takenAt)
    }

    @Test("una prenotazione nuova scrive identificatore e durata")
    func taken() {
        let events = L.$current.withValue(.it) {
            LeaseDiff.events(before: [], after: [lease(id: "a", ttl: 20)], now: 90)
        }
        #expect(events == ["prenotazione presa a (20 s)"])
    }

    @Test("una prenotazione sparita oltre la scadenza è scaduta")
    func expired() {
        let events = L.$current.withValue(.it) {
            LeaseDiff.events(before: [lease(id: "a", ttl: 20)], after: [], now: 101)
        }
        #expect(events == ["prenotazione scaduta a"])
    }

    @Test("una prenotazione sparita prima della scadenza è restituita")
    func returned() {
        let events = L.$current.withValue(.it) {
            LeaseDiff.events(before: [lease(id: "a", ttl: 120)], after: [], now: 101)
        }
        #expect(events == ["prenotazione restituita a"])
    }

    @Test("lo stesso insieme non scrive niente, nemmeno dopo un rinnovo (polo negativo)")
    func renewalIsSilent() {
        let before = [lease(id: "a", ttl: 20)]
        let after = [lease(id: "a", ttl: 40)]
        #expect(LeaseDiff.events(before: before, after: after, now: 90) == [])
    }

    @Test("prese, scadute e restituite hanno ordine deterministico")
    func mixed() {
        let before = [lease(id: "a", ttl: 20), lease(id: "b", ttl: 120)]
        let after = [lease(id: "c", takenAt: 100, ttl: 30)]
        let events = L.$current.withValue(.it) {
            LeaseDiff.events(before: before, after: after, now: 101)
        }
        #expect(events == [
            "prenotazione presa c (30 s)",
            "prenotazione scaduta a",
            "prenotazione restituita b",
        ])
    }

    @Test("esattamente alla scadenza non è più viva ed è scaduta")
    func expiryBoundary() {
        let events = L.$current.withValue(.it) {
            LeaseDiff.events(before: [lease(id: "a", ttl: 20)], after: [], now: 100)
        }
        #expect(events == ["prenotazione scaduta a"])
    }
}
