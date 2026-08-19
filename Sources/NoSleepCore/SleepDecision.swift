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

    /// Quanto deve essere passato da un risveglio perché il sonno si possa imporre di nuovo.
    ///
    /// **Il caso, trovato a tavolino il 19/08 e non ancora visto sul suo Mac:** il Mac dorme per un
    /// motivo suo mentre una prenotazione è viva, quella scade nel sonno, lui riapre il coperchio e
    /// l'app vede il lavoro finire **in quell'istante**. Se aprire il coperchio non azzera il
    /// contatore di inattività, mezzo minuto dopo il Mac tornerebbe a dormire in faccia a chi l'ha
    /// appena aperto. Non ho verificato quell'anello, e un minuto di franchigia lo rende
    /// irrilevante invece di appoggiarsi a una supposizione.
    public static let wakeGuard: Double = 60

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
    ///   `idleThreshold` **e** niente che stia suonando **e** nessun risveglio appena avvenuto.
    ///
    /// I due veti valgono solo sulla porta dell'inattività, e non su quella del coperchio: chi
    /// abbassa il coperchio ha già detto quello che voleva, e il caso che ha fatto nascere tutto
    /// era proprio un processo audio che teneva sveglio il Mac chiuso per nove ore.
    ///
    /// **Le condizioni si rileggono a ogni giro, non si ricordano**: in mezzo minuto il coperchio
    /// può essersi riaperto, un lavoro può essere ripartito, lui può aver riacceso tutto.
    /// `grace` arriva come argomento con il suo valore vero già scritto accanto, perché i banchi
    /// la abbassano per non aspettare mezzo minuto d'orologio a ogni polo. La soglia di inattività
    /// invece si legge qui e basta: nessuno la sposta, e i banchi fingono l'inattività a monte.
    public static func verdict(lidClosed: Bool,
                               leases: Int,
                               screenAwake: Bool,
                               lidAwake: Bool,
                               releaseWhenWorkEnds: Bool,
                               pendingFor: Double,
                               userIdle: Double,
                               audioPlaying: Bool,
                               sinceWake: Double,
                               grace: Double = SleepDecision.grace) -> Verdict {
        guard leases == 0, !screenAwake, !lidAwake, releaseWhenWorkEnds else { return .cancel }
        guard pendingFor <= pendingMaxAge else { return .cancel }
        guard pendingFor >= grace else { return .wait }
        if lidClosed { return .sleepNow }
        guard userIdle >= idleThreshold, !audioPlaying, sinceWake >= wakeGuard else { return .wait }
        return .sleepNow
    }
}
