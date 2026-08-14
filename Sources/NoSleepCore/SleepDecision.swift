import Foundation

/// Quando «disattiva quando il lavoro finisce» deve **addormentare** il Mac invece di limitarsi a
/// mollare la presa.
///
/// **Perché la differenza conta.** Smettere di impedire il sonno è tutto quello che serve a
/// coperchio alzato: sei davanti al Mac e decidi tu. A coperchio **chiuso** è una promessa non
/// mantenuta: hai chiesto che tornasse a dormire, NoSleep molla, e basta una scheda del browser con
/// dell'audio aperto perché resti sveglio per ore mentre non puoi né vederlo né intervenire. È
/// successo davvero: `coreaudiod` ha tenuto sveglio il Mac dalle 02:47 alle 11:50 del 7/08.
///
/// **È un'imposizione, e va detto.** Non stiamo tornando al comportamento di serie, stiamo
/// spegnendo qualcosa che qualcun altro voleva tenere acceso. Per questo agisce **solo** a
/// coperchio abbassato, dove l'intenzione di chi l'ha chiuso è inequivocabile.
public enum SleepDecision {

    /// Il respiro prima di addormentare. Serve a due cose: un lavoro che riparte subito non viene
    /// tagliato, e chi ha appena riaperto il coperchio non si vede il Mac spegnersi in faccia.
    public static let grace: Double = 30

    /// Va addormentato adesso? Tutte le condizioni in AND, e ognuna ha una ragione.
    ///
    /// - `lidClosed`: fuori da qui non si tocca niente.
    /// - `leases == 0`: nessun lavoro vivo, che è il fatto che ha innescato tutto.
    /// - `!screenAwake && !lidAwake`: nel frattempo nessuno ha riacceso NoSleep, né a mano né
    ///   dall'automatismo.
    /// - `releaseWhenWorkEnds`: se l'interruttore è stato spento durante l'attesa, la decisione
    ///   presa trenta secondi fa non vale più.
    public static func shouldSleep(lidClosed: Bool,
                                   leases: Int,
                                   screenAwake: Bool,
                                   lidAwake: Bool,
                                   releaseWhenWorkEnds: Bool) -> Bool {
        lidClosed && leases == 0 && !screenAwake && !lidAwake && releaseWhenWorkEnds
    }
}
