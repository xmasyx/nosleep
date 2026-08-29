import Foundation

/// Cosa fa muovere gli interruttori, oltre al dito.
public enum PolicyEvent: Equatable, Sendable {
    /// Il numero di prenotazioni vive è cambiato.
    case leases(from: Int, to: Int)
    /// Il sistema ha dichiarato un nuovo livello termico.
    case thermal(ThermalLevel)
    /// Una lettura del termometro. I valori possono mancare, e mancare non è mai un motivo per
    /// mollare: un sensore che tace non è un Mac caldo.
    case temperature(board: Double?, battery: Double?)
    /// La carica della batteria, e se il Mac è alla presa. `nil` quando non c'è una batteria.
    case battery(percent: Int?, onAC: Bool)
    /// L'automatismo è stato acceso adesso, con un certo numero di lavori già in corso.
    ///
    /// Serve perché tutto il resto ragiona per **transizioni**, e accendere l'interruttore mentre il
    /// lavoro sta già girando non è una transizione del conteggio: senza questo evento, l'automatico
    /// acceso a lavoro in corso non faceva niente e restava lì a non attivarsi (2026-08-07).
    case autoArmSwitchedOn(leases: Int)
}

/// Il risultato di un evento: la configurazione nuova, e **perché**.
///
/// La ragione non è decorazione: senza, l'utente vede un interruttore muoversi da solo e non sa se
/// è l'automatismo, il termico o un difetto. Finisce nel registro e nel menu.
public struct PolicyOutcome: Equatable, Sendable {
    public let config: Config
    public let note: String?
    public var changed: Bool { note != nil }
}

/// Come sopra, più la memoria di chi ha acceso il coperchio: questa regola può disattivare **solo**
/// ciò che ha attivato lei, e senza quel campo non saprebbe distinguerlo da una scelta a mano.
public struct LidFollowOutcome: Equatable, Sendable {
    public let config: Config
    public let armed: Bool
    public let note: String?
    public var changed: Bool { note != nil }
}

/// Come sopra, per la soglia di batteria: la configurazione nuova, e la memoria di chi ha spento.
///
/// `held` è il debito: vero fra il momento in cui la soglia ha mollato e il momento in cui la
/// stessa soglia restituisce. Senza, non si distingue uno spegnimento nostro da uno suo.
public struct BatteryReturnOutcome: Equatable, Sendable {
    public let config: Config
    public let held: Bool
    public let note: String?
    public var changed: Bool { note != nil }
}

/// Le regole, tutte qui e tutte pure: nessun disco, nessun IOKit, nessun orologio.
///
/// È l'unico posto dove si decide se una presa va aperta o chiusa, e per questo è l'unico posto
/// che i test devono coprire per intero.
public enum Policy {

    public static func apply(_ event: PolicyEvent, to config: Config) -> PolicyOutcome {
        switch event {
        case .thermal(let level):
            return thermal(level, config)
        case .leases(let from, let to):
            return leases(from: from, to: to, config)
        case .temperature(let board, let battery):
            guard let motivo = Temperature.exceeded(board: board, battery: battery),
                  config.screenAwake || config.lidAwake else {
                return PolicyOutcome(config: config, note: nil)
            }
            var next = config
            next.screenAwake = false
            next.lidAwake = false
            return PolicyOutcome(config: next, note: S.releasedBecause(motivo))

        case .battery(let percent, let onAC):
            guard batteryFloorBites(config, percent: percent, onAC: onAC), let p = percent,
                  config.screenAwake || config.lidAwake else {
                return PolicyOutcome(config: config, note: nil)
            }
            var next = config
            next.screenAwake = false
            next.lidAwake = false
            return PolicyOutcome(config: next, note: S.releasedBattery(p))

        case .autoArmSwitchedOn(let n):
            guard n > 0, config.autoArmOnWork, !config.screenAwake else {
                return PolicyOutcome(config: config, note: nil)
            }
            var next = config
            next.screenAwake = true
            return PolicyOutcome(config: next, note: S.autoArmed)
        }
    }

    /// La soglia di batteria **morde**?
    ///
    /// Domanda estratta perché la risposta serve in due posti che devono non poter divergere: qui
    /// per mollare, e a `batteryReturn` per sapere quando la stessa condizione ha smesso di valere.
    /// A corrente non morde mai: la carica sale, non scende.
    public static func batteryFloorBites(_ config: Config, percent: Int?, onAC: Bool) -> Bool {
        guard !onAC, config.batteryFloorOn, let p = percent else { return false }
        return p <= config.batteryFloor
    }

    /// Ciò che la soglia di batteria ha preso, la soglia di batteria lo restituisce.
    ///
    /// **Perché serve una regola a sé e non basta l'automatismo del lavoro.** Quello si arma sul
    /// **fronte** zero → qualcosa prenotazioni (`leases`). Quando la batteria molla mentre il lavoro
    /// sta girando, il conteggio non passa mai da zero, quindi quel fronte non ricapita e l'app resta
    /// spenta anche riattaccata alla corrente, con i terminali che lavorano. Visto dal vivo il
    /// 2026-08-30: mollato alle 00:13 al 15% con tre prenotazioni vive, mai più riacceso.
    ///
    /// **E restituisce solo ciò che ha preso lei**, come `lidFollow` col coperchio: senza la memoria
    /// `held`, riaccendere «appena la corrente torna e c'è lavoro» combatterebbe contro un
    /// interruttore che lui ha spento con la sua mano.
    public static func batteryReturn(config: Config,
                                     percent: Int?,
                                     onAC: Bool,
                                     leases: Int,
                                     thermalBites: Bool,
                                     held: Bool) -> BatteryReturnOutcome {
        // Niente di nostro da restituire.
        guard held else { return BatteryReturnOutcome(config: config, held: false, note: nil) }
        // Il Mac scotta: la rete termica viene prima e non le si passa davanti. La memoria resta,
        // perché quando il Mac si raffredda il debito con la batteria è ancora aperto.
        guard !thermalBites else { return BatteryReturnOutcome(config: config, held: true, note: nil) }
        // La soglia morde ancora: si aspetta, tenendo la memoria.
        guard !batteryFloorBites(config, percent: percent, onAC: onAC) else {
            return BatteryReturnOutcome(config: config, held: true, note: nil)
        }
        // Da qui la memoria si consuma comunque: la soglia non morde più, e ciò che non
        // riaccendiamo adesso non va riacceso più tardi da un ricordo vecchio.
        guard config.autoArmOnWork, leases > 0, !config.screenAwake else {
            return BatteryReturnOutcome(config: config, held: false, note: nil)
        }
        var next = config
        next.screenAwake = true
        return BatteryReturnOutcome(config: next, held: false, note: S.rearmedBattery)
    }

    /// Il coperchio che segue «tieni sveglio», deciso qui perché è una regola e non un cablaggio.
    ///
    /// **Lavora sul fronte, non sullo stato**, ed è la parte che si sbaglia scrivendola in fretta.
    /// Una regola nella forma «se tieni sveglio è acceso allora il coperchio è acceso» lo
    /// riaccenderebbe mezzo secondo dopo che l'utente l'ha spento a mano, e chi guarda vede un
    /// interruttore che gli combatte contro. Armare sul **passaggio** da spento ad acceso lascia
    /// l'ultima parola alla sua mano fino al passaggio dopo.
    ///
    /// **E molla solo ciò che ha preso lei.** Un coperchio acceso a mano non si spegne quando «tieni
    /// sveglio» si spegne: non l'aveva acceso questa regola, non tocca a lei toglierlo.
    ///
    /// Senza l'helper non succede niente e non si scrive niente: la riga in Preferenze dice già che
    /// manca il permesso, e una nota a ogni giro sarebbe rumore su una cosa ferma.
    public static func lidFollow(config: Config,
                                 screenAwakeWas: Bool,
                                 armed: Bool,
                                 helperInstalled: Bool) -> LidFollowOutcome {
        if config.lidFollowsAwake, !screenAwakeWas, config.screenAwake,
           helperInstalled, !config.lidAwake {
            var next = config
            next.lidAwake = true
            return LidFollowOutcome(config: next, armed: true, note: S.lidArmed)
        }
        if armed, config.lidAwake, !config.screenAwake || !config.lidFollowsAwake {
            var next = config
            next.lidAwake = false
            return LidFollowOutcome(config: next, armed: false, note: S.lidDisarmed)
        }
        // Se il coperchio nel frattempo si è spento per un'altra strada (il termico, la batteria, la
        // sua mano), la memoria si azzera da sé: non c'è più niente di nostro da mollare.
        return LidFollowOutcome(config: config, armed: armed && config.lidAwake, note: nil)
    }

    /// Il termico vince su tutto, compresi i due interruttori di comportamento. Non è negoziabile
    /// e non ha una chiave che lo spenga: è una delle due reti di sicurezza (AC-5).
    private static func thermal(_ level: ThermalLevel, _ config: Config) -> PolicyOutcome {
        guard level.forcesRelease else { return PolicyOutcome(config: config, note: nil) }
        guard config.screenAwake || config.lidAwake else {
            // Niente da mollare: non si scrive una riga di registro per un non-evento.
            return PolicyOutcome(config: config, note: nil)
        }
        var next = config
        next.screenAwake = false
        next.lidAwake = false
        return PolicyOutcome(config: next, note: S.releasedThermal(level.name))
    }

    private static func leases(from: Int, to: Int, _ config: Config) -> PolicyOutcome {
        // Il lavoro comincia: da zero a qualcosa.
        if from == 0, to > 0, config.autoArmOnWork, !config.screenAwake {
            var next = config
            next.screenAwake = true
            return PolicyOutcome(config: next, note: S.autoArmed)
        }
        // Il lavoro finisce: l'ultima prenotazione è caduta.
        if from > 0, to == 0, config.releaseWhenWorkEnds, config.screenAwake || config.lidAwake {
            var next = config
            next.screenAwake = false
            next.lidAwake = false
            return PolicyOutcome(config: next, note: S.releasedWorkDone)
        }
        return PolicyOutcome(config: config, note: nil)
    }
}
