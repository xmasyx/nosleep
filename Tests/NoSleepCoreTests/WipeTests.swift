import Testing
import Foundation
@testable import NoSleepCore

/// La pulizia della tastiera, per la parte che è logica pura.
///
/// Il resto — le finestre, il tap, il cane da guardia — si prova con
/// `NoSleepApp --selftest-wipe`, che accende la schermata vera: sono cose che un test unitario
/// non può guardare, ed è meglio dirlo che fingere di provarle qui.
struct WipeTests {

    @Test func leDurateSonoTreENonInfinite() {
        #expect(WipeDuration.allCases.map(\.rawValue) == [60, 120, 300])
        #expect(WipeDuration.allCases.allSatisfy { $0.seconds <= 300 })
    }

    @Test func laCombinazioneDUscitaVuoleTuttiETreIModificatori() {
        let esc = WipeExit.escapeKeyCode
        #expect(WipeExit.matches(keyCode: esc, control: true, option: true, command: true))
        #expect(!WipeExit.matches(keyCode: esc, control: false, option: true, command: true))
        #expect(!WipeExit.matches(keyCode: esc, control: true, option: false, command: true))
        #expect(!WipeExit.matches(keyCode: esc, control: true, option: true, command: false))
        #expect(!WipeExit.matches(keyCode: 0, control: true, option: true, command: true))
    }

    /// La via di fuga del sistema deve restare distinguibile dalla nostra, altrimenti o la
    /// ingoiamo (e togliamo l'ultima porta) o usciamo quando lui voleva il pannello di macOS.
    @Test func lUscitaDiSistemaNonSiConfondeConLaNostra() {
        let esc = WipeExit.escapeKeyCode
        #expect(WipeExit.isForceQuit(keyCode: esc, control: false, option: true, command: true))
        #expect(!WipeExit.isForceQuit(keyCode: esc, control: true, option: true, command: true))
    }

    @Test func ilContoAllaRovesciaNonVaMaiSottoZero() {
        #expect(WipeClock.countdown(remaining: 300) == "05:00")
        #expect(WipeClock.countdown(remaining: 90) == "01:30")
        #expect(WipeClock.countdown(remaining: 0) == "00:00")
        #expect(WipeClock.countdown(remaining: -12) == "00:00")
    }

    @Test func leCitazioniHannoTutteUnAutoreENonSiRipetono() {
        let q = Quotes.all
        #expect(q.count >= 20)
        #expect(Set(q.map(\.text)).count == q.count)
        #expect(q.allSatisfy { !$0.text.isEmpty && !$0.author.isEmpty && !$0.work.isEmpty })
        #expect(Quotes.pick(-1) == q[q.count - 1])
        #expect(Quotes.pick(q.count) == q[0])
    }

    /// ISC-72: la durata è una preferenza, quindi deve sopravvivere alla chiusura dell'app —
    /// **a differenza** delle due prese, che per scelta non si ricordano.
    @Test func laDurataSopravviveAlRiavvio() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nosleep-wipe-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        var c = Config.atBirth
        c.wipeDuration = .five
        c.screenAwake = true
        c.save(to: url)

        let riletta = Config.load(from: url)
        #expect(riletta.wipeDuration == .five)
        #expect(riletta.screenAwake == false, "le prese non si ricordano, la durata sì")
    }

    /// Una configurazione scritta prima che questo campo esistesse non deve far tornare indietro
    /// tutto il resto: è la stessa trappola già pagata con `awakeMode`.
    @Test func unaConfigurazioneVecchiaNonPerdeGliAltriCampi() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nosleep-vecchia-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try #"{"batteryFloor":15,"autoArmOnWork":true,"lidFollowsAwake":true}"#
            .write(to: url, atomically: true, encoding: .utf8)

        let c = Config.load(from: url)
        #expect(c.wipeDuration == .one)
        #expect(c.batteryFloor == 15)
        #expect(c.autoArmOnWork == true)
        #expect(c.lidFollowsAwake == true)
    }
}
