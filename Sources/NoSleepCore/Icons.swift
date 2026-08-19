import Foundation

/// Che cosa si vede nella barra dei menu, e perché quella cosa lì.
///
/// **La cornice fissa è il pezzo che tiene fermo il pannello.** `MenuBarExtra` ancora la finestra
/// all'elemento nella barra: se l'elemento cambia larghezza cambiando stato, il pannello **si
/// sposta di lato** sotto il dito di chi lo sta usando. È successo passando da `bolt.fill` (15pt) a
/// `bolt.horizontal.fill` (24pt), e lui se n'è accorto subito. La riparazione non sta nella scelta
/// dei simboli, sta in `Icons.frameWidth`: una larghezza sola per tutti gli stati, qualunque cosa ci
/// stia dentro. Il banco `--selftest-icons` verifica il vincolo residuo, cioè che nessun simbolo sia
/// più largo della cornice, e lo verifica col suo polo negativo.
///
/// **Tre stati, tre segni fermi:**
///
/// - a riposo, `zzz`: il Mac può addormentarsi;
/// - il lavoro va avanti e il display è libero di spegnersi: il **fulmine vuoto**;
/// - il lavoro va avanti **e** il display resta acceso: il **fulmine pieno**.
///
/// **I due stati attivi sono di nuovo lo stesso segno in due pesi, e stavolta col verso giusto**
/// (sua scelta, 2026-08-12, dopo mezza giornata di tazza). L'11/08 li aveva separati proprio perché
/// due pesi si distinguono male, ma allora il pieno stava sullo stato *minore*: adesso il pieno vuol
/// dire **anche il display**, cioè di più, e un peso che cresce insieme a ciò che descrive si legge
/// senza pensarci. Il prezzo del segno diverso era la larghezza: `mug` misura 19 punti contro i 15
/// del fulmine, e nella barra si vedeva.
///
/// **Il cavallo al galoppo è stato qui un giorno, ed è uscito il 12/08 perché costava.** Misurato
/// sull'app installata e non su una sonda: 5,96 secondi di CPU ogni 30 di orologio, cioè **il 19,9%
/// di un core**, per sempre, in un'app che esiste per non sprecare energia. Il disegno resta nel
/// repo (`Horse.swift`, `HorseImage`, `Scripts/horse-frames.ts`, sonda `--selftest-horse`), e
/// rimetterlo nella barra è una riga qui sotto. La lezione, che vale oltre questa app: **un'icona
/// animata non si paga in disegno, si paga in ridisegni dell'interfaccia**, e il commento che
/// stimava «qualche punto percentuale» era di sei volte sotto il vero.
///
/// **Perché il segno pieno sta sullo stato «schermo e attività» e non sull'altro.** «Solo attività»
/// è lo stato in cui il Mac lavora e nessuno lo guarda, ed è quello in cui lui vive; l'altro tiene
/// acceso **anche** il display, cioè aggiunge qualcosa, e il pieno è come si scrive «aggiunge».
///
/// **Perché non c'è un quarto stato per il coperchio.** Con il coperchio abbassato lo schermo è
/// spento e quell'icona non la vedrebbe nessuno proprio quando sarebbe in uso. Il punto delicato è
/// un altro, ed è costato un difetto vissuto per una settimana: la presa del coperchio **armata**
/// non è il coperchio **abbassato**. Con «prepara il coperchio» accesa — la sua configurazione — la
/// presa si arma insieme a «tieni sveglio», cioè a ogni lavoro; farla decidere qui voleva dire
/// cancellare la modalità e mostrare il fulmine vuoto per sempre, anche in «schermo e attività»
/// (suo referto, 2026-08-19). Il peso lo decide la modalità e nient'altro. Lo stato del coperchio si
/// legge nel pannello, dove si può leggere.
public enum Icons {
    /// Niente in presa: il Mac può andare in sleep.
    public static let idle = "zzz"
    /// Il lavoro va avanti da solo e il display può spegnersi. **Vuoto.**
    public static let awakeActivity = "bolt"
    /// Tiene tutto: display acceso e sistema sveglio. **Pieno, perché tiene una cosa in più.**
    public static let awakeScreen = "bolt.fill"

    /// La larghezza fissa dell'etichetta nella barra.
    ///
    /// **Diciotto, che è la misura di prima del cavallo.** Era salita a 22 l'11/08 per far stare la
    /// sua cornice, ed è rimasta lì un giorno di troppo: **quello che occupa spazio nella barra è
    /// questa costante, non il simbolo**, quindi con i glifi tornati stretti i quattro punti in più
    /// erano aria pagata da lui e li ha visti (2026-08-12). Il più largo dei tre è `zzz` con sedici,
    /// quindi diciotto lascia un punto per parte e nessuno viene tagliato.
    ///
    /// Fissa, e questo non cambia mai: `MenuBarExtra` ancora il pannello all'elemento, e un elemento
    /// che cambia larghezza fra uno stato e l'altro se lo porta di lato sotto il dito.
    public static let frameWidth: Double = 18

    /// **Quanto è alto ciascun segno nella barra, misurato il 2026-08-12** e tenuto qui perché
    /// costa una fotografia ricavarlo: il fulmine sta a **14** punti, mentre altri simboli di
    /// sistema stanno a 12 e a 9 dentro cornici già identiche. Pareggiarli è stato provato e
    /// rimesso indietro lo stesso giorno: le altezze di serie restano quelle buone.
    ///
    /// Non è un'impostazione e non va letta da nessuno: è il numero che evita di rimisurare.

    /// L'altezza a cui la sonda `--selftest-horse` disegna il cavallo. Quindici punti è l'altezza a
    /// cui macOS rende i simboli di sistema in una barra da ventidue.
    public static let horseHeight: Double = 15

    /// I simboli che possono comparire nella barra. Il banco li misura uno per uno.
    public static let all = [idle, awakeActivity, awakeScreen]

    public static func glyph(awake: Bool, mode: AwakeMode, lid lidOn: Bool) -> String {
        guard awake || lidOn else { return idle }
        // Solo il coperchio armato, senza «tieni sveglio»: il Mac non si addormenta ma il display è
        // libero di spegnersi, che è esattamente «solo attività».
        guard awake else { return awakeActivity }
        // `lidOn` NON è il coperchio abbassato, è la presa del coperchio armata — e con «prepara il
        // coperchio» accesa si arma insieme a «tieni sveglio», cioè sempre. Farla decidere qui
        // cancellava la modalità e il fulmine restava vuoto anche in «schermo e attività»
        // (suo referto, 2026-08-19). La modalità è l'unica cosa che decide il peso.
        return mode == .screenAndActivity ? awakeScreen : awakeActivity
    }
}
