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
            return PolicyOutcome(config: next, note: "disattivato perché \(motivo)")

        case .battery(let percent, let onAC):
            // A corrente la soglia non ha senso: la carica sale, non scende.
            guard !onAC, config.batteryFloorOn, let p = percent, p <= config.batteryFloor,
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
        return PolicyOutcome(config: next, note: S.releasedThermal(level.italian))
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
