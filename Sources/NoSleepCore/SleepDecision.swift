import Foundation

/// Quando «disattiva quando il lavoro finisce» deve **addormentare** il Mac invece di limitarsi a
/// mollare la presa.
///
/// **Perché la differenza conta.** Mollare la presa basterebbe su un Mac che si addormenta da solo.
/// Il suo non lo fa: `pmset -g` dice `sleep 0`, cioè mai per inattività, e anche quando NoSleep
/// lascia andare restano in piedi le asserzioni di qualcun altro — `sharingd`, una scheda del
/// browser, il `caffeinate` che lancia Claude Code. Il risultato è un Mac sveglio per ore dopo che
/// il lavoro è finito, cioè la cosa che questa app esiste per evitare. È successo davvero:
/// `coreaudiod` dalle 02:47 alle 11:50 del 7/08, a coperchio chiuso.
///
/// **È un'imposizione, e va detto.** Non stiamo tornando al comportamento di serie, stiamo
/// spegnendo qualcosa che qualcun altro voleva tenere acceso. Per questo ci sono due porte e non
/// una: il coperchio abbassato, dove l'intenzione di chi l'ha chiuso è inequivocabile, e — dal
/// 2026-08-19, sua scelta — il coperchio alzato **con nessuno alla tastiera da cinque minuti**.
///
/// **La seconda porta senza la soglia di inattività sarebbe il difetto peggiore dell'app:** il Mac
/// si addormenta in faccia a chi lo sta leggendo, e il rimedio diventa la cosa da disinstallare.
/// Cinque minuti sono la stessa promessa scritta in una riga: finito il lavoro, il Mac dorme appena
/// lo lasci stare.
public enum SleepDecision {

    /// Il respiro prima di addormentare. Serve a due cose: un lavoro che riparte subito non viene
    /// tagliato, e chi ha appena riaperto il coperchio non si vede il Mac spegnersi in faccia.
    public static let grace: Double = 30

    /// Da quanto tempo nessuno tocca tastiera o trackpad perché il coperchio **alzato** conti come
    /// «non c'è nessuno». Cinque minuti, sua scelta del 2026-08-19.
    public static let idleThreshold: Double = 300

    /// Quanto può restare armata un'attesa che non trova mai il suo momento.
    ///
    /// Senza questo tetto, un lavoro finito alle sette di sera addormenterebbe il Mac alle due di
    /// notte, cinque minuti dopo che lui smette di scrivere, attribuendo a quel lavoro una
    /// decisione presa sette ore più tardi. Passate due ore di attività continua l'intenzione è
    /// invecchiata e l'attesa cade da sé.
    public static let pendingMaxAge: Double = 7200

    /// Che cosa fare adesso di un'attesa armata dalla fine del lavoro.
    public enum Verdict: Equatable, Sendable {
        /// Le condizioni non ci sono più: l'attesa si butta.
        case cancel
        /// Ancora presto, oppure c'è ancora qualcuno alla tastiera.
        case wait
        /// Adesso.
        case sleepNow
    }

    /// Tutte le condizioni in un posto solo, e ognuna ha la sua ragione.
    ///
    /// - `leases == 0`: nessun lavoro vivo, che è il fatto che ha innescato tutto.
    /// - `!screenAwake && !lidAwake`: nel frattempo nessuno ha riacceso NoSleep, né a mano né
    ///   dall'automatismo.
    /// - `releaseWhenWorkEnds`: se l'interruttore è stato spento durante l'attesa, la decisione
    ///   presa mezzo minuto fa non vale più.
    /// - `pendingFor >= grace`: il respiro.
    /// - e infine una porta sola fra le due: coperchio abbassato, oppure nessuno alla tastiera da
    ///   `idleThreshold`.
    ///
    /// **Le condizioni si rileggono a ogni giro, non si ricordano**: in mezzo minuto il coperchio
    /// può essersi riaperto, un lavoro può essere ripartito, lui può aver riacceso tutto.
    /// `grace` e `idleThreshold` arrivano come argomenti con il loro valore vero già scritto
    /// accanto: un banco li abbassa per non aspettare cinque minuti d'orologio, e in esercizio
    /// nessuno li passa. Cablarli dentro voleva dire o un banco lento o una copia dei numeri.
    public static func verdict(lidClosed: Bool,
                               leases: Int,
                               screenAwake: Bool,
                               lidAwake: Bool,
                               releaseWhenWorkEnds: Bool,
                               pendingFor: Double,
                               userIdle: Double,
                               grace: Double = SleepDecision.grace,
                               idleThreshold: Double = SleepDecision.idleThreshold) -> Verdict {
        guard leases == 0, !screenAwake, !lidAwake, releaseWhenWorkEnds else { return .cancel }
        guard pendingFor <= pendingMaxAge else { return .cancel }
        guard pendingFor >= grace else { return .wait }
        return (lidClosed || userIdle >= idleThreshold) ? .sleepNow : .wait
    }

    /// La forma corta, per chi la grazia l'ha già aspettata e vuole solo sapere se è il momento.
    public static func shouldSleep(lidClosed: Bool,
                                   leases: Int,
                                   screenAwake: Bool,
                                   lidAwake: Bool,
                                   releaseWhenWorkEnds: Bool,
                                   userIdle: Double = .infinity) -> Bool {
        verdict(lidClosed: lidClosed, leases: leases, screenAwake: screenAwake,
                lidAwake: lidAwake, releaseWhenWorkEnds: releaseWhenWorkEnds,
                pendingFor: grace, userIdle: userIdle) == .sleepNow
    }
}
