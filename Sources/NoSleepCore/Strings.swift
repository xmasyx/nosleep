import Foundation

/// **Tutto il testo che l'utente legge sta qui, in un file solo.**
///
/// Non è ordine per l'ordine. Le parole di un'interfaccia sono la parte che invecchia peggio e che
/// nessun test coglie: sparse fra le viste, si riscrivono una alla volta e nessuno le rilegge mai
/// insieme. Raccolte, si possono far passare da un controllo di lingua come si fa con un documento
/// (`Scripts/check-italian.sh`, agganciato dentro `build-app.sh`), e soprattutto si possono
/// **leggere di seguito** e sentire se suonano tradotte.
/// Le due lingue stanno una accanto all'altra: così anche l'inglese si legge di seguito e una
/// traduzione che conserva la forma italiana si vede mentre si scrive quella giusta.
///
/// Il metro, dopo le sue due revisioni del 2026-08-07: si dice **che cosa succede al Mac**, e ci si
/// ferma. Niente meccanica interna, niente ovvietà scritte per riempire, e mai una frase che spieghi
/// che cosa fa il programma quando l'utente vuole sapere l'effetto.
public enum S {

    // ── Intestazione ─────────────────────────────────────────────────────────

    public static var headerHolding: String {
        L.t(en: "The Mac stays awake", it: "Il Mac resta sveglio")
    }
    public static var headerIdle: String {
        L.t(en: "The Mac can sleep", it: "Il Mac può andare in sleep")
    }

    // ── La riga di stato ────────────────────────────────────────────────────

    public static var noWork: String {
        L.t(en: "no jobs alive", it: "nessun lavoro attivo")
    }
    public static var oneWork: String {
        L.t(en: "one job alive", it: "un lavoro attivo")
    }
    public static func manyWork(_ n: Int) -> String {
        L.t(en: "\(n) jobs alive", it: "\(n) lavori attivi")
    }

    public static func macThermal(_ level: String) -> String {
        L.t(en: "Mac \(level)", it: "Mac \(level)")
    }
    public static func batteryCharge(_ percent: Int) -> String {
        L.t(en: "charge \(percent)%", it: "carica \(percent)%")
    }
    /// Batteria e chip sono una misura sola agli occhi di chi legge: tenerli insieme evita che la
    /// punteggiatura della frase finisca nella vista.
    public static func batteryTemperatures(battery: Double, chip: Double?) -> String {
        let batteryText = String(
            format: L.t(en: "battery %.0f°", it: "batteria %.0f°"),
            battery
        )
        guard let chip else { return batteryText }
        return batteryText + String(format: ", chip %.0f°", chip)
    }

    public static var lidPending: String {
        L.t(
            en: "lid waiting for admin approval",
            it: "coperchio in attesa del permesso di amministratore"
        )
    }

    // ── Tieni sveglio ────────────────────────────────────────────────────────

    public static var awakeTitle: String {
        L.t(en: "Keep the Mac awake", it: "Tieni sveglio il Mac")
    }

    public static var modeScreenAndActivity: String {
        L.t(en: "Display and activity", it: "Schermo e attività")
    }
    public static var modeActivityOnly: String {
        L.t(en: "Activity only", it: "Solo attività")
    }

    /// La nota cambia con la modalità e con l'alimentazione, perché sono le due cose che cambiano
    /// davvero il comportamento. La fonte va in coda fra parentesi e non in testa: «a batteria il
    /// display…» faceva sembrare la corrente un caso a parte, e non lo è.
    public static func awakeNote(screenToo: Bool, onAC: Bool) -> String {
        let source = onAC ? "on power" : "on battery"
        let fonte = onAC ? "corrente" : "batteria"
        return screenToo
            ? L.t(
                en: "The display stays on and the Mac stays awake (\(source)).",
                it: "Il display resta acceso e il Mac non si addormenta (\(fonte))."
            )
            : L.t(
                en: "The Mac keeps working and the display can turn off (\(source)).",
                it: "Il Mac continua a lavorare e il display può spegnersi (\(fonte))."
            )
    }

    // ── Coperchio ────────────────────────────────────────────────────────────

    public static var lidTitle: String {
        L.t(en: "Work with the lid closed", it: "Lavora a coperchio chiuso")
    }
    /// Una frase, e basta. L'elenco che c'era dopo i due punti diceva cose che si vedono da sé.
    public static var lidNote: String {
        L.t(en: "Close the lid and the work carries on.", it: "Abbassi il coperchio e il Mac va avanti.")
    }

    // ── Comportamento ────────────────────────────────────────────────────────
    //
    // L'ordine è quello dei fatti: prima una cosa si attiva, poi si disattiva.

    public static var autoTitle: String {
        L.t(
            en: "Turn on automatically when a job starts",
            it: "Attiva automaticamente quando parte un lavoro"
        )
    }
    public static var autoNote: String {
        L.t(
            en: "Only \"Keep the Mac awake\" turns on automatically, in the selected mode. Working with the lid closed stays your choice.",
            it: "Si attiva automaticamente solo «Tieni sveglio il Mac», nella modalità scelta. Il coperchio chiuso resta una scelta tua."
        )
    }

    public static var lidFollowTitle: String {
        L.t(
            en: "Arm the lid whenever the Mac is kept awake",
            it: "Prepara il coperchio quando il Mac è tenuto sveglio"
        )
    }
    public static var lidFollowNote: String {
        L.t(
            en: "Close the lid and the work carries on, even if you did not plan ahead. It returns to normal when the Mac is no longer kept awake.",
            it: "Abbassi lo schermo e il lavoro va avanti, senza doverci pensare prima. Torna come prima quando il Mac smette di essere tenuto sveglio."
        )
    }
    /// Quando l'helper manca, la riga lo dice: altrimenti l'interruttore è acceso e non fa niente.
    public static var lidFollowNoHelper: String {
        L.t(
            en: "This needs your admin password once. Turn on \"Work with the lid closed\", then come back here.",
            it: "Serve la password di amministratore, una volta sola. Accendi «Lavora a coperchio chiuso» e poi torna qui."
        )
    }

    public static var releaseTitle: String {
        L.t(en: "Release when the work ends", it: "Disattiva quando il lavoro finisce")
    }
    /// Dice che cosa succede al Mac, e dice **quando**: dal 28/08 il coperchio abbassato aspetta tre
    /// minuti, perché un rinnovo arrivato tardi non spenga il Mac sotto il lavoro; con quello
    /// alzato il momento resta quando lui smette di toccarlo. Scritto male, questa riga sarebbe la
    /// promessa che l'app non mantiene.
    public static var releaseNote: String {
        L.t(
            en: "When the last job ends, the Mac goes to sleep after three minutes with the lid down, or after five idle minutes with it up.",
            it: "Finito l'ultimo lavoro il Mac torna a dormire: dopo tre minuti se il coperchio è abbassato, dopo cinque minuti che lo lasci stare se è alzato."
        )
    }

    // ── Pulizia della tastiera ────────────────────────────────────────────────
    //
    // Le parole dicono che cosa succede al Mac — schermo nero, tastiera ferma — e mai come è fatto
    // dentro. La riga più importante di tutte è quella che dice **come si esce**, e infatti compare
    // due volte: nel pannello prima di partire, e nel piede della schermata mentre è accesa.

    public static var wipeTitle: String {
        L.t(en: "Clean the keyboard", it: "Pulisci la tastiera")
    }
    /// Il bottone dice **che cosa fa il click**, non ripete il titolo della riga: «Pulisci la
    /// tastiera» con accanto «Pulisci» erano la stessa parola due volte, e la seconda non
    /// aggiungeva niente. «Avvia» è sua (2026-08-22).
    public static var wipeStartButton: String {
        L.t(en: "Start", it: "Avvia")
    }
    public static var wipeNote: String {
        L.t(
            en: "The keyboard stops responding and the display goes black. Everything returns to normal when time runs out.",
            it: "La tastiera smette di rispondere e lo schermo diventa nero. Torna tutto da solo alla scadenza."
        )
    }
    public static func wipeExitNote(_ combo: String) -> String {
        L.t(en: "To leave early: \(combo).", it: "Per uscire prima: \(combo).")
    }

    /// Il piede della schermata nera. Tre cose e nient'altro: che cosa sta succedendo, quanto
    /// manca, come si esce.
    public static var wipeStatus: String {
        L.t(en: "Keyboard cleaning", it: "Pulizia della tastiera")
    }
    public static var wipeRemaining: String {
        L.t(en: "remaining", it: "rimanenti")
    }
    public static var wipeExitWord: String {
        L.t(en: "exit", it: "esci")
    }

    public static var wipeDurationTitle: String {
        L.t(en: "Cleaning time", it: "Durata della pulizia")
    }
    public static var wipeDurationNote: String {
        L.t(
            en: "The lock always ends on its own, even if you start it by mistake. Five minutes is the limit.",
            it: "Il blocco si toglie sempre da solo alla scadenza, anche se parte per sbaglio. Cinque minuti è il massimo."
        )
    }

    public static var wipeAxTitle: String {
        L.t(en: "Block function keys too", it: "Blocca anche i tasti funzione")
    }
    public static var wipeAxNote: String {
        L.t(
            en: "This needs Accessibility permission, and only while cleaning is on. Without it, the F keys, brightness, volume, and Dictation still work.",
            it: "Serve il permesso di Accessibilità, e vale solo mentre la pulizia è accesa. Senza, restano vivi i tasti F, la luminosità, il volume e la Dettatura."
        )
    }
    public static var wipeAxMissing: String {
        L.t(
            en: "Accessibility permission is missing. Cleaning still starts, but the function keys and volume controls still work.",
            it: "Manca il permesso di Accessibilità: la pulizia parte lo stesso, ma i tasti funzione e i comandi del volume restano vivi."
        )
    }
    public static var wipeAxOpenSettings: String {
        L.t(en: "Open System Settings", it: "Apri Impostazioni di Sistema")
    }
    public static var accessibilityActive: String {
        L.t(en: "active", it: "attivo")
    }
    public static var noModifiers: String {
        L.t(en: "none", it: "nessuno")
    }

    // ── Piede ────────────────────────────────────────────────────────────────

    public static var batteryTitle: String {
        L.t(
            en: "Let the Mac sleep below the charge threshold",
            it: "Lascia dormire il Mac sotto una certa carica"
        )
    }
    public static var batteryNote: String {
        L.t(
            en: "On battery, NoSleep releases everything when the charge drops below the threshold. Keeping a Mac awake when it is about to run out will not finish the job.",
            it: "A batteria, quando la carica scende sotto la soglia, NoSleep molla tutto. Tenere sveglio un Mac che sta per spegnersi non finisce il lavoro."
        )
    }

    public static var loginTitle: String {
        L.t(en: "Open NoSleep at login", it: "Avvia NoSleep all'accesso")
    }
    public static var loginNote: String {
        L.t(
            en: "It opens when you start the Mac, without you having to remember.",
            it: "Si apre da sola quando accendi il Mac, senza doverci pensare."
        )
    }

    public static var preferencesButton: String {
        L.t(en: "Settings", it: "Preferenze")
    }
    public static var settingsWindowTitle: String {
        L.t(en: "NoSleep Settings", it: "Preferenze di NoSleep")
    }
    public static var quitButton: String {
        L.t(en: "Turn off and quit", it: "Disattiva e chiudi")
    }


    // ── Le righe che l'app scrive da sola ────────────────────────────────────

    public static var autoArmed: String {
        L.t(en: "turned on automatically when a job started", it: "attivato automaticamente, è partito un lavoro")
    }
    public static var lidArmed: String {
        L.t(en: "lid ready, you can close it", it: "coperchio pronto, puoi abbassare lo schermo")
    }
    public static var lidDisarmed: String {
        L.t(en: "lid returned to normal", it: "coperchio tornato come prima")
    }
    public static func releasedBattery(_ p: Int) -> String {
        L.t(en: "turned off at \(p)% charge", it: "disattivato, la batteria è al \(p)%")
    }
    public static var releasedWorkDone: String {
        L.t(en: "turned off when the job ended", it: "disattivato, il lavoro è finito")
    }
    public static var rearmedBattery: String {
        L.t(en: "turned back on, the battery no longer blocks it and the job is still running",
            it: "riattivato, la batteria non blocca più e il lavoro è ancora in corso")
    }
    public static func releasedThermal(_ level: String) -> String {
        L.t(
            en: "turned off because the Mac is \(level) and the system is already slowing down",
            it: "disattivato perché il Mac è \(level) e il sistema sta già rallentando"
        )
    }
    public static func releasedBecause(_ reason: String) -> String {
        L.t(en: "turned off because \(reason)", it: "disattivato perché \(reason)")
    }
    public static func batteryTemperatureReason(_ degrees: Double) -> String {
        String(
            format: L.t(
                en: "the battery is at %.0f degrees",
                it: "la batteria è a %.0f gradi"
            ),
            degrees
        )
    }

    // ── I livelli termici ───────────────────────────────────────────────────

    public static var thermalNormal: String {
        L.t(en: "normal", it: "normale")
    }
    public static var thermalWarm: String {
        L.t(en: "warm", it: "tiepido")
    }
    public static var thermalHot: String {
        L.t(en: "hot", it: "caldo")
    }
    public static var thermalCritical: String {
        L.t(en: "critical", it: "critico")
    }

    // ── Il registro ──────────────────────────────────────────────────────────

    public static var logScreenOn: String {
        L.t(en: "turned keep awake on by hand", it: "tieni sveglio attivato a mano")
    }
    public static var logScreenOff: String {
        L.t(en: "turned keep awake off by hand", it: "tieni sveglio disattivato a mano")
    }
    public static var logLidOn: String {
        L.t(en: "turned lid mode on by hand", it: "coperchio chiuso attivato a mano")
    }
    public static var logLidOff: String {
        L.t(en: "turned lid mode off by hand", it: "coperchio chiuso disattivato a mano")
    }
    public static func logLidFollow(_ on: Bool) -> String {
        on
            ? L.t(
                en: "armed the lid with keep awake",
                it: "coperchio preparato insieme a tieni sveglio"
            )
            : L.t(en: "stopped arming the lid", it: "coperchio non più preparato")
    }
    public static var logQuit: String {
        L.t(en: "turned everything off on quit", it: "chiusura, disattivato tutto")
    }
    public static var logSleepScheduled: String {
        L.t(
            en: "scheduled sleep after the job ended with the lid closed",
            it: "sleep programmato, coperchio chiuso e lavoro finito"
        )
    }
    public static var logSleepPendingIdle: String {
        L.t(
            en: "waiting to sleep after the job ended with the lid open",
            it: "sleep in attesa, lavoro finito e coperchio alzato"
        )
    }
    public static var logSleepCancelled: String {
        L.t(
            en: "cancelled sleep after conditions changed",
            it: "sleep annullato, le condizioni sono cambiate"
        )
    }
    public static var logSleepNow: String {
        L.t(en: "sending the Mac to sleep", it: "mando il Mac in sleep")
    }
    public static var logSleepFailed: String {
        L.t(
            en: "the system refused to go to sleep",
            it: "il sistema ha rifiutato di andare in sleep"
        )
    }
    /// I minuti interi si dicono come minuti: la promessa visibile deve dire i tre minuti veri.
    /// La parola resta fuori dal letterale: il cancello legge il ternario dentro `\( )` come un
    /// punto interrogativo con uno spazio davanti.
    public static func sleepScheduled(_ s: Int) -> String {
        guard s >= 60, s % 60 == 0 else {
            return L.t(en: "goes to sleep in \(s) seconds", it: "va in sleep fra \(s) secondi")
        }
        let minuti = s / 60
        let parola = minuti == 1 ? "minuto" : "minuti"
        let word = minuti == 1 ? "minute" : "minutes"
        return L.t(
            en: "goes to sleep in \(minuti) \(word)",
            it: "va in sleep fra \(minuti) \(parola)"
        )
    }
    /// Il plurale inglese si decide qui e non a valle: oggi il numero è sempre cinque, ma un
    /// «1 minutes» comparirebbe il giorno che la soglia cambia, e nessun test lo starebbe guardando.
    public static func sleepWhenIdle(_ min: Int) -> String {
        let word = min == 1 ? "minute" : "minutes"
        return L.t(
            en: "goes to sleep after you leave the Mac idle for \(min) \(word)",
            it: "va in sleep quando lasci il Mac fermo \(min) minuti"
        )
    }
    public static func logMode(_ m: String) -> String {
        L.t(en: "mode changed to \(m)", it: "modalità cambiata in \(m)")
    }

    /// L'identificatore resta nella riga perché alle 06:54 del 28/08 i soli conteggi «0 → 1 → 0»
    /// non dicevano quale prenotazione fosse sparita, né se fosse scaduta o restituita.
    public static func logLeaseTaken(_ id: String, ttl: Int) -> String {
        L.t(en: "claim taken \(id) (\(ttl) s)", it: "prenotazione presa \(id) (\(ttl) s)")
    }
    /// Nomina la prenotazione restituita, così la sua uscita non si confonde con una scadenza.
    public static func logLeaseReleased(_ id: String) -> String {
        L.t(en: "claim released \(id)", it: "prenotazione restituita \(id)")
    }
    /// Nomina la prenotazione scaduta, così il rinnovo mancato resta leggibile il giorno dopo.
    public static func logLeaseExpired(_ id: String) -> String {
        L.t(en: "claim expired \(id)", it: "prenotazione scaduta \(id)")
    }

    public static func logWipeStart(_ minuti: Int) -> String {
        let parola = minuti == 1 ? "minuto" : "minuti"
        let word = minuti == 1 ? "minute" : "minutes"
        return L.t(
            en: "keyboard cleaning, \(minuti) \(word)",
            it: "pulizia della tastiera, \(minuti) \(parola)"
        )
    }
    public static var logWipeManual: String {
        L.t(en: "keyboard cleaning ended by hand", it: "pulizia finita, uscita a mano")
    }
    public static var logWipeExpired: String {
        L.t(en: "keyboard cleaning ended when time ran out", it: "pulizia finita, tempo scaduto")
    }
    public static var logWipeWatchdog: String {
        L.t(
            en: "watchdog ended cleaning because the timer did not fire",
            it: "pulizia chiusa dal cane da guardia: il timer non era scattato"
        )
    }
    public static var logWipeNoAX: String {
        L.t(
            en: "started keyboard cleaning without Accessibility permission, leaving function keys unblocked",
            it: "pulizia senza permesso di Accessibilità: i tasti funzione non sono bloccati"
        )
    }
    /// Un modificatore era rimasto premuto per il sistema quando la pulizia si è chiusa. Riga rara
    /// per costruzione: senza, di un guasto che si ripara da solo alla pressione dopo non resta
    /// niente da leggere il giorno dopo.
    public static func logWipeStuckModifiers(_ tasti: String) -> String {
        L.t(
            en: "reset \(tasti) after the system left them held down when cleaning ended",
            it: "alla chiusura della pulizia il sistema teneva ancora premuto \(tasti): rimessi a zero"
        )
    }
    public static var logWipeSecureInput: String {
        L.t(
            en: "another app is using secure input, so the keys bypass NoSleep and cannot all be blocked",
            it: "un'altra app tiene l'input protetto: i tasti non passano da noi e non possiamo bloccarli tutti"
        )
    }

    // ── La riga di comando ──────────────────────────────────────────────────

    public static var cliUsage: String {
        L.t(
            en: """
            nosleep — claims for NoSleep

              nosleep hold --id <x> [--ttl <seconds>] [--label <text>]
              nosleep release --id <x>
              nosleep status [--json]
              nosleep list

            A claim means "this job is alive". It always has an expiry: if whoever took it dies
            without releasing it, it expires on its own and the Mac can sleep again.
            """,
            it: """
            nosleep — prenotazioni per NoSleep

              nosleep hold --id <x> [--ttl <secondi>] [--label <testo>]
              nosleep release --id <x>
              nosleep status [--json]
              nosleep list

            Una prenotazione dice «questo lavoro è vivo». Ha sempre una scadenza: se chi l'ha presa muore
            senza restituirla, scade da sola e il Mac torna a poter dormire.
            """
        )
    }
    public static var claimNeedsID: String {
        L.t(en: "--id is required", it: "serve --id")
    }
    public static func claimWriteFailed(_ path: String) -> String {
        L.t(
            en: "could not write the claim to \(path)",
            it: "non sono riuscito a scrivere la prenotazione in \(path)"
        )
    }
    public static func claimHeld(_ id: String, ttl: Int, alive: Int) -> String {
        L.t(
            en: "held \(id) for \(ttl)s — alive: \(alive)",
            it: "prenotato \(id) per \(ttl)s — vive: \(alive)"
        )
    }
    public static func claimReleased(_ id: String, existed: Bool, alive: Int) -> String {
        let result = existed
            ? L.t(en: "released", it: "restituito")
            : L.t(en: "was not there", it: "non c'era")
        return L.t(
            en: "\(result) \(id) — alive: \(alive)",
            it: "\(result) \(id) — vive: \(alive)"
        )
    }
    public static var noLiveClaims: String {
        L.t(en: "no live claims", it: "nessuna prenotazione viva")
    }
    public static func liveClaim(_ id: String, label: String, secondsLeft: Int) -> String {
        L.t(
            en: "\(id)  \(label)  expires in \(secondsLeft)s",
            it: "\(id)  \(label)  scade fra \(secondsLeft)s"
        )
    }
    public static func unknownCommand(_ command: String) -> String {
        L.t(en: "unknown command: \(command)", it: "comando sconosciuto: \(command)")
    }

    // ── Il daemon ───────────────────────────────────────────────────────────

    public static var helperNeedsArguments: String {
        L.t(
            en: "nosleep-helper: --uid and --request are required",
            it: "nosleep-helper: servono --uid e --request"
        )
    }
    public static var helperResetAtStart: String {
        L.t(
            en: "starting: setting SleepDisabled to 0 before reading any request",
            it: "avvio: porto SleepDisabled a 0 prima di leggere qualunque richiesta"
        )
    }
    public static var helperSleepDisabled: String {
        L.t(
            en: "sleep disabled: the app is requesting it and its heartbeat is alive",
            it: "sonno disattivato: l'app lo chiede e sta battendo"
        )
    }
    public static func helperSleepEnabled(requestOwned: Bool) -> String {
        let reason = requestOwned
            ? L.t(
                en: "request dropped or heartbeat stopped",
                it: "richiesta caduta o battito fermo"
            )
            : L.t(en: "no valid request", it: "nessuna richiesta valida")
        return L.t(
            en: "sleep enabled: \(reason)",
            it: "sonno riattivato: \(reason)"
        )
    }
    public static func helperPmsetFailed(_ value: Int) -> String {
        L.t(
            en: "pmset failed setting SleepDisabled to \(value)",
            it: "pmset ha fallito puntando a \(value)"
        )
    }

    // ── L'installazione dell'helper ─────────────────────────────────────────

    public static var helperInstallScriptMissing: String {
        L.t(
            en: "the install script is not in the bundle",
            it: "lo script di installazione non è nel bundle"
        )
    }
    public static var helperScriptMissing: String {
        L.t(en: "the script is not in the bundle", it: "lo script non è nel bundle")
    }
    public static var cannotLaunchOsascript: String {
        L.t(en: "could not launch osascript", it: "non riesco a lanciare osascript")
    }
    public static var helperPartlyInstalled: String {
        L.t(en: "only partly installed", it: "installato a metà")
    }
    public static var helperRemovalFailed: String {
        L.t(en: "removal failed", it: "rimozione fallita")
    }

    public static var installCancelled: String {
        L.t(
            en: "Working with the lid closed needs your admin password once. Try again when you are ready.",
            it: "Per il coperchio chiuso serve la password di amministratore, una volta sola."
        )
    }
    public static func installFailed(_ why: String) -> String {
        L.t(
            en: "Working with the lid closed is not set up. \(why) Try again.",
            it: "Non è riuscita. \(why)"
        )
    }
}
