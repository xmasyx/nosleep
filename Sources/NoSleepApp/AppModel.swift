import Foundation
import SwiftUI
import IOKit.ps
import NoSleepCore

/// Il cuore dell'app: un giro ogni cinque secondi che guarda il mondo, applica la politica e
/// batte il cuore all'helper.
///
/// Un giro solo, non tre timer diversi: leggere le prenotazioni, guardare il termico e battere
/// devono avvenire nello stesso istante, altrimenti la decisione si prende su tre fotografie
/// scattate in tre momenti e nessuno capisce più perché una presa si è aperta.
@MainActor
final class AppModel: ObservableObject {

    @Published private(set) var config: Config
    @Published private(set) var leaseCount: Int = 0
    @Published private(set) var thermal: ThermalLevel = .nominal
    @Published private(set) var helperInstalled: Bool = false
    /// Lo stato **reale** letto dal sistema, che può differire da quello voluto per un giro.
    @Published private(set) var lidAwakeReal: Bool = false
    /// L'ultima lettura del termometro. `nil` quando i sensori non rispondono, e quel `nil` non è
    /// mai un motivo per mollare: un sensore muto non è un Mac caldo.
    @Published private(set) var temp: Thermometer.Reading = .init(die: nil, board: nil, battery: nil)
    /// Chi altro impedisce il sonno, quando NoSleep non c'entra.
    ///
    /// **Fuori dal pannello dal 2026-08-07**, per sua richiesta e con ragione: il nome vero di
    /// quelle asserzioni è roba come `osservice<com.example.qualcosa(501)>408-781-36299:
    /// com.apple.CFNetwork.StorageDB`, che occupa tre righe e non dice niente a chi legge. La
    /// lettura resta qui e finisce nel registro, dove serve a capire dopo, invece che nel pannello,
    /// dove era solo rumore. Il mistero che l'aveva motivata, `coreaudiod` per nove ore, adesso è
    /// risolto e documentato.
    @Published private(set) var altri: [OtherHolders.Holder] = []
    /// Se il Mac è a corrente adesso: cambia quale asserzione è viva e che cosa dice il pannello.
    @Published private(set) var onAC: Bool = false
    /// L'ultima cosa che è successa da sola, da mostrare nel menu.
    @Published private(set) var lastNote: String?
    @Published var installMessage: String?
    /// La carica della batteria, quando c'è una batteria.
    @Published private(set) var batteryPercent: Int?
    @Published private(set) var launchesAtLogin: Bool = false

    private let assertion = PowerAssertion()
    /// Com'era «tieni sveglio» all'ultimo giro, per riconoscere il fronte che arma il coperchio.
    private var screenAwakeWas = false
    /// Il coperchio acceso è opera nostra? Solo allora possiamo spegnerlo noi.
    private var lidArmedByUs = false

    /// Da dove viene il livello termico.
    ///
    /// È una variabile e non una chiamata diretta **per una sola ragione**: senza questo seam, la
    /// catena app → politica → asserzioni si potrebbe provare solo scaldando davvero il Mac fino a
    /// `serious`, cioè mai. Con il seam, il banco `--selftest-thermal` inietta il livello e guarda
    /// se le asserzioni cadono per davvero. In esercizio nessuno la tocca.
    var thermalSource: () -> ThermalLevel = {
        ThermalLevel.from(processInfo: ProcessInfo.processInfo.thermalState)
    }

    /// Quello che l'app sta davvero tenendo, letto dall'oggetto che lo tiene. Serve al banco.
    var isActuallyHolding: Bool { assertion.held }
    private let leases = LeaseStore(directory: Paths.leases())
    private var timer: Timer?
    private var previousLeaseCount = 0
    /// Quando è stata armata l'attesa di addormentare, se ce n'è una. **Non è un timer**: un timer
    /// decide una volta sola e a coperchio alzato la condizione che conta — che lui abbia lasciato
    /// stare il Mac — arriva quando vuole lei, magari venti minuti dopo. L'attesa vive qui e viene
    /// rivalutata dal giro da cinque secondi, come tutto il resto.
    private var pendingSleepSince: Double?
    /// Che cosa fare per addormentare, e quanto aspettare. Iniettabili per i banchi: un banco che
    /// per provarsi deve addormentare davvero il Mac non lo lancia nessuno, quindi non proverebbe
    /// niente.
    var sleepAction: () -> Void = {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["sleepnow"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
    var grace: Double = SleepDecision.grace
    /// Da quanto tempo nessuno tocca il Mac. Iniettabile per la stessa ragione del termico: un
    /// banco che per provarsi deve stare fermo cinque minuti non lo lancia nessuno.
    var userIdleSource: () -> Double = { PowerAssertion.userIdleSeconds() }
    /// La soglia di inattività, sfilabile solo dai banchi.
    var idleThreshold: Double = SleepDecision.idleThreshold
    /// Da dove viene la lettura dei gradi. Iniettabile per la stessa ragione di `thermalSource`:
    /// un banco che vuole provare UNA regola deve poter mettere a tacere le altre.
    var temperatureSource: () -> Thermometer.Reading = { Thermometer.read() }

    init() {
        Paths.ensureSupport()
        config = Config.load(from: Paths.config())
        helperInstalled = HelperControl.isInstalled
        // Si registra all'accesso alla prima apertura, e mai più: se l'utente la toglie, resta tolta.
        if Paths.homeOverride == nil { LoginItem.registerOnceIfNeeded(marker: Paths.firstRunMarker()) }
        launchesAtLogin = LoginItem.isEnabled
        // La sonda della barra deve mostrare uno stato attivo, e si vede solo tenendo sveglio in
        // «solo attività». Lo stato vive nella casa della sonda, non nella sua: `homeOverride` è
        // già stato messo prima che questo oggetto nascesse.
        if ShotDelegate.wantsAwake {
            config.screenAwake = true
            config.awakeMode = .activityOnly
        }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        observePowerSource()
    }

    /// Attaccare o staccare l'alimentatore deve cambiare il pannello **subito**.
    ///
    /// Col solo giro da cinque secondi il testo restava indietro, e chi guarda legge quel ritardo
    /// come «non funziona» invece che «aspetta un attimo» (sua osservazione, 2026-08-07). IOKit ha
    /// una notifica apposta e costa una riga.
    private func observePowerSource() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ raw in
            guard let raw else { return }
            let me = Unmanaged<AppModel>.fromOpaque(raw).takeUnretainedValue()
            Task { @MainActor in me.tick() }
        }, ctx)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        powerSource = src
    }
    private var powerSource: CFRunLoopSource?

    // ── Il giro ──────────────────────────────────────────────────────────────

    /// Un giro, forzato. Serve al banco per non dover aspettare cinque secondi.
    func tickNow() { tick() }

    /// Solo per i banchi: simula la fine del lavoro senza dover creare e far scadere prenotazioni.
    func simulateWorkEnded() { apply(.leases(from: 1, to: 0)) }

    private func tick() {
        let now = Date().timeIntervalSince1970
        let count = leases.count(now: now)
        let level = thermalSource()

        // Prima si aggiorna la fotografia del mondo, poi si decide: una riga di registro scritta
        // durante la decisione deve dire quante prenotazioni ci sono ADESSO, non quante ce n'erano
        // al giro prima. Con l'ordine rovesciato il registro diceva «rilasciato: il lavoro è
        // finito, prenotazioni: 1», che è la contraddizione che fa dubitare di tutto il file.
        thermal = level
        leaseCount = count

        // Il termometro prima della pressione termica: sono due domande diverse e la notte del
        // 7/08 hanno dato due risposte diverse. Nessuna delle due può essere spenta da un
        // interruttore.
        let lettura = temperatureSource()
        temp = lettura
        apply(.temperature(board: lettura.board, battery: lettura.battery))

        // Il termico vince su tutto, e va valutato per primo: se il Mac scotta, il fatto che sia
        // appena partito un lavoro non deve poter riaccendere niente nello stesso giro.
        apply(.thermal(level))
        apply(.battery(percent: batteryPercent, onAC: onAC))
        if count != previousLeaseCount {
            apply(.leases(from: previousLeaseCount, to: count))
            previousLeaseCount = count
        }

        // Dopo la politica, non prima: l'attesa deve vedere la configurazione di adesso, compreso
        // un «tieni sveglio» appena riacceso da un lavoro nuovo.
        evaluatePendingSleep(now: now, leases: count)

        refresh()
    }

    private func apply(_ event: PolicyEvent) {
        let outcome = Policy.apply(event, to: config)
        guard outcome.changed else { return }
        config = outcome.config
        lastNote = outcome.note
        persist()
        record(outcome.note ?? "cambio")

        // Se a mollare la presa è stata la **fine del lavoro** e il coperchio è abbassato, mollare
        // non basta: qualcun altro può tenere sveglio il Mac per ore mentre lui non può vederlo.
        if outcome.note == S.releasedWorkDone { armPendingSleep() }
    }

    // ── Addormentare davvero ─────────────────────────────────────────────────

    /// Arma l'attesa. Da qui in poi decide `evaluatePendingSleep`, giro per giro.
    private func armPendingSleep() {
        pendingSleepSince = Date().timeIntervalSince1970
        let chiuso = PowerAssertion.isClamshellClosed()
        lastNote = chiuso ? S.sleepScheduled(Int(grace)) : S.sleepWhenIdle(Int(idleThreshold / 60))
        record(chiuso ? S.logSleepScheduled : S.logSleepPendingIdle)
    }

    /// Il verdetto, a ogni giro, sulle condizioni di **adesso**.
    ///
    /// A coperchio alzato la porta è l'inattività, e l'inattività non ha un'ora: per questo l'attesa
    /// non può essere un timer che decide una volta sola. Lui finisce il lavoro, continua a
    /// scrivere, e mezz'ora dopo si alza: è quello il momento, e nessun timer armato prima lo sa.
    private func evaluatePendingSleep(now: Double, leases count: Int) {
        guard let since = pendingSleepSince else { return }
        let idle = userIdleSource()
        let verdetto = SleepDecision.verdict(lidClosed: PowerAssertion.isClamshellClosed(),
                                             leases: count,
                                             screenAwake: config.screenAwake,
                                             lidAwake: config.lidAwake,
                                             releaseWhenWorkEnds: config.releaseWhenWorkEnds,
                                             pendingFor: max(0, now - since),
                                             userIdle: idle,
                                             grace: grace,
                                             idleThreshold: idleThreshold)
        switch verdetto {
        case .wait:
            return
        case .cancel:
            pendingSleepSince = nil
            record(S.logSleepCancelled)
            lastNote = nil
        case .sleepNow:
            pendingSleepSince = nil
            record(S.logSleepNow)
            sleepAction()
        }
    }


    // ── Il coperchio che segue ───────────────────────────────────────────────

    /// Applica `Policy.lidFollow` e ne conserva la memoria.
    ///
    /// `forzandoIlFronte` serve a un caso solo: l'interruttore acceso **mentre** il Mac è già tenuto
    /// sveglio. Lì di fronte non ce n'è, e senza questo l'interruttore resterebbe acceso a non fare
    /// niente fino al prossimo spegni-e-riaccendi. È la stessa correzione già fatta per l'automatismo
    /// del lavoro (`autoArmSwitchedOn`, 2026-08-07): un comportamento definito sulle transizioni deve
    /// avere una porta per chi lo accende a transizione già avvenuta.
    private func reconcileLid(forcingEdge forzandoIlFronte: Bool = false) {
        let esito = Policy.lidFollow(config: config,
                                     screenAwakeWas: forzandoIlFronte ? false : screenAwakeWas,
                                     armed: lidArmedByUs,
                                     helperInstalled: helperInstalled)
        lidArmedByUs = esito.armed
        screenAwakeWas = config.screenAwake
        guard esito.changed else { return }
        config = esito.config
        lastNote = esito.note
        persist()
        record(esito.note ?? "coperchio")
    }

    /// Allinea il mondo alla configurazione, e rilegge dal mondo ciò che il mondo sa meglio di noi.
    private func refresh() {
        // Prima si decide, poi si agisce: il coperchio che segue cambia `config`, e le asserzioni
        // qui sotto devono già vedere la configurazione decisa.
        reconcileLid()
        assertion.set(config.screenAwake, mode: config.awakeMode)

        if config.lidAwake && helperInstalled {
            HelperControl.beat(lidAwake: true)
        } else {
            HelperControl.beat(lidAwake: false)
        }

        helperInstalled = HelperControl.isInstalled
        lidAwakeReal = HelperControl.sleepDisabledNow() ?? false
        onAC = PowerAssertion.isOnACPower()
        batteryPercent = PowerAssertion.batteryPercent()
        // Si guarda solo quando NoSleep non tiene: è lì che «il Mac può dormire» rischia di essere
        // vero per noi e falso per il Mac.
        altri = isHolding ? [] : OtherHolders.current()
    }

    // ── Comandi dal menu ─────────────────────────────────────────────────────

    func setScreenAwake(_ on: Bool) {
        config.screenAwake = on
        lastNote = nil
        persist()
        record(on ? S.logScreenOn : S.logScreenOff)
        refresh()
    }

    /// L'interruttore che prepara il coperchio.
    ///
    /// Il permesso si chiede **qui**, cioè mentre lui sta guardando lo schermo e ha in mano la
    /// decisione. Chiederlo al momento in cui il coperchio serve davvero vorrebbe dire mostrare una
    /// richiesta di password su un display che si sta spegnendo.
    func setLidFollowsAwake(_ on: Bool) {
        if on && !helperInstalled {
            switch HelperControl.install() {
            case .installed:
                helperInstalled = true
                installMessage = nil
            case .cancelled:
                installMessage = S.installCancelled
                return
            case .failed(let why):
                installMessage = S.installFailed(why)
                return
            }
        }
        config.lidFollowsAwake = on
        lastNote = nil
        persist()
        record(S.logLidFollow(on))
        // Acceso adesso, con il Mac già tenuto sveglio: si arma subito invece di aspettare il
        // prossimo spegni-e-riaccendi, che è ciò che chiunque si aspetta premendo quell'interruttore.
        reconcileLid(forcingEdge: on)
        refresh()
    }

    func setLidAwake(_ on: Bool) {
        // Spento a mano, il coperchio smette di essere opera nostra: da qui in poi è una sua scelta,
        // e la regola non deve rimetterci le mani fino al prossimo fronte.
        if !on { lidArmedByUs = false }
        if on && !helperInstalled {
            switch HelperControl.install() {
            case .installed:
                helperInstalled = true
                installMessage = nil
            case .cancelled:
                installMessage = S.installCancelled
                return
            case .failed(let why):
                installMessage = S.installFailed(why)
                return
            }
        }
        config.lidAwake = on
        lastNote = nil
        persist()
        record(on ? S.logLidOn : S.logLidOff)
        refresh()
    }

    func setAwakeMode(_ m: AwakeMode) {
        guard m != config.awakeMode else { return }
        config.awakeMode = m
        lastNote = nil
        persist()
        record(S.logMode(m == .screenAndActivity ? S.modeScreenAndActivity : S.modeActivityOnly))
        refresh()
    }

    func setBatteryFloorOn(_ on: Bool) {
        config.batteryFloorOn = on
        persist()
        refresh()
    }

    func setBatteryFloor(_ v: Int) {
        guard v != config.batteryFloor else { return }
        config.batteryFloor = v
        persist()
        refresh()
    }

    func setLaunchAtLogin(_ on: Bool) {
        LoginItem.set(on)
        launchesAtLogin = LoginItem.isEnabled
    }

    func setReleaseWhenWorkEnds(_ on: Bool) {
        config.releaseWhenWorkEnds = on
        persist()
    }

    func setAutoArm(_ on: Bool) {
        config.autoArmOnWork = on
        persist()
        // Acceso adesso con un lavoro già in corso: si attiva subito invece di aspettare il
        // prossimo lavoro, che è ciò che chiunque si aspetta premendo quell'interruttore.
        if on { apply(.autoArmSwitchedOn(leases: leaseCount)) }
        refresh()
    }

    /// L'uscita pulita: molla tutto **prima** di morire, così il coperchio non resta disattivato
    /// per i trenta secondi del cane da guardia.
    func releaseEverythingAndQuit() {
        config.screenAwake = false
        config.lidAwake = false
        assertion.set(false)
        HelperControl.clearRequest()
        record(S.logQuit)
        NSApplication.shared.terminate(nil)
    }

    // ── Stato derivato, per l'interfaccia ────────────────────────────────────

    /// L'app sta facendo qualcosa? È la domanda a cui risponde l'icona nella barra (ISC-42).
    var isHolding: Bool { config.screenAwake || config.lidAwake }

    /// Il nome del simbolo di sistema che va nella barra adesso.
    var glyph: String {
        Icons.glyph(awake: config.screenAwake, mode: config.awakeMode, lid: config.lidAwake)
    }

    // ── Contorno ─────────────────────────────────────────────────────────────

    private func persist() { config.save(to: Paths.config()) }

    private func record(_ event: String) {
        Log.append(LogEntry(at: Date().timeIntervalSince1970,
                            who: "app",
                            event: event,
                            screenAwake: config.screenAwake,
                            lidAwake: config.lidAwake,
                            leases: leaseCount,
                            thermal: thermal.italian,
                            board: temp.board,
                            battery: temp.battery,
                            others: altri.prefix(3).map(\.process)),
                   to: Paths.log())
    }
}
