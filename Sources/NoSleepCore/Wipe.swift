import Foundation

/// Quanto dura una pulizia della tastiera.
///
/// **Tre durate e nessun campo libero, ed è una scelta di sicurezza.** Un cursore o un numero
/// scritto a mano aprirebbero la porta al blocco lungo un'ora, e un blocco lungo un'ora su una
/// tastiera che non risponde non è una funzione, è un Mac inutilizzabile. Il valore più alto è
/// cinque minuti perché è quello che basta a pulire uno schermo e una tastiera, ed è anche il tetto
/// che usa Mole, da cui la funzione viene.
public enum WipeDuration: Int, Codable, CaseIterable, Sendable, Equatable {
    case one = 60
    case two = 120
    case five = 300

    public var seconds: Double { Double(rawValue) }
    public var minutes: Int { rawValue / 60 }
    public var label: String { "\(minutes) min" }
}

/// La combinazione che interrompe la pulizia prima della scadenza.
///
/// **È la stessa di Mole, e non è una somiglianza cercata: è la richiesta esplicita del principale**
/// (2026-08-22). Misurata sull'app installata (Mole 1.12.1), che nel piede della sua schermata nera
/// scrive «Esci · Control Option Command Esc».
///
/// Tre modificatori e non uno solo perché un tasto solo si preme per sbaglio proprio mentre passi
/// lo straccio, che è l'unico momento in cui questa schermata esiste.
public enum WipeExit {
    /// Il codice del tasto Esc su qualunque tastiera Mac.
    public static let escapeKeyCode: UInt16 = 53

    /// Come si scrive nel piede della schermata. Le parole per esteso, non i simboli: ⌃⌥⌘ è
    /// illeggibile a mezzo metro dallo schermo, che è la distanza da cui si pulisce.
    public static let label = "Control Option Command Esc"

    /// Riconosce la combinazione.
    ///
    /// **Il maiuscolo non viene richiesto ed è deliberato**: se lui preme anche il maiuscolo per
    /// sbaglio la via d'uscita deve funzionare lo stesso. Su una via d'uscita si sbaglia sempre
    /// verso il permissivo — l'errore opposto lascia una persona davanti a una tastiera morta.
    public static func matches(keyCode: UInt16,
                               control: Bool,
                               option: Bool,
                               command: Bool) -> Bool {
        keyCode == escapeKeyCode && control && option && command
    }

    /// La via di fuga del sistema, ⌘⌥Esc, che la pulizia **lascia passare apposta**.
    ///
    /// È il pulsante di emergenza di macOS, e ingoiarlo insieme a tutto il resto significherebbe
    /// togliere l'ultima porta a chi si trovasse davanti a un'app impiantata. Costa un caso in più
    /// nel filtro e vale come seconda uscita indipendente da tutto il nostro codice.
    public static func isForceQuit(keyCode: UInt16,
                                   control: Bool,
                                   option: Bool,
                                   command: Bool) -> Bool {
        keyCode == escapeKeyCode && !control && option && command
    }
}

/// Il conto alla rovescia, come si legge.
public enum WipeClock {
    /// `mm:ss`, sempre due cifre, mai negativo.
    public static func countdown(remaining: Double) -> String {
        let s = max(0, Int(remaining.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

/// Una frase da un libro.
///
/// Testo, autore e opera separati: l'attribuzione va **sotto** la frase e in un altro corpo, quindi
/// deve restare un campo suo e non una coda incollata alla frase.
public struct Quote: Equatable, Sendable {
    public let text: String
    public let author: String
    public let work: String

    public init(_ text: String, _ author: String, _ work: String) {
        self.text = text
        self.author = author
        self.work = work
    }

    public var attribution: String { "\(author), \(work)" }
}

/// Il libro da cui la schermata nera pesca.
///
/// **Vincolo che decide il contenuto: questo repository è pubblico.** Una frase ancora sotto
/// copyright ci resterebbe dentro per sempre e in una licenza MIT, quindi ogni voce qui viene da
/// un'opera in pubblico dominio — l'autore più recente è Gabriele d'Annunzio, morto nel 1938, e la
/// soglia italiana sono settant'anni dalla morte. Per la stessa ragione **non sono le frasi di
/// Mole**: quelle sono il testo di qualcun altro, e copiarle in un repo pubblico sarebbe la cosa
/// sbagliata anche quando nessuno se ne accorge.
///
/// Sono tutte righe d'apertura o versi notissimi, e non è pigrizia: sono le uniche che si possono
/// riportare alla lettera senza rischiare di storpiare un testo che non ho sotto gli occhi.
public enum Quotes {
    public static let all: [Quote] = [
        Quote("Nel mezzo del cammin di nostra vita\nmi ritrovai per una selva oscura",
              "Dante Alighieri", "Inferno, I"),
        Quote("fatti non foste a viver come bruti,\nma per seguir virtute e canoscenza",
              "Dante Alighieri", "Inferno, XXVI"),
        Quote("l'amor che move il sole e l'altre stelle",
              "Dante Alighieri", "Paradiso, XXXIII"),
        Quote("Libertà va cercando, ch'è sì cara",
              "Dante Alighieri", "Purgatorio, I"),
        Quote("Sempre caro mi fu quest'ermo colle",
              "Giacomo Leopardi", "L'infinito"),
        Quote("e il naufragar m'è dolce in questo mare",
              "Giacomo Leopardi", "L'infinito"),
        Quote("Silvia, rimembri ancora\nquel tempo della tua vita mortale",
              "Giacomo Leopardi", "A Silvia"),
        Quote("Quel ramo del lago di Como, che volge a mezzogiorno,\ntra due catene non interrotte di monti",
              "Alessandro Manzoni", "I promessi sposi, I"),
        Quote("Addio, monti sorgenti dall'acque, ed elevati al cielo",
              "Alessandro Manzoni", "I promessi sposi, VIII"),
        Quote("A egregie cose il forte animo accendono\nl'urne de' forti",
              "Ugo Foscolo", "Dei sepolcri"),
        Quote("Forse perché della fatal quïete\ntu sei l'immago a me sì cara vieni",
              "Ugo Foscolo", "Alla sera"),
        Quote("Voi ch'ascoltate in rime sparse il suono",
              "Francesco Petrarca", "Canzoniere, I"),
        Quote("Le donne, i cavallier, l'arme, gli amori,\nle cortesie, l'audaci imprese io canto",
              "Ludovico Ariosto", "Orlando furioso, I"),
        Quote("Umana cosa è aver compassione degli afflitti",
              "Giovanni Boccaccio", "Decameron, Proemio"),
        Quote("La filosofia è scritta in questo grandissimo libro\nche continuamente ci sta aperto innanzi agli occhi",
              "Galileo Galilei", "Il Saggiatore"),
        Quote("La nebbia a gl'irti colli\npiovigginando sale",
              "Giosuè Carducci", "San Martino"),
        Quote("San Lorenzo, io lo so perché tanto\ndi stelle per l'aria tranquilla\narde e cade",
              "Giovanni Pascoli", "X Agosto"),
        Quote("Taci. Su le soglie\ndel bosco non odo\nparole che dici\numane",
              "Gabriele d'Annunzio", "La pioggia nel pineto"),
        Quote("C'era una volta un pezzo di legno",
              "Carlo Collodi", "Le avventure di Pinocchio"),
        Quote("Un tempo i Malavoglia erano stati numerosi\ncome i sassi della strada vecchia di Trezza",
              "Giovanni Verga", "I Malavoglia, I"),
    ]

    /// Ne pesca una. L'indice arriva da fuori — dal caso o da un banco — così la scelta resta
    /// riproducibile e questo file non ha bisogno di un generatore di numeri casuali dentro.
    public static func pick(_ index: Int) -> Quote {
        let n = all.count
        let i = ((index % n) + n) % n
        return all[i]
    }

    public static func random() -> Quote { pick(Int.random(in: 0..<all.count)) }
}
