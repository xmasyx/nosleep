import Foundation

/// Il filtro dei modificatori durante la pulizia della tastiera.
///
/// **Il problema che risolve, in una riga: ingoiare un modificatore è necessario, ingoiarne il
/// rilascio è un guasto.** Le due cose sembrano la stessa e non lo sono, e fra il 2026-08-29 e
/// oggi l'app ha tenuto la scelta larga — passavano tutti i `flagsChanged`, pressioni comprese —
/// perché era l'unica che si sapeva sicura.
///
/// **Il prezzo di quella scelta, visto da lui il 2026-09-18.** Kalamos ha come grilletto un
/// modificatore nudo (⌥, `HotkeyManager.modifierMasks`), riconosciuto proprio sui `flagsChanged`:
/// lo straccio che passa sull'Option apriva una dettatura **mentre lo schermo era nero**, e la
/// dettatura restava aperta da sé. Cioè il blocco tasti lasciava passare l'unica classe di eventi
/// che un'altra app usa come comando.
///
/// **La regola qui dentro tiene le due cose insieme, e l'idea è un registro di ciò che le app di
/// sotto hanno visto.** Al momento dell'armamento si guarda quali modificatori sono già premuti:
/// quelli, e solo quelli, le app di sotto credono premuti. Da lì:
///
///   * un evento che **rilascia** qualcosa di quel registro passa, con i flag riscritti a ciò che
///     resta del registro — così chi sta sotto torna esattamente allo stato che aveva;
///   * ogni altro evento si **ingoia**, perché è la pressione di un tasto che nessuno sotto ha
///     visto: nessuno resta con un tasto premuto, e nessuna scorciatoia globale parte.
///
/// Nel caso normale — mani sullo straccio, nessun modificatore premuto quando parte la pulizia —
/// il registro è vuoto e **non passa niente**, che è quello che «tasti bloccati» vuol dire.
///
/// Il tipo è puro e lavora su maschere di bit (`UInt64`, i valori di `CGEventFlags`) per stare in
/// `NoSleepCore` e poter essere provato senza finestre, senza permessi e senza un Mac con le mani
/// sopra — il banco usa questo stesso file, non una sua parafrasi.
public struct WipeFilter: Equatable, Sendable {

    /// I modificatori che si **tengono premuti**, come li vede CoreGraphics.
    ///
    /// Il maiuscolo bloccato (`maskAlphaShift`, 0x10000) **non è qui dentro di proposito**: non è
    /// un tasto che si tiene, è un interruttore, e lo stato che lascia dietro non si difende
    /// ingoiando l'evento — la commutazione avviene in uno strato più basso del nostro tap. Quello
    /// si ingoia sempre (nessuna app deve vederlo) e si rimette a posto alla fine, in `WipeScreen`.
    public static let heldMask: UInt64 = 0x0002_0000   // ⇧ shift
        | 0x0004_0000                                  // ⌃ control
        | 0x0008_0000                                  // ⌥ alternate
        | 0x0010_0000                                  // ⌘ command
        | 0x0080_0000                                  // fn

    /// Che fare di un `flagsChanged`.
    public enum Decision: Equatable, Sendable {
        /// Non arriva a nessuno.
        case swallow
        /// Passa, **dopo** aver riscritto i flag dell'evento a questo valore: i modificatori premuti
        /// durante la pulizia non devono comparire di sorpresa nelle app di sotto.
        case pass(flags: UInt64)
    }

    /// Quello che le app di sotto credono ancora premuto.
    private var seen: UInt64

    /// `heldAtStart` è lo stato vero dei modificatori quando la pulizia comincia
    /// (`CGEventSource.flagsState`), non un'ipotesi.
    public init(heldAtStart: UInt64) {
        seen = heldAtStart & Self.heldMask
    }

    /// Solo per i test e per il registro: cosa resta in mano alle app di sotto.
    public var seenBelow: UInt64 { seen }

    /// La decisione, e aggiorna il registro quando lascia passare un rilascio.
    public mutating func modifiers(now: UInt64) -> Decision {
        let ancora = now & seen
        guard ancora != seen else { return .swallow }
        seen = ancora
        return .pass(flags: ancora)
    }
}
