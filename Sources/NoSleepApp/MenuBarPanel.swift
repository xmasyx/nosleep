import AppKit

/// Chiudere il pannello della barra dei menu.
///
/// **Perché serve una funzione e non una riga.** `MenuBarExtra` non espone la sua finestra: SwiftUI
/// la crea, la mostra e la toglie da solo quando clicchi fuori. Aprendo le Preferenze da dentro il
/// pannello, la finestra nuova nasceva **dietro** un pannello ancora aperto, e lui vedeva le
/// Preferenze solo dopo aver cliccato altrove.
///
/// La finestra si riconosce dalla classe, che in SwiftUI si chiama `NSStatusBarWindow`. Il nome è
/// interno ad AppKit e potrebbe cambiare, perciò **si cerca senza forzare**: se un domani non la
/// trova, non chiude niente e non rompe niente, esattamente come prima.
@MainActor
enum MenuBarPanel {

    /// I nomi di classe visti finora. Più di uno perché il pannello disegnato (`.window`) e il menu
    /// classico non usano la stessa finestra, e non voglio scommettere su quale sia oggi.
    private static let names = ["NSStatusBarWindow", "MenuBarExtraWindow", "NSPopoverWindow"]

    static func dismiss() {
        for w in NSApp.windows where names.contains(where: { w.className.contains($0) }) {
            guard w.isVisible else { continue }
            // `orderOut` e non `close`: la finestra è di SwiftUI, che la crea e la distrugge per
            // conto suo. Chiuderla gliela toglie di mano e le lascia lo stato «aperta», con il
            // risultato che il clic dopo sull'icona non fa niente. Nasconderla la lascia viva.
            w.orderOut(nil)
        }
    }

    /// Che finestre ci sono adesso, per la sonda: se un giorno il nome cambia, questa lo dice.
    static func visibleWindowClasses() -> [String] {
        NSApp.windows.filter(\.isVisible).map(\.className)
    }
}
