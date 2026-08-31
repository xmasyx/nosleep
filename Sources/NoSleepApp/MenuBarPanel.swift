import AppKit

/// Chiudere il pannello della barra dei menu.
///
/// **Perché è rimasta una funzione anche adesso che il pannello è nostro.** Serve nel momento in
/// cui si aprono le Preferenze da dentro il pannello: la finestra nuova nasceva **dietro** un
/// pannello ancora aperto, e lui vedeva le Preferenze solo dopo aver cliccato altrove (sua
/// osservazione, 2026-08-07). Il pannello va chiuso prima, e i chiamanti chiamano questo.
///
/// **Com'era, e perché non poteva reggere.** Fino al 2026-08-31 il pannello lo disegnava
/// `MenuBarExtra`, che non espone la propria finestra: questa funzione la cercava **per nome di
/// classe** fra tre candidati (`NSStatusBarWindow`, `MenuBarExtraWindow`, `NSPopoverWindow`),
/// nomi interni ad AppKit che nessuno ci garantiva e che nessuna sonda avrebbe visto cambiare.
/// Adesso la finestra è `PanelWindow`, la costruiamo noi, e chiudere vuol dire chiederlo
/// all'oggetto che la possiede.
@MainActor
enum MenuBarPanel {

    static func dismiss() {
        StatusPanel.current?.close()
    }

    /// Che finestre ci sono adesso. Resta per le sonde, e adesso risponde a una domanda con una
    /// risposta certa invece che a un indovinello sui nomi interni di AppKit.
    static func visibleWindowClasses() -> [String] {
        NSApp.windows.filter(\.isVisible).map(\.className)
    }
}
