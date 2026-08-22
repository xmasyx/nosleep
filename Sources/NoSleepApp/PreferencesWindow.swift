import AppKit
import SwiftUI
import NoSleepCore

/// Le Preferenze, in una finestra vera.
///
/// **Perché esistono, e perché ripetono il pannello.** Qui c'è **tutto**; il pannello della barra
/// dei menu è la scorciatoia ai comandi che si toccano ogni giorno. Chi cerca un'impostazione la
/// trova sempre in Preferenze, senza dover ricordare in quale delle due finestre l'abbiamo messa.
///
/// Era stato fatto al contrario per un giro (le impostazioni **solo** qui, tolte dal pannello) e lui
/// l'ha corretto: *«credo sia meglio avere accesso a tutte le opzioni quando sono in preferenze»*.
/// Ha ragione, ed è anche il modo in cui si comportano le app di sistema.
///
/// **La politica di attivazione non si tocca, e questa è una correzione del 2026-08-07.**
///
/// Kalamos e Otium passano a `.regular` per far venire avanti la finestra e tornano `.accessory`
/// chiudendola. Qui l'ho copiato, e il risultato è stato che **dopo aver chiuso le Preferenze il
/// fulmine nella barra dei menu smetteva di rispondere al clic**: cambiare politica di attivazione
/// scombina l'elemento nella barra, che è proprio la cosa che questa app è.
///
/// Non serviva nemmeno: un'app `.accessory` può mostrare finestre e quelle finestre possono
/// diventare chiave. `.regular` serve per avere icona nel Dock e barra dei menu propria, che qui
/// non vogliamo. Quindi la politica resta `.accessory` sempre, e il banco lo verifica.
///
/// Resta invece vera la seconda trappola ereditata: una finestra dimensionata sul contenuto può
/// nascere più alta dello schermo, essere centrata, e finire col bordo inferiore sotto la
/// scrivania. Il tetto è il frame **visibile**, già al netto della barra dei menu e del Dock.
@MainActor
final class PreferencesWindow: NSObject {
    static let shared = PreferencesWindow()
    private var window: NSWindow?

    func show(model: AppModel) {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: PreferencesView(model: model))
        let wanted = hosting.view.fittingSize
        let limit = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
            ?? NSSize(width: 1200, height: 800)
        let size = NSSize(width: min(max(wanted.width, 420), limit.width - 40),
                          height: min(max(wanted.height, 300), limit.height - 40))

        let w = NSWindow(contentViewController: hosting)
        w.title = "Preferenze di NoSleep"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.titlebarAppearsTransparent = true
        // Va DIETRO cambiando app, non sparisce: `hidesOnDeactivate` fa svanire le impostazioni che
        // stavi leggendo appena clicchi altrove, ed è la lezione già pagata su Kalamos.
        w.hidesOnDeactivate = false
        w.isReleasedWhenClosed = false
        w.setContentSize(size)
        w.center()
        window = w

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var s: SurfacePalette { scheme == .dark ? Surface.sera : Surface.giorno }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rows.awake(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.lid(model: model, s: s)
            Divider().overlay(Color(s.rule))
            // Subito sotto il coperchio, perché è la stessa cosa detta una volta per sempre invece
            // che ogni volta a mano.
            Rows.lidFollow(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.auto(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.release(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.battery(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.wipe(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.wipeAccess(model: model, s: s)
            Divider().overlay(Color(s.rule))
            Rows.login(model: model, s: s)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 460, alignment: .leading)
        .background(Color(s.paper))
    }
}
