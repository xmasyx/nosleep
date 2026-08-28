import Testing
import Foundation
@testable import NoSleepCore

/// La battuta di caccia: decine di migliaia di stati tirati a caso, e certe cose che non devono
/// succedere **mai**.
///
/// **Perché accanto ai test a esempio, e non al posto loro.** Un test a esempio dice «in questo
/// caso deve fare così», e copre i casi a cui qualcuno ha pensato. Questo dice «in nessun caso deve
/// fare così», e trova quelli a cui non ha pensato nessuno: è nato il 19/08 come sonda usa-e-getta
/// dopo la modifica sul sonno imposto, ed è entrato qui perché il suo valore è ripetersi.
///
/// **Il seme è fisso**, quindi un difetto trovato oggi si rigioca domani identico. E la caccia è
/// stata provata rompendo il codice di proposito: tolta la porta dell'inattività escono 60.072
/// violazioni, tolti i due veti ne escono 283, storpiato il termico compaiono le sue due famiglie.
/// Una caccia che non ha mai visto il rosso non è una caccia.
@Suite("La battuta di caccia sul nucleo puro")
struct CacciaTests {

    private final class Dado {
        private var seme: UInt64 = 0x5eed_1234
        func tira() -> UInt64 { seme ^= seme << 13; seme ^= seme >> 7; seme ^= seme << 17; return seme }
        func bool() -> Bool { tira() % 2 == 0 }
        func fra(_ a: Int, _ b: Int) -> Int { a + Int(tira() % UInt64(b - a + 1)) }
        func reale(_ a: Double, _ b: Double) -> Double {
            a + Double(tira() % 100_000) / 100_000 * (b - a)
        }
        func config() -> Config {
            Config(screenAwake: bool(), awakeMode: bool() ? .screenAndActivity : .activityOnly,
                   lidAwake: bool(), releaseWhenWorkEnds: bool(), autoArmOnWork: bool(),
                   lidFollowsAwake: bool(), batteryFloorOn: bool(), batteryFloor: fra(0, 100))
        }
    }

    private let giri = 20_000

    @Test("il sonno imposto non scatta mai fuori dalle sue condizioni")
    func sonnoImposto() {
        let d = Dado()
        for _ in 0..<giri {
            let lid = d.bool(), leases = d.fra(0, 3), screen = d.bool(), lidA = d.bool()
            let rel = d.bool(), audio = d.bool(), caffe = d.bool()
            let pending = d.reale(-10, 9000), idle = d.reale(0, 1200)
            let risveglio = d.reale(0, 300), grace = d.reale(0, 60)
            let v = SleepDecision.verdict(lidClosed: lid, leases: leases, screenAwake: screen,
                                          lidAwake: lidA, releaseWhenWorkEnds: rel,
                                          pendingFor: pending, userIdle: idle,
                                          audioPlaying: audio, sinceWake: risveglio,
                                          caffeinated: caffe, grace: grace)
            guard v == .sleepNow else { continue }
            #expect(leases == 0, "addormenta con \(leases) lavori vivi")
            #expect(!screen && !lidA, "addormenta con una presa ancora viva")
            #expect(rel, "addormenta con l'interruttore spento")
            #expect(pending >= grace, "addormenta prima del respiro")
            #expect(pending <= SleepDecision.pendingMaxAge, "addormenta con un'attesa scaduta")
            #expect(!caffe, "addormenta con il caffeinate di Claude Code ancora vivo")
            guard !lid else { continue }
            #expect(idle >= SleepDecision.idleThreshold, "addormenta con lui alla tastiera")
            #expect(!audio, "addormenta mentre qualcosa sta suonando")
            #expect(risveglio >= SleepDecision.wakeGuard, "addormenta appena svegliato")
        }
    }

    @Test("un'attesa non si butta finché le sue condizioni ci sono")
    func attesaNonSiButta() {
        let d = Dado()
        for _ in 0..<giri {
            let pending = d.reale(0, SleepDecision.pendingMaxAge)
            let v = SleepDecision.verdict(lidClosed: d.bool(), leases: 0, screenAwake: false,
                                          lidAwake: false, releaseWhenWorkEnds: true,
                                          pendingFor: pending, userIdle: d.reale(0, 1200),
                                          audioPlaying: d.bool(), sinceWake: d.reale(0, 300),
                                          caffeinated: d.bool())
            #expect(v != .cancel, "butta l'attesa mentre le condizioni ci sono ancora")
        }
    }

    @Test("le due reti di sicurezza non hanno un interruttore che le spenga")
    func retiDiSicurezza() {
        let d = Dado()
        for _ in 0..<giri {
            let c = d.config()
            for livello in [ThermalLevel.serious, .critical] {
                let dopo = Policy.apply(.thermal(livello), to: c).config
                #expect(!dopo.screenAwake && !dopo.lidAwake, "il Mac scotta e una presa è viva")
            }
            let uno = Policy.apply(.thermal(.critical), to: c).config
            #expect(!Policy.apply(.thermal(.critical), to: uno).changed,
                    "il termico applicato due volte cambia ancora qualcosa")
        }
    }

    @Test("niente si accende o si spegne da solo se il suo interruttore è spento")
    func nienteDaSolo() {
        let d = Dado()
        for _ in 0..<giri {
            var senzaAuto = d.config()
            senzaAuto.autoArmOnWork = false
            let dopo = Policy.apply(.leases(from: 0, to: d.fra(1, 3)), to: senzaAuto).config
            #expect(dopo.screenAwake == senzaAuto.screenAwake, "acceso da solo con l'automatismo spento")

            var senzaRilascio = d.config()
            senzaRilascio.releaseWhenWorkEnds = false
            let poi = Policy.apply(.leases(from: 2, to: 0), to: senzaRilascio).config
            #expect(poi == senzaRilascio, "ha mollato con «disattiva quando il lavoro finisce» spento")
        }
    }

    @Test("la batteria: alla corrente non molla mai, e mai senza sapere la carica")
    func batteria() {
        let d = Dado()
        for _ in 0..<giri {
            let c = d.config()
            let p = d.fra(0, 100)
            #expect(!Policy.apply(.battery(percent: p, onAC: true), to: c).changed,
                    "ha mollato mentre il Mac è alla corrente")
            #expect(!Policy.apply(.battery(percent: nil, onAC: false), to: c).changed,
                    "ha deciso senza sapere la carica")
            let scarico = Policy.apply(.battery(percent: p, onAC: false), to: c).config
            if scarico != c {
                #expect(c.batteryFloorOn && p <= c.batteryFloor, "ha mollato sopra la soglia")
            }
        }
    }

    @Test("la configurazione sopravvive al giro sul disco")
    func configSulDisco() throws {
        let d = Dado()
        for _ in 0..<200 {
            let c = d.config()
            let riletta = try JSONDecoder().decode(Config.self, from: JSONEncoder().encode(c))
            #expect(riletta == c, "la configurazione cambia passando dal disco")
        }
    }
}
