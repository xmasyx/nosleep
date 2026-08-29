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
    /// Dice che cosa succede al Mac, e dice **quando**: dal 28/08 il coperchio abbassato aspetta tre
    /// minuti, perché un rinnovo arrivato tardi non spenga il Mac sotto il lavoro; con quello
    /// alzato il momento resta quando lui smette di toccarlo. Scritto male, questa riga sarebbe la
    /// promessa che l'app non mantiene.
    public static let releaseNote =
        "Finito l'ultimo lavoro il Mac torna a dormire: dopo tre minuti se il coperchio è abbassato, dopo cinque minuti che lo lasci stare se è alzato."

    // ── Pulizia della tastiera ────────────────────────────────────────────────
    //
    // Le parole dicono che cosa succede al Mac — schermo nero, tastiera ferma — e mai come è fatto
    // dentro. La riga più importante di tutte è quella che dice **come si esce**, e infatti compare
    // due volte: nel pannello prima di partire, e nel piede della schermata mentre è accesa.

    public static let wipeTitle = "Pulisci la tastiera"
    /// Il bottone dice **che cosa fa il click**, non ripete il titolo della riga: «Pulisci la
    /// tastiera» con accanto «Pulisci» erano la stessa parola due volte, e la seconda non
    /// aggiungeva niente. «Avvia» è sua (2026-08-22).
    public static let wipeStartButton = "Avvia"
    public static let wipeNote =
        "La tastiera smette di rispondere e lo schermo diventa nero. Torna tutto da solo alla scadenza."
    public static func wipeExitNote(_ combo: String) -> String {
        "Per uscire prima: \(combo)."
    }

    /// Il piede della schermata nera. Tre cose e nient'altro: che cosa sta succedendo, quanto
    /// manca, come si esce.
    public static let wipeStatus = "Pulizia della tastiera"
    public static let wipeRemaining = "rimanenti"
    public static let wipeExitWord = "esci"

    public static let wipeDurationTitle = "Durata della pulizia"
    public static let wipeDurationNote =
        "Il blocco si toglie sempre da solo alla scadenza, anche se parte per sbaglio. Cinque minuti è il massimo."

    public static let wipeAxTitle = "Blocca anche i tasti funzione"
    public static let wipeAxNote =
        "Serve il permesso di Accessibilità, e vale solo mentre la pulizia è accesa. Senza, restano vivi i tasti F, la luminosità, il volume e la Dettatura."
    public static let wipeAxMissing =
        "Manca il permesso di Accessibilità: la pulizia parte lo stesso, ma i tasti funzione e i comandi del volume restano vivi."
    public static let wipeAxOpenSettings = "Apri Impostazioni di Sistema"

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
    public static let rearmedBattery = "riattivato, la batteria non blocca più e il lavoro è ancora in corso"
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
    public static let logSleepFailed = "il sistema ha rifiutato di andare in sleep"
    /// I minuti interi si dicono come minuti: la promessa visibile deve dire i tre minuti veri.
    /// La parola resta fuori dal letterale: il cancello legge il ternario dentro `\( )` come un
    /// punto interrogativo con uno spazio davanti.
    public static func sleepScheduled(_ s: Int) -> String {
        guard s >= 60, s % 60 == 0 else { return "va in sleep fra \(s) secondi" }
        let minuti = s / 60
        let parola = minuti == 1 ? "minuto" : "minuti"
        return "va in sleep fra \(minuti) \(parola)"
    }
    public static func sleepWhenIdle(_ min: Int) -> String {
        "va in sleep quando lasci il Mac fermo \(min) minuti"
    }
    public static func logMode(_ m: String) -> String { "modalità cambiata in \(m)" }

    /// L'identificatore resta nella riga perché alle 06:54 del 28/08 i soli conteggi «0 → 1 → 0»
    /// non dicevano quale prenotazione fosse sparita, né se fosse scaduta o restituita.
    public static func logLeaseTaken(_ id: String, ttl: Int) -> String {
        "prenotazione presa \(id) (\(ttl) s)"
    }
    /// Nomina la prenotazione restituita, così la sua uscita non si confonde con una scadenza.
    public static func logLeaseReleased(_ id: String) -> String { "prenotazione restituita \(id)" }
    /// Nomina la prenotazione scaduta, così il rinnovo mancato resta leggibile il giorno dopo.
    public static func logLeaseExpired(_ id: String) -> String { "prenotazione scaduta \(id)" }

    public static func logWipeStart(_ minuti: Int) -> String {
        let parola = minuti == 1 ? "minuto" : "minuti"
        return "pulizia della tastiera, \(minuti) \(parola)"
    }
    public static let logWipeManual = "pulizia finita, uscita a mano"
    public static let logWipeExpired = "pulizia finita, tempo scaduto"
    public static let logWipeWatchdog = "pulizia chiusa dal cane da guardia: il timer non era scattato"
    public static let logWipeNoAX =
        "pulizia senza permesso di Accessibilità: i tasti funzione non sono bloccati"
    /// Un modificatore era rimasto premuto per il sistema quando la pulizia si è chiusa. Riga rara
    /// per costruzione: senza, di un guasto che si ripara da solo alla pressione dopo non resta
    /// niente da leggere il giorno dopo.
    public static func logWipeStuckModifiers(_ tasti: String) -> String {
        "alla chiusura della pulizia il sistema teneva ancora premuto \(tasti): rimessi a zero"
    }
    public static let logWipeSecureInput =
        "un'altra app tiene l'input protetto: i tasti non passano da noi e non possiamo bloccarli tutti"

    public static let installCancelled =
        "Per il coperchio chiuso serve la password di amministratore, una volta sola."
    public static func installFailed(_ why: String) -> String { "Non è riuscita. \(why)" }
}
