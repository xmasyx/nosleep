import Foundation

/// La rete del coperchio chiuso: un Mac tenuto sveglio **dall'automatismo**, col coperchio
/// abbassato, a batteria e senza nessun lavoro in corso non ha più una ragione per restare sveglio.
///
/// **Il caso, che è costato tre notti di fila.** Con «disattiva quando il lavoro finisce» spento e
/// l'automatico acceso, la prima chat arma «tieni sveglio» e il coperchio, e niente molla più: la
/// fine del lavoro non conta per costruzione, e l'unica uscita rimasta è la soglia di batteria. Il
/// 12/10/2026 l'app ha armato alle 22:20, le prenotazioni sono scese a zero alle 23:31, lui ha
/// staccato la corrente alle 23:49 all'80% e ha abbassato il coperchio: la presa è rimasta viva
/// tre ore e diciotto minuti, fino a «la batteria è al 15%» all'01:38. Lo stesso il 10 e l'11.
///
/// **Guarda lo stato, non il fronte.** Quella notte il lavoro è finito a coperchio alzato e a
/// corrente, e il coperchio si è chiuso diciotto minuti dopo. Una regola agganciata all'istante in
/// cui cade l'ultima prenotazione l'avrebbe mancato: qui le condizioni si rileggono a ogni giro, e
/// il respiro parte dal primo giro in cui valgono tutte insieme.
///
/// **Molla solo ciò che ha preso l'automatismo**, come il coperchio che segue e come la batteria
/// che restituisce. Una presa accesa a mano è una sua scelta: chi abbassa il coperchio per finire
/// uno scaricamento non deve trovarsi il Mac addormentato da una regola che non ha chiesto, e lì
/// resta la soglia di batteria.
///
/// **Non è «disattiva quando il lavoro finisce» sotto un altro nome.** Quell'interruttore decide
/// che cosa succede alla fine del lavoro in generale, e da spento continua a voler dire ciò che
/// dice: a coperchio alzato e a corrente questa rete non esiste.
public enum ClosedLidNet {

    public enum Verdict: Equatable, Sendable {
        /// Le condizioni non ci sono: l'attesa, se c'era, si azzera.
        case idle
        /// Le condizioni ci sono, ma il respiro non è finito o un turno sta ancora lavorando.
        case wait
        /// Adesso: mollare la presa e addormentare.
        case release
    }

    /// - `armedByWork`: tutto ciò che è tenuto adesso l'ha acceso l'automatismo, niente la sua mano.
    /// - `lidClosed`, `!onAC`, `leases == 0`: il caso, e nessuno dei tre è negoziabile.
    /// - `heldFor >= grace`: lo stesso respiro di `SleepDecision`, per la stessa ragione del 28/08,
    ///   quando due rinnovi mancati hanno fatto vedere zero prenotazioni sotto un turno vivo.
    /// - `caffeinated`: si aspetta e non si azzera, come nella porta del sonno. È una chiusura
    ///   perché leggerla costa, e va chiesta solo quando tutto il resto ha già detto sì.
    public static func verdict(armedByWork: Bool,
                               lidClosed: Bool,
                               onAC: Bool,
                               leases: Int,
                               heldFor: Double,
                               caffeinated: () -> Bool,
                               grace: Double = SleepDecision.grace) -> Verdict {
        guard armedByWork, lidClosed, !onAC, leases == 0 else { return .idle }
        guard heldFor >= grace else { return .wait }
        guard !caffeinated() else { return .wait }
        return .release
    }
}
