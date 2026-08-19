import Foundation

/// **Tutto il testo che l'utente legge sta qui, in un file solo.**
///
/// Non è ordine per l'ordine. Le parole di un'interfaccia sono la parte che invecchia peggio e che
/// nessun test coglie: sparse fra le viste, si riscrivono una alla volta e nessuno le rilegge mai
/// insieme. Raccolte, si possono far passare da un controllo di lingua come si fa con un documento
/// (`Scripts/check-italian.sh`, agganciato dentro `build-app.sh`), e soprattutto si possono
/// **leggere di seguito** e sentire se suonano tradotte.
///
/// Il metro, dopo le sue due revisioni del 2026-08-07: si dice **che cosa succede al Mac**, e ci si
/// ferma. Niente meccanica interna, niente ovvietà scritte per riempire, e mai una frase che spieghi
/// che cosa fa il programma quando l'utente vuole sapere l'effetto.
public enum S {

    // ── Intestazione ─────────────────────────────────────────────────────────

    public static let headerHolding = "Il Mac resta sveglio"
    public static let headerIdle = "Il Mac può andare in sleep"

    public static let noWork = "nessun lavoro attivo"
    public static let oneWork = "un lavoro attivo"
    public static func manyWork(_ n: Int) -> String { "\(n) lavori attivi" }

    public static let lidPending = "coperchio in attesa del permesso di amministratore"

    // ── Tieni sveglio ────────────────────────────────────────────────────────

    public static let awakeTitle = "Tieni sveglio il Mac"

    public static let modeScreenAndActivity = "Schermo e attività"
    public static let modeActivityOnly = "Solo attività"

    /// La nota cambia con la modalità e con l'alimentazione, perché sono le due cose che cambiano
    /// davvero il comportamento. La fonte va in coda fra parentesi e non in testa: «a batteria il
    /// display…» faceva sembrare la corrente un caso a parte, e non lo è.
    public static func awakeNote(screenToo: Bool, onAC: Bool) -> String {
        let fonte = onAC ? "corrente" : "batteria"
        return screenToo
            ? "Il display resta acceso e il Mac non si addormenta (\(fonte))."
            : "Il Mac continua a lavorare e il display può spegnersi (\(fonte))."
    }

    // ── Coperchio ────────────────────────────────────────────────────────────

    public static let lidTitle = "Lavora a coperchio chiuso"
    /// Una frase, e basta. L'elenco che c'era dopo i due punti diceva cose che si vedono da sé.
    public static let lidNote = "Abbassi il coperchio e il Mac va avanti."

    // ── Comportamento ────────────────────────────────────────────────────────
    //
    // L'ordine è quello dei fatti: prima una cosa si attiva, poi si disattiva.

    public static let autoTitle = "Attiva automaticamente quando parte un lavoro"
    public static let autoNote =
        "Si attiva automaticamente solo «Tieni sveglio il Mac», nella modalità scelta. Il coperchio chiuso resta una scelta tua."

    public static let lidFollowTitle = "Prepara il coperchio quando il Mac è tenuto sveglio"
    public static let lidFollowNote =
        "Abbassi lo schermo e il lavoro va avanti, senza doverci pensare prima. Torna come prima quando il Mac smette di essere tenuto sveglio."
    /// Quando l'helper manca, la riga lo dice: altrimenti l'interruttore è acceso e non fa niente.
    public static let lidFollowNoHelper =
        "Serve la password di amministratore, una volta sola. Accendi «Lavora a coperchio chiuso» e poi torna qui."

    public static let releaseTitle = "Disattiva quando il lavoro finisce"
    /// Dice che cosa succede al Mac, e dice **quando**: con il coperchio alzato il momento non è la
    /// fine del lavoro, è quando lui smette di toccarlo. Scritto male, questa riga sarebbe la
    /// promessa che l'app non mantiene.
    public static let releaseNote =
        "Finito l'ultimo lavoro il Mac torna a dormire: subito se il coperchio è abbassato, dopo cinque minuti che lo lasci stare se è alzato."

    // ── Piede ────────────────────────────────────────────────────────────────

    public static let batteryTitle = "Lascia dormire il Mac sotto una certa carica"
    public static let batteryNote =
        "A batteria, quando la carica scende sotto la soglia, NoSleep molla tutto. Tenere sveglio un Mac che sta per spegnersi non finisce il lavoro."

    public static let loginTitle = "Avvia NoSleep all'accesso"
    public static let loginNote = "Si apre da sola quando accendi il Mac, senza doverci pensare."

    public static let preferencesButton = "Preferenze"
    public static let quitButton = "Disattiva e chiudi"


    // ── Le righe che l'app scrive da sola ────────────────────────────────────

    public static let autoArmed = "attivato automaticamente, è partito un lavoro"
    public static let lidArmed = "coperchio pronto, puoi abbassare lo schermo"
    public static let lidDisarmed = "coperchio tornato come prima"
    public static func releasedBattery(_ p: Int) -> String { "disattivato, la batteria è al \(p)%" }
    public static let releasedWorkDone = "disattivato, il lavoro è finito"
    public static func releasedThermal(_ level: String) -> String {
        "disattivato perché il Mac è \(level) e il sistema sta già rallentando"
    }

    // ── Il registro ──────────────────────────────────────────────────────────

    public static let logScreenOn = "tieni sveglio attivato a mano"
    public static let logScreenOff = "tieni sveglio disattivato a mano"
    public static let logLidOn = "coperchio chiuso attivato a mano"
    public static let logLidOff = "coperchio chiuso disattivato a mano"
    public static func logLidFollow(_ on: Bool) -> String {
        on ? "coperchio preparato insieme a tieni sveglio" : "coperchio non più preparato"
    }
    public static let logQuit = "chiusura, disattivato tutto"
    public static let logSleepScheduled = "sleep programmato, coperchio chiuso e lavoro finito"
    public static let logSleepPendingIdle = "sleep in attesa, lavoro finito e coperchio alzato"
    public static let logSleepCancelled = "sleep annullato, le condizioni sono cambiate"
    public static let logSleepNow = "mando il Mac in sleep"
    public static func sleepScheduled(_ s: Int) -> String { "va in sleep fra \(s) secondi" }
    public static func sleepWhenIdle(_ min: Int) -> String {
        "va in sleep quando lasci il Mac fermo \(min) minuti"
    }
    public static func logMode(_ m: String) -> String { "modalità cambiata in \(m)" }

    public static let installCancelled =
        "Per il coperchio chiuso serve la password di amministratore, una volta sola."
    public static func installFailed(_ why: String) -> String { "Non è riuscita. \(why)" }
}
