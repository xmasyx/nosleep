import SwiftUI
import NoSleepCore

@main
struct NoSleepApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(ShotDelegate.self) private var shot

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            // L'icona dice a colpo d'occhio che cosa sta facendo (ISC-42): le zeta quando il Mac è
            // libero di dormire, il fulmine vuoto quando il lavoro va avanti da solo, il fulmine
            // pieno quando resta acceso anche il display.
            //
            // La cornice fissa è il pezzo che tiene fermo il pannello: `MenuBarExtra` ancora la
            // finestra all'elemento, e un elemento che cambia larghezza la fa scivolare di lato.
            // Fissata qui, la scelta dei glifi torna libera.
            // L'altezza torna quella di serie di SwiftUI (2026-08-12): dichiararla a 12 per
            // pareggiare le app sorelle era stato provato e rimesso indietro lo stesso giorno, su
            // richiesta di chi la guarda tutti i giorni. La misura resta in `Icons`.
            Image(systemName: model.glyph)
                .frame(width: Icons.frameWidth)
        }
        .menuBarExtraStyle(.window)
    }
}
