import Testing
@testable import NoSleepCore

// I test della politica, che è l'unico posto dove si decide se una presa va aperta o chiusa.
//
// Ogni regola ha il suo **polo negativo**: non basta provare che con l'interruttore acceso succede
// la cosa, bisogna provare che con l'interruttore spento NON succede. Senza il polo negativo, un
// test che dice sempre sì passa lo stesso.

@Suite("Politica — fine del lavoro")
struct PolicyEndOfWorkTests {

    @Test("ISC-33 — l'ultima prenotazione che cade molla entrambe le prese")
    func releasesOnLastLease() {
        let c = Config(screenAwake: true, lidAwake: true, releaseWhenWorkEnds: true)
        let out = Policy.apply(.leases(from: 1, to: 0), to: c)
        #expect(out.config.screenAwake == false)
        #expect(out.config.lidAwake == false)
        #expect(out.note != nil)
    }

    @Test("ISC-34 — con l'interruttore spento le prese restano (polo negativo)")
    func keepsWhenToggleOff() {
        let c = Config(screenAwake: true, lidAwake: true, releaseWhenWorkEnds: false)
        let out = Policy.apply(.leases(from: 1, to: 0), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.config.lidAwake == true)
        #expect(out.changed == false)
    }

    @Test("ISC-31 — da due a una non molla niente: c'è ancora lavoro vivo")
    func twoToOneHoldsOn() {
        let c = Config(screenAwake: true, lidAwake: true, releaseWhenWorkEnds: true)
        let out = Policy.apply(.leases(from: 2, to: 1), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed == false)
    }

    @Test("da zero a zero non è un evento e non scrive una riga di registro")
    func zeroToZeroIsSilent() {
        let c = Config(screenAwake: false, lidAwake: false)
        #expect(Policy.apply(.leases(from: 0, to: 0), to: c).changed == false)
    }
}

@Suite("Politica — accensione automatica")
struct PolicyAutoArmTests {

    @Test("con l'interruttore acceso, la prima prenotazione accende lo schermo")
    func armsOnFirstLease() {
        let c = Config(autoArmOnWork: true)
        let out = Policy.apply(.leases(from: 0, to: 1), to: c)
        #expect(out.config.screenAwake == true)
    }

    @Test("ISC-40 — l'automatico NON accende mai il coperchio (AC-4)")
    func neverArmsLid() {
        let c = Config(autoArmOnWork: true)
        let out = Policy.apply(.leases(from: 0, to: 1), to: c)
        #expect(out.config.lidAwake == false)
    }

    @Test("con l'interruttore spento non accende niente (polo negativo)")
    func doesNotArmWhenOff() {
        let c = Config(autoArmOnWork: false)
        let out = Policy.apply(.leases(from: 0, to: 3), to: c)
        #expect(out.config.screenAwake == false)
        #expect(out.changed == false)
    }
}

@Suite("Politica — il termico vince su tutto")
struct PolicyThermalTests {

    @Test("ISC-22 — a `serious` molla tutto")
    func releasesAtSerious() {
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.thermal(.serious), to: c)
        #expect(out.config.screenAwake == false)
        #expect(out.config.lidAwake == false)
        #expect(out.note?.contains("caldo") == true)
    }

    @Test("a `critical` molla tutto")
    func releasesAtCritical() {
        let c = Config(screenAwake: true, lidAwake: true)
        #expect(Policy.apply(.thermal(.critical), to: c).config.screenAwake == false)
    }

    @Test("a `fair` non tocca niente (polo negativo)")
    func holdsAtFair() {
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.thermal(.fair), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed == false)
    }

    @Test("ISC-23 — il rilascio termico non guarda nessun interruttore di comportamento")
    func thermalIgnoresToggles() {
        // Entrambi gli interruttori di comportamento messi nel verso che direbbe «non mollare».
        let c = Config(screenAwake: true, lidAwake: true,
                       releaseWhenWorkEnds: false, autoArmOnWork: false)
        let out = Policy.apply(.thermal(.serious), to: c)
        #expect(out.config.screenAwake == false)
        #expect(out.config.lidAwake == false)
    }

    @Test("un livello sconosciuto si sbaglia verso il sicuro")
    func unknownIsSafe() {
        #expect(ThermalLevel.serious.forcesRelease == true)
        #expect(ThermalLevel.nominal.forcesRelease == false)
    }
}

@Suite("Stati di nascita")
struct BirthStateTests {

    @Test("ISC-40 — i quattro interruttori nascono come deciso")
    func atBirth() {
        let c = Config.atBirth
        #expect(c.screenAwake == false)
        #expect(c.lidAwake == false)
        #expect(c.releaseWhenWorkEnds == true)   // sua decisione, 2026-08-07
        #expect(c.autoArmOnWork == false)
    }
}

@Suite("Politica — l'automatico acceso a lavoro già in corso")
struct PolicyAutoArmLateTests {

    @Test("acceso mentre un lavoro gira, si attiva subito")
    func armsImmediately() {
        let c = Config(autoArmOnWork: true)
        let out = Policy.apply(.autoArmSwitchedOn(leases: 2), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed)
    }

    @Test("acceso senza lavori in corso non attiva niente (polo negativo)")
    func doesNothingWithoutWork() {
        let c = Config(autoArmOnWork: true)
        #expect(Policy.apply(.autoArmSwitchedOn(leases: 0), to: c).changed == false)
    }

    @Test("non riaccende ciò che è già acceso, e non scrive una riga inutile")
    func idempotent() {
        let c = Config(screenAwake: true, autoArmOnWork: true)
        #expect(Policy.apply(.autoArmSwitchedOn(leases: 3), to: c).changed == false)
    }

    @Test("non tocca mai il coperchio, nemmeno per questa strada (AC-4)")
    func neverLid() {
        let c = Config(autoArmOnWork: true)
        #expect(Policy.apply(.autoArmSwitchedOn(leases: 1), to: c).config.lidAwake == false)
    }
}

@Suite("Politica — le soglie sulla temperatura misurata")
struct PolicyTemperatureTests {

    @Test("batteria oltre soglia: molla tutto")
    func hotBattery() {
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.temperature(board: 40, battery: 46), to: c)
        #expect(out.config.screenAwake == false)
        #expect(out.config.lidAwake == false)
        #expect(out.note?.contains("batteria") == true)
    }

    @Test("il chip caldo NON molla niente: quegli 81 gradi sono normali")
    func hotBoardDoesNothing() {
        // I due casi veri del registro: `board 81` con `thermal "normale"`, cioè macOS non stava
        // nemmeno abbassando le frequenze, e l'app spegneva con quattro lavori in corso. Quel
        // sensore è `PMU tdev7`, due gradi dal die: è il chip, non la scocca.
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.temperature(board: 81, battery: 30), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed == false)
    }

    @Test("nemmeno un die bollente basta da solo: a quello risponde thermalState")
    func veryHotBoardStillDoesNothing() {
        // Apple Silicon sotto carico sta a cento gradi ed è normale, perché si difende da sé
        // abbassando le frequenze. Se il sistema è davvero in difficoltà lo dice `ThermalLevel`,
        // ed è quella la strada che molla la presa.
        let c = Config(screenAwake: true, lidAwake: true)
        #expect(Policy.apply(.temperature(board: 105, battery: 30), to: c).changed == false)
    }

    @Test("una normale ricostruzione dell'app NON deve far scattare la rete")
    func ordinaryBuildIsFine() {
        // I gradi misurati sul suo Mac il 7/08 mentre girava `build-app.sh`.
        let c = Config(screenAwake: true, lidAwake: true)
        #expect(Policy.apply(.temperature(board: 60, battery: 31), to: c).changed == false)
    }

    @Test("temperature normali: non tocca niente (polo negativo)")
    func normalTemps() {
        // I valori veri letti sul suo Mac il 7/08 a Mac fermo.
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.temperature(board: 46, battery: 35), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed == false)
    }

    @Test("sensori muti non sono un Mac caldo (polo negativo che conta)")
    func missingSensorsDoNothing() {
        let c = Config(screenAwake: true, lidAwake: true)
        let out = Policy.apply(.temperature(board: nil, battery: nil), to: c)
        #expect(out.config.screenAwake == true)
        #expect(out.changed == false)
    }

    @Test("un solo sensore basta, se è quello oltre soglia")
    func oneSensorIsEnough() {
        let c = Config(screenAwake: true, lidAwake: true)
        #expect(Policy.apply(.temperature(board: nil, battery: 50), to: c).changed)
    }
}

@Suite("Addormentare davvero, non solo mollare la presa")
struct SleepDecisionTests {

    /// Si chiede alla funzione che gira davvero nell'app, `verdict`, e non a una scorciatoia
    /// scritta per i test: una prova che passa da un'altra porta non prova la porta che si usa.
    ///
    /// L'inattività non passata vale «da sempre fermo», e il respiro è già stato aspettato: così
    /// ogni prova che non parla di lui alla tastiera misura la condizione che dichiara.
    private func d(lid: Bool = true, leases: Int = 0, screen: Bool = false,
                   lidAwake: Bool = false, release: Bool = true,
                   idle: Double = .infinity, audio: Bool = false,
                   sinceWake: Double = .infinity, caffeinated: Bool = false) -> Bool {
        SleepDecision.verdict(lidClosed: lid, leases: leases, screenAwake: screen,
                              lidAwake: lidAwake, releaseWhenWorkEnds: release,
                              pendingFor: SleepDecision.grace, userIdle: idle,
                              audioPlaying: audio, sinceWake: sinceWake,
                              caffeinated: caffeinated) == .sleepNow
    }

    @Test("il caso per cui esiste: coperchio chiuso, lavoro finito, NoSleep spento")
    func theCase() { #expect(d() == true) }

    @Test("a coperchio alzato con lui alla tastiera non si addormenta mai (il polo che conta)")
    func neverUnderHisHands() {
        #expect(d(lid: false, idle: 0) == false)
        #expect(d(lid: false, idle: SleepDecision.idleThreshold - 1) == false)
    }

    @Test("a coperchio alzato e Mac lasciato stare, si addormenta (sua scelta, 19/08)")
    func lidOpenButNobodyThere() {
        #expect(d(lid: false, idle: SleepDecision.idleThreshold) == true)
    }

    @Test("a coperchio chiuso l'inattività non c'entra: il gesto ha già parlato")
    func lidClosedIgnoresIdle() { #expect(d(lid: true, idle: 0) == true) }

    @Test("a coperchio alzato non si interrompe quello che sta suonando")
    func neverDuringPlayback() { #expect(d(lid: false, audio: true) == false) }

    @Test("a coperchio alzato non si riaddormenta un Mac appena svegliato")
    func neverRightAfterWake() {
        #expect(d(lid: false, sinceWake: SleepDecision.wakeGuard - 1) == false)
        #expect(d(lid: false, sinceWake: SleepDecision.wakeGuard) == true)
    }

    @Test("a coperchio chiuso i due veti non valgono: era il caso di coreaudiod")
    func lidClosedIgnoresVetoes() {
        #expect(d(lid: true, idle: 0, audio: true, sinceWake: 0) == true)
    }

    @Test("se nel frattempo è ripartito un lavoro, si annulla")
    func workRestarted() { #expect(d(leases: 1) == false) }

    @Test("se qualcuno ha riacceso NoSleep durante l'attesa, si annulla")
    func rearmed() {
        #expect(d(screen: true) == false)
        #expect(d(lidAwake: true) == false)
    }

    @Test("se l'interruttore è stato spento durante l'attesa, la decisione decade")
    func toggleTurnedOff() { #expect(d(release: false) == false) }

    @Test("l'attesa è di tre minuti, non trenta secondi")
    func graceIsReal() { #expect(SleepDecision.grace >= 120) }

    @Test("la soglia di inattività è quella che gli ho promesso: cinque minuti")
    func idleThresholdIsFiveMinutes() { #expect(SleepDecision.idleThreshold == 300) }

    private func v(pendingFor: Double, idle: Double = .infinity, lid: Bool = false,
                   caffeinated: Bool = false) -> SleepDecision.Verdict {
        SleepDecision.verdict(lidClosed: lid, leases: 0, screenAwake: false, lidAwake: false,
                              releaseWhenWorkEnds: true, pendingFor: pendingFor, userIdle: idle,
                              audioPlaying: false, sinceWake: .infinity,
                              caffeinated: caffeinated)
    }

    @Test("prima del respiro si aspetta, anche se tutto il resto è a posto")
    func graceIsWaited() { #expect(v(pendingFor: SleepDecision.grace - 1) == .wait) }

    @Test("un'attesa che non trova mai il suo momento invecchia e cade")
    func pendingExpires() {
        #expect(v(pendingFor: SleepDecision.pendingMaxAge - 1) == .sleepNow)
        #expect(v(pendingFor: SleepDecision.pendingMaxAge + 1) == .cancel)
    }

    @Test("con lui alla tastiera l'attesa resta in attesa, non si butta")
    func staysPendingWhileHeIsThere() { #expect(v(pendingFor: 60, idle: 10) == .wait) }

    @Test("il caffeinate di Claude Code è ancora vivo: si aspetta, coperchio chiuso (06:54 del 28/08)")
    func caffeinateWaitsWithLidClosed() {
        #expect(v(pendingFor: SleepDecision.grace, lid: true, caffeinated: true) == .wait)
    }

    @Test("senza caffeinate il coperchio chiuso addormenta (polo negativo)")
    func noCaffeinateSleepsWithLidClosed() {
        #expect(d(lid: true, caffeinated: false))
    }

    @Test("il caffeinate aspetta anche a coperchio alzato e Mac lasciato stare")
    func caffeinateWaitsWithLidOpen() {
        #expect(v(pendingFor: SleepDecision.grace,
                  idle: SleepDecision.idleThreshold,
                  caffeinated: true) == .wait)
    }

    @Test("il caffeinate tiene l'attesa armata, non la annulla, su entrambe le porte")
    func caffeinateNeverCancels() {
        #expect(v(pendingFor: 60, caffeinated: true) == .wait)
        #expect(v(pendingFor: 60, lid: true, caffeinated: true) == .wait)
    }
}

@Suite("Le parole del sonno")
struct SleepWordsTests {

    @Test("i minuti interi sono detti in minuti, al singolare e al plurale")
    func wholeMinutes() {
        #expect(S.sleepScheduled(60) == "va in sleep fra 1 minuto")
        #expect(S.sleepScheduled(180) == "va in sleep fra 3 minuti")
    }

    @Test("i secondi non interi restano secondi (polo negativo)")
    func nonWholeMinutesStaySeconds() {
        #expect(S.sleepScheduled(61) == "va in sleep fra 61 secondi")
    }
}

@Suite("Politica — la soglia di batteria")
struct PolicyBatteryTests {

    private let acceso = Config(screenAwake: true, lidAwake: true)

    @Test("sotto la soglia, a batteria: molla tutto")
    func belowFloor() {
        let out = Policy.apply(.battery(percent: 18, onAC: false), to: acceso)
        #expect(out.config.screenAwake == false)
        #expect(out.config.lidAwake == false)
        #expect(out.note?.contains("18%") == true)
    }

    @Test("esattamente alla soglia molla: 20 vuol dire «da 20 in giù»")
    func atFloor() { #expect(Policy.apply(.battery(percent: 20, onAC: false), to: acceso).changed) }

    @Test("sopra la soglia non tocca niente (polo negativo)")
    func aboveFloor() {
        #expect(Policy.apply(.battery(percent: 21, onAC: false), to: acceso).changed == false)
    }

    @Test("a CORRENTE la soglia non si applica mai: la carica sale, non scende")
    func neverOnAC() {
        #expect(Policy.apply(.battery(percent: 5, onAC: true), to: acceso).changed == false)
    }

    @Test("con l'interruttore spento non molla nemmeno al 3%")
    func disabled() {
        var c = acceso; c.batteryFloorOn = false
        #expect(Policy.apply(.battery(percent: 3, onAC: false), to: c).changed == false)
    }

    @Test("su una macchina senza batteria non succede niente")
    func noBattery() {
        #expect(Policy.apply(.battery(percent: nil, onAC: false), to: acceso).changed == false)
    }

    @Test("la soglia nasce a 20 ed è modificabile fra cinque valori")
    func birthValue() {
        #expect(Config.atBirth.batteryFloor == 20)
        #expect(Config.atBirth.batteryFloorOn == true)
        #expect(Config.batteryFloorChoices.contains(20))
    }
}

/// Il coperchio che segue «tieni sveglio» (2026-08-11, sua richiesta).
///
/// **Perché la regola prepara invece di reagire.** Abbassato il coperchio, macOS addormenta il Mac
/// in una frazione di secondo, mentre il giro dell'app passa ogni cinque: accorgersene dopo vuol
/// dire accorgersene da spenti. L'unico istante utile è prima, quindi il coperchio si arma insieme
/// a «tieni sveglio».
@Suite("Il coperchio che segue")
struct LidFollowTests {

    private var conRegola: Config {
        var c = Config.atBirth
        c.lidFollowsAwake = true
        return c
    }

    @Test("acceso «tieni sveglio», il coperchio si arma")
    func armsOnEdge() {
        var c = conRegola; c.screenAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: false, armed: false, helperInstalled: true)
        #expect(e.config.lidAwake)
        #expect(e.armed)
        #expect(e.note == S.lidArmed)
    }

    @Test("senza la regola non si arma niente (polo negativo)")
    func neverWithoutTheSwitch() {
        var c = Config.atBirth; c.screenAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: false, armed: false, helperInstalled: true)
        #expect(e.config.lidAwake == false)
        #expect(e.changed == false)
    }

    @Test("senza il permesso di amministratore non si arma, e non si scrive niente")
    func needsHelper() {
        var c = conRegola; c.screenAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: false, armed: false, helperInstalled: false)
        #expect(e.config.lidAwake == false)
        #expect(e.changed == false)
    }

    /// Il cuore della regola: **fronte, non stato**. Senza questo, il coperchio spento a mano
    /// tornerebbe acceso mezzo secondo dopo, e l'app combatterebbe contro il dito di chi la usa.
    @Test("spento a mano mentre «tieni sveglio» è acceso, NON si riarma")
    func doesNotFightTheHand() {
        var c = conRegola; c.screenAwake = true; c.lidAwake = false
        let e = Policy.lidFollow(config: c, screenAwakeWas: true, armed: false, helperInstalled: true)
        #expect(e.config.lidAwake == false)
        #expect(e.changed == false)
    }

    @Test("spento «tieni sveglio», il coperchio armato da noi si molla")
    func disarmsWithAwake() {
        var c = conRegola; c.screenAwake = false; c.lidAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: true, armed: true, helperInstalled: true)
        #expect(e.config.lidAwake == false)
        #expect(e.armed == false)
        #expect(e.note == S.lidDisarmed)
    }

    @Test("un coperchio acceso A MANO non si spegne quando «tieni sveglio» si spegne")
    func leavesTheHandAlone() {
        var c = conRegola; c.screenAwake = false; c.lidAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: true, armed: false, helperInstalled: true)
        #expect(e.config.lidAwake)
        #expect(e.changed == false)
    }

    @Test("spenta la regola, quello che aveva armato lei si molla")
    func disarmsWhenSwitchedOff() {
        var c = Config.atBirth; c.screenAwake = true; c.lidAwake = true
        let e = Policy.lidFollow(config: c, screenAwakeWas: true, armed: true, helperInstalled: true)
        #expect(e.config.lidAwake == false)
        #expect(e.armed == false)
    }

    /// Le reti di sicurezza restano sopra a tutto: se il termico ha già mollato il coperchio, la
    /// memoria si azzera invece di restare a dire che lì c'è ancora qualcosa di nostro.
    @Test("se il coperchio è già caduto per altra via, la memoria si azzera")
    func forgetsWhatIsGone() {
        var c = conRegola; c.screenAwake = true; c.lidAwake = false
        let e = Policy.lidFollow(config: c, screenAwakeWas: true, armed: true, helperInstalled: true)
        #expect(e.armed == false)
        #expect(e.changed == false)
    }

    @Test("nasce spento: il coperchio ha un costo fisico e non si arma senza che l'abbia chiesto")
    func bornOff() {
        #expect(Config.atBirth.lidFollowsAwake == false)
    }

    @Test("il termico molla tutto anche col coperchio armato: le reti restano sopra")
    func thermalStillWins() {
        var c = conRegola; c.screenAwake = true; c.lidAwake = true
        let e = Policy.apply(.thermal(.serious), to: c)
        #expect(e.config.screenAwake == false)
        #expect(e.config.lidAwake == false)
    }
}

/// Il ritorno dopo la soglia di batteria (2026-08-30, difetto visto dal vivo).
///
/// **Il caso vero.** Alle 00:13 il Mac era a batteria al 15% con tre prenotazioni vive: la rete di
/// sicurezza ha mollato, giustamente. Riattaccata la corrente, NoSleep è rimasto spento mentre i
/// terminali lavoravano, perché l'automatismo del lavoro si arma sul **fronte** zero → qualcosa e
/// quel conteggio non è più tornato a zero. La riparazione non è un fronte in più: è che chi ha
/// spento si ricordi di riaccendere.
@Suite("Politica — la batteria restituisce ciò che ha preso")
struct PolicyBatteryReturnTests {

    /// Spento dalla soglia, con lavoro in corso: è lo stato in cui l'app si era piantata.
    private var indebitato: Config {
        var c = Config(screenAwake: false, lidAwake: false)
        c.autoArmOnWork = true
        return c
    }

    private func ritorno(_ c: Config, percent: Int?, onAC: Bool, leases: Int = 3,
                         thermal: Bool = false, held: Bool = true) -> BatteryReturnOutcome {
        Policy.batteryReturn(config: c, percent: percent, onAC: onAC,
                             leases: leases, thermalBites: thermal, held: held)
    }

    @Test("la corrente torna e il lavoro c'è ancora: riaccende")
    func onACRearms() {
        let out = ritorno(indebitato, percent: 7, onAC: true)
        #expect(out.config.screenAwake)
        #expect(out.held == false)
        #expect(out.note == S.rearmedBattery)
    }

    @Test("la carica risale sopra la soglia, ancora a batteria: riaccende lo stesso")
    func chargeRecovered() {
        #expect(ritorno(indebitato, percent: 40, onAC: false).config.screenAwake)
    }

    @Test("la soglia morde ancora: non riaccende e il debito resta (polo negativo)")
    func stillBiting() {
        let out = ritorno(indebitato, percent: 12, onAC: false)
        #expect(out.changed == false)
        #expect(out.config.screenAwake == false)
        #expect(out.held, "il debito va tenuto finché la soglia morde")
    }

    @Test("senza debito non riaccende mai: uno spegnimento a mano resta spento (polo negativo)")
    func neverWithoutDebt() {
        let out = ritorno(indebitato, percent: 90, onAC: true, held: false)
        #expect(out.changed == false)
        #expect(out.config.screenAwake == false)
    }

    @Test("il Mac scotta: la rete termica passa davanti, il debito resta (polo negativo)")
    func thermalWinsAndKeepsDebt() {
        let out = ritorno(indebitato, percent: 90, onAC: true, thermal: true)
        #expect(out.changed == false)
        #expect(out.held, "raffreddandosi il debito con la batteria è ancora aperto")
    }

    @Test("nessun lavoro in corso: non riaccende, e il debito si consuma")
    func noWorkConsumesDebt() {
        let out = ritorno(indebitato, percent: 90, onAC: true, leases: 0)
        #expect(out.changed == false)
        #expect(out.held == false, "il fronte zero → qualcosa penserà al lavoro nuovo")
    }

    @Test("con l'automatismo spento non riaccende, e il debito si consuma (polo negativo)")
    func autoArmOff() {
        var c = indebitato; c.autoArmOnWork = false
        let out = ritorno(c, percent: 90, onAC: true)
        #expect(out.changed == false)
        #expect(out.held == false)
    }

    @Test("riacceso a mano nel frattempo: non scrive niente e il debito si chiude")
    func alreadyOnByHand() {
        var c = indebitato; c.screenAwake = true
        let out = ritorno(c, percent: 90, onAC: true)
        #expect(out.changed == false)
        #expect(out.held == false)
    }

    @Test("la catena intera del 30/08: molla al 15%, la corrente torna, riaccende")
    func fullChain() {
        var c = Config(screenAwake: true, lidAwake: true)
        c.batteryFloor = 15
        c.autoArmOnWork = true

        // Tre prenotazioni vive, la carica tocca il pavimento.
        #expect(Policy.batteryFloorBites(c, percent: 15, onAC: false))
        let mollato = Policy.apply(.battery(percent: 15, onAC: false), to: c)
        #expect(mollato.config.screenAwake == false)

        // Il fronte del lavoro NON ricapita: le prenotazioni non sono mai passate da zero.
        #expect(Policy.apply(.leases(from: 3, to: 4), to: mollato.config).changed == false,
                "è questa la ragione per cui il Mac restava spento")

        // La corrente torna: chi ha spento riaccende.
        let out = ritorno(mollato.config, percent: 7, onAC: true, leases: 4)
        #expect(out.config.screenAwake)
        #expect(out.note == S.rearmedBattery)
    }
}
