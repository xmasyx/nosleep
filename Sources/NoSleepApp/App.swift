import SwiftUI
import NoSleepCore

@main
struct NoSleepApp: App {
    @StateObject private var model: AppModel
    @NSApplicationDelegateAdaptor(ShotDelegate.self) private var shot

    init() {
        // Il modello nasce prima del delegate: la sonda va dirottata qui o il suo primo giro
        // toccherebbe per davvero configurazione, registro e richiesta all'helper.
        if ShotDelegate.isProbe { Paths.homeOverride = ShotDelegate.sandbox() }
        let model = AppModel()
        _model = StateObject(wrappedValue: model)
        // Il delegate lo raccoglie a lancio finito per costruirci l'elemento nella barra. Passa da
        // una statica e non da un parametro perché `@NSApplicationDelegateAdaptor` costruisce il
        // delegate da sé, senza che nessuno possa passargli niente.
        ShotDelegate.liveModel = model

        guard CommandLine.arguments.contains("--bench-updates") else { return }
        Task { @MainActor in
            exit(await model.updater.runBench())
        }
    }

    /// **Nessuna scena visibile, ed è voluto.**
    ///
    /// Fino al 2026-08-31 qui c'era un `MenuBarExtra` con `.menuBarExtraStyle(.window)`, cioè una
    /// finestra disegnata da SwiftUI, e da quella scelta venivano i tre difetti che lui ha
    /// fotografato lo stesso giorno: sedici punti di distacco dalla barra, angoli quadrati e una
    /// larghezza scritta a mano. Nessuno dei tre era riparabile da dentro, perché la finestra la
    /// posiziona SwiftUI e non ne espone né l'origine né la forma.
    ///
    /// L'elemento nella barra e il suo pannello adesso sono AppKit e vivono in `StatusPanel`,
    /// come in Kalamos e Otium. L'icona non è più dichiarata qui: la disegna `StatusPanel` dallo
    /// stesso `model.glyph`, quindi le tre regole di `Icons` (tre stati, tre segni, cornice fissa)
    /// valgono identiche.
    ///
    /// Questa scena vuota serve solo perché un `App` deve dichiararne una. L'app è `LSUIElement`,
    /// quindi non possiede la barra dei menu e la voce «Impostazioni» non compare da nessuna
    /// parte; le Preferenze vere restano una finestra AppKit aperta dal pannello.
    var body: some Scene {
        Settings { EmptyView() }
    }
}
