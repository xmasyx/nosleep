import Testing
import Foundation
@testable import NoSleepCore

/// Il filtro dei modificatori, che è la parte del blocco tasti dove si sbaglia.
///
/// Due guasti opposti, e i test esistono per tenerli lontani entrambi: ingoiare troppo poco lascia
/// partire la dettatura di Kalamos sull'⌥ (visto il 2026-09-18), ingoiare troppo lascia un tasto
/// premuto per sempre nelle app di sotto (visto il 2026-08-28). Nessuno dei due si vede a occhio.
struct WipeFilterTests {

    // I valori veri di `CGEventFlags`, scritti a mano perché questo modulo non importa CoreGraphics.
    static let shift: UInt64 = 0x0002_0000
    static let control: UInt64 = 0x0004_0000
    static let option: UInt64 = 0x0008_0000
    static let command: UInt64 = 0x0010_0000
    static let caps: UInt64 = 0x0001_0000

    /// Il caso normale: mani sullo straccio, niente premuto quando parte la pulizia. **Non passa
    /// niente**, che è la richiesta del principale: i tasti devono essere bloccati per davvero.
    @Test func aMaiVuotoIngoiaTutto() {
        var f = WipeFilter(heldAtStart: 0)
        #expect(f.modifiers(now: Self.option) == .swallow)      // ⌥ premuto dallo straccio
        #expect(f.modifiers(now: 0) == .swallow)                // e rilasciato
        #expect(f.modifiers(now: Self.command | Self.shift) == .swallow)
        #expect(f.seenBelow == 0)
    }

    /// Un modificatore già premuto quando la pulizia comincia: il suo rilascio **deve** passare,
    /// altrimenti l'app di sotto resta a credere premuto un tasto che la mano ha già mollato.
    @Test func bIlRilascioDiUnModificatoreGiaPremutoPassa() {
        var f = WipeFilter(heldAtStart: Self.command)
        #expect(f.modifiers(now: Self.command) == .swallow)     // ancora premuto: niente da dire
        #expect(f.modifiers(now: 0) == .pass(flags: 0))         // mollato: le app di sotto lo sappiano
        #expect(f.seenBelow == 0)
        #expect(f.modifiers(now: Self.command) == .swallow)     // e da qui in poi è muto
    }

    /// Il caso che unisce i due: ⌘ tenuto all'avvio, ⌥ premuto dallo straccio durante. Il rilascio
    /// del ⌘ passa **con i flag riscritti**, cioè senza portarsi dietro l'⌥ che nessuno ha visto.
    @Test func cIlRilascioNonPortaDietroIlTastoDelloStraccio() {
        var f = WipeFilter(heldAtStart: Self.command)
        #expect(f.modifiers(now: Self.command | Self.option) == .swallow)
        #expect(f.modifiers(now: Self.option) == .pass(flags: 0))
        #expect(f.seenBelow == 0)
    }

    /// Due modificatori all'avvio si mollano uno per volta, e ogni passaggio dice la verità su
    /// quello che resta.
    @Test func dDueModificatoriSiMollanoUnoPerVolta() {
        var f = WipeFilter(heldAtStart: Self.command | Self.shift)
        #expect(f.modifiers(now: Self.shift) == .pass(flags: Self.shift))
        #expect(f.seenBelow == Self.shift)
        #expect(f.modifiers(now: 0) == .pass(flags: 0))
        #expect(f.seenBelow == 0)
    }

    /// Il maiuscolo bloccato non è un tasto che si tiene: non entra nel registro, quindi non c'è
    /// nessun caso in cui un suo evento passi. Lo stato che lascia si ripara alla fine, altrove.
    @Test func eIlMaiuscoloBloccatoNonEntraNelRegistro() {
        var f = WipeFilter(heldAtStart: Self.caps | Self.command)
        #expect(f.seenBelow == Self.command)
        #expect(f.modifiers(now: Self.caps | Self.command) == .swallow)
        #expect(f.modifiers(now: Self.command) == .swallow)     // caps spento: nessuno lo sapeva
        #expect(WipeFilter.heldMask & Self.caps == 0)
    }

    /// La proprietà che vale per QUALUNQUE sequenza, ed è la ragione d'essere del tipo: il registro
    /// non cresce mai. Un modificatore premuto durante la pulizia non può finire fra quelli che le
    /// app di sotto credono premuti, quindi alla fine non resta niente da riparare.
    @Test func fIlRegistroNonCresceMai() {
        let tasti = [Self.shift, Self.control, Self.option, Self.command]
        var f = WipeFilter(heldAtStart: Self.control)
        var precedente = f.seenBelow
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            let now = tasti.reduce(UInt64(0)) { $0 | (Bool.random(using: &rng) ? $1 : 0) }
            _ = f.modifiers(now: now)
            #expect(f.seenBelow & ~precedente == 0)
            precedente = f.seenBelow
        }
        #expect(f.seenBelow & ~Self.control == 0)
    }
}
