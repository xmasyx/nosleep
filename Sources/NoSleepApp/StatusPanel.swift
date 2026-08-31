import AppKit
import Combine
import SwiftUI
import NoSleepCore

/// Il pannello della barra dei menu, ancorato al suo elemento e disegnato da noi.
///
/// **Perché non è più `MenuBarExtra`.** Fino al 2026-08-31 il pannello era una scena SwiftUI
/// (`.menuBarExtraStyle(.window)`), e quella scelta produceva tre difetti che lui ha visto tutti
/// insieme in una fotografia: la carta cominciava a **49 punti** dall'alto mentre la barra dei menu
/// finisce a **33** — sedici punti di vuoto, che è la ragione per cui il pannello sembrava
/// *fluttuante* invece che attaccato; gli **angoli erano quadrati**, perché il nostro sfondo opaco
/// copriva la maschera arrotondata della finestra di SwiftUI; e la larghezza era una costante di
/// 340 punti che tagliava «Verifica aggiornamenti» e lo mandava su una seconda riga.
///
/// Nessuno dei tre si poteva riparare da dentro: la finestra la crea e la posiziona SwiftUI, che
/// non espone né l'origine né la forma. Kalamos e Otium non hanno il problema perché non disegnano
/// nessuna finestra — usano `NSStatusItem` più un menu di sistema, e attacco, angoli e ombra glieli
/// dà macOS. Qui la finestra resta nostra (le righe sono tutte interattive, e un `NSMenu` sopra
/// controlli SwiftUI è un terreno che non volevo scommettere), ma **la posizione e la forma le
/// decide questo file**, cioè un posto dove si possono leggere e cambiare.
@MainActor
final class StatusPanel: NSObject, NSWindowDelegate {

    /// **L'unico numero scelto e non misurato in questo file.**
    ///
    /// Il raggio dei menu di sistema non è leggibile da API pubbliche: la finestra di un menu è
    /// `NSPopupMenuWindow`, il suo `contentView.layer.cornerRadius` è **0** (verificato il
    /// 2026-08-31 ispezionando l'albero delle viste di un menu aperto) e la forma la disegna il
    /// window server. Fotografarlo per misurarlo è la strada normale ed è chiusa: `screencapture`
    /// vuole il permesso di Registrazione schermo, che qui non ha nessuno dei due processi che
    /// potrebbero scattare.
    ///
    /// Quindi questo dodici è una scelta dichiarata, da giudicare a occhio accanto a un menu vero.
    /// `.continuous` e non `.circular` perché è la curva che macOS usa da Big Sur in poi.
    static let cornerRadius: CGFloat = 12

    /// **Zero, ed è il punto di tutta la modifica.** Un menu di sistema comincia esattamente dove
    /// finisce la barra: qualunque numero più grande di zero rimette il difetto che questo file
    /// esiste per togliere.
    static let gapFromMenuBar: CGFloat = 0

    /// Quanto il pannello resta lontano dal bordo dello schermo quando l'elemento sta agli estremi.
    static let edgeMargin: CGFloat = 8

    /// Il bordo destro del pannello va **appena oltre** quello dell'elemento, così il pannello si
    /// apre verso sinistra restando agganciato all'icona. È dove SwiftUI lo metteva (misurato: 1438
    /// punti di bordo destro con l'icona a 1431) e a lui piace così: «il fatto che venga a sinistra
    /// è meglio delle altre che vengono fuori a destra».
    static let anchorOvershoot: CGFloat = 8

    /// La larghezza dell'elemento nella barra. **Fissa**, e non è pigrizia: un elemento che cambia
    /// larghezza cambiando icona si porta il pannello di lato sotto il dito di chi lo sta usando —
    /// difetto vissuto l'11/08, spiegato per esteso in `Icons.frameWidth`.
    static let itemLength: CGFloat = Icons.frameWidth + 12

    private let model: AppModel
    fileprivate let statusItem: NSStatusItem
    private var panel: PanelWindow?
    private var hosting: NSHostingView<AnyView>?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var observation: AnyCancellable?

    /// L'unico pannello vivo. Serve a `MenuBarPanel.dismiss()`, che lo chiude prima di aprire le
    /// Preferenze, e alla sonda che ne misura la larghezza.
    private(set) static weak var current: StatusPanel?

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: Self.itemLength)
        super.init()

        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        statusItem.button?.setButtonType(.momentaryChange)
        refreshIcon()

        // L'icona segue il modello. Con `MenuBarExtra` lo faceva SwiftUI osservando `model.glyph`;
        // adesso l'elemento è di AppKit e l'aggancio va scritto. `objectWillChange` arriva **prima**
        // che il valore cambi, quindi si rilegge al giro dopo.
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshIcon() }
        }

        Self.current = self
    }

    // ── L'elemento nella barra ───────────────────────────────────────────────

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        let image = NSImage(systemSymbolName: model.glyph, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        image?.isTemplate = true
        button.image = image
    }

    // ── Apertura e chiusura ──────────────────────────────────────────────────

    @objc private func toggle() {
        if panel?.isVisible == true { close() } else { open() }
    }

    func open() {
        let panel = panel ?? makePanel()
        self.panel = panel

        // La misura si rifà a ogni apertura, non una volta sola: lo stato cambia il testo (i gradi
        // compaiono solo quando l'app tiene qualcosa) e il testo cambia la larghezza.
        let size = fittingSize()
        panel.setFrame(NSRect(origin: origin(for: size), size: size), display: false)
        panel.orderFrontRegardless()
        panel.makeKey()
        statusItem.button?.isHighlighted = true
        startWatchingForDismissal()
    }

    func close() {
        stopWatchingForDismissal()
        statusItem.button?.isHighlighted = false
        panel?.orderOut(nil)
    }

    private func makePanel() -> PanelWindow {
        let host = NSHostingView(rootView: AnyView(PanelChrome(model: model)))
        hosting = host

        let panel = PanelWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        panel.contentView = host
        panel.delegate = self
        // Trasparente e senza sfondo di sistema: la carta e gli angoli li disegna `PanelChrome`, e
        // se la finestra dipingesse anche il suo, gli angoli tornerebbero quadrati per la stessa
        // ragione di prima.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    // ── Geometria ────────────────────────────────────────────────────────────

    /// Quanto vuole essere largo e alto il pannello, in due passi separati perché sono due domande
    /// diverse.
    ///
    /// **La larghezza non si chiede all'intero pannello.** La misura ideale di una nota che va a
    /// capo è tutta la frase su una riga, quindi chiedendola a tutto il contenuto usciva **779
    /// punti** (misurato il 31/08 alzando il tetto): il pannello sarebbe stato inchiodato al
    /// massimo per sempre, e la larghezza «dal contenuto» sarebbe stata una frase invece di un
    /// comportamento. La domanda giusta la fa solo la fila dei comandi, che è l'unica riga che non
    /// può andare a capo, e si misura montando **quella vista lì** — non ricalcolandola.
    ///
    /// **L'altezza si chiede dopo, alla larghezza decisa**, perché è la larghezza a stabilire
    /// quante righe prende ogni nota. Chiederle insieme è come misurare un testo prima di sapere
    /// quant'è largo il foglio.
    /// La larghezza del pannello, e **l'unico posto dove si calcola**.
    ///
    /// È `static` perché la usa anche `--scatta`: finché la sonda si sceglieva la propria misura
    /// (330 punti scritti a mano, contro i 340 del pannello vero) fotografava una superficie che
    /// nell'app non esisteva, ed è la ragione per cui non ha mai potuto vedere nessuno dei difetti
    /// del 31/08.
    static func contentWidth(for model: AppModel) -> CGFloat {
        let bar = NSHostingView(rootView: MenuView(model: model).footer)
        bar.layoutSubtreeIfNeeded()
        return min(MenuView.maxWidth, max(MenuView.minWidth, bar.fittingSize.width.rounded(.up)))
    }

    func fittingSize() -> NSSize {
        // **Si monta la riga intera, non i suoi pezzi.** Il primo giro misurava i soli comandi e
        // ci sommava a mano il respiro laterale: mancavano lo spazio e l'etichetta «NoSleep», e la
        // fotografia del 31/08 mostrava il piede tagliato **da tutte e due le parti**. Sommare a
        // mano i pezzi di una vista è riscriverne il layout in un secondo posto, che diverge alla
        // prima etichetta che cambia. Qui si chiede la misura a `footer`, che è esattamente la
        // vista che poi verrà disegnata; il testo di stato non vota, perché ha ideale zero.
        let width = Self.contentWidth(for: model)

        guard let host = hosting else { return NSSize(width: width, height: 100) }
        host.rootView = AnyView(PanelChrome(model: model).frame(width: width))
        host.layoutSubtreeIfNeeded()
        return NSSize(width: width, height: host.fittingSize.height)
    }

    /// Dove va l'angolo in basso a sinistra del pannello.
    ///
    /// **Il bordo alto della barra si legge da `visibleFrame`, non da `NSStatusBar.thickness`**:
    /// quel valore risponde 22 anche su un Mac col notch, dove la barra è alta 33 (misurato su
    /// questa macchina). Undici punti di errore sono esattamente il genere di sbaglio che il
    /// difetto originale aveva.
    private func origin(for size: NSSize) -> NSPoint {
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        guard let screen else { return .zero }

        let barBottom = screen.visibleFrame.maxY
        let y = barBottom - size.height - Self.gapFromMenuBar

        // **Il ripiego sul bordo destro dello schermo non è innocuo, ed è per questo che si vede.**
        // A fine lancio la finestra del bottone nella barra ha ancora rettangolo zero (trappola
        // già pagata in Otium, `--scatta-menu`), e un ancoraggio che in quel caso ripiega in
        // silenzio dà un pannello dall'altra parte dello schermo senza che niente lo dica. Qui il
        // ripiego resta, perché un pannello mal messo è meglio di nessun pannello, ma `anchorX`
        // lo espone e la sonda lo boccia.
        var x = anchorX(on: screen) + Self.anchorOvershoot - size.width
        x = min(x, screen.frame.maxX - Self.edgeMargin - size.width)
        x = max(x, screen.frame.minX + Self.edgeMargin)
        return NSPoint(x: x, y: y)
    }

    /// Il bordo destro dell'elemento nella barra, o `nil` se non è ancora al suo posto.
    private var anchorMaxX: CGFloat? {
        guard let f = statusItem.button?.window?.frame, f.width > 0 else { return nil }
        return f.maxX
    }

    private func anchorX(on screen: NSScreen) -> CGFloat {
        anchorMaxX ?? screen.frame.maxX
    }

    // ── Chiusura: clic fuori, Esc, perdita del fuoco ─────────────────────────

    private func startWatchingForDismissal() {
        stopWatchingForDismissal()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        // Il locale serve per Esc e **restituisce l'evento** quando non è Esc, altrimenti mangia
        // ogni tasto premuto dentro il pannello.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return event }   // 53 = esc
            Task { @MainActor in self?.close() }
            return nil
        }
    }

    private func stopWatchingForDismissal() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
    }

    nonisolated func windowDidResignKey(_ notification: Notification) {
        Task { @MainActor in self.close() }
    }

    // ── La sonda ─────────────────────────────────────────────────────────────

    /// `--misura-pannello` — stampa i due numeri che questo file esiste per riparare, e li boccia.
    ///
    /// **Perché una sonda e non un'occhiata.** I sedici punti di distacco sono stati scoperti da
    /// lui, in una fotografia, dopo settimane: erano invisibili a `--scatta`, che fotografava
    /// `MenuView` dentro una finestra costruita apposta e quindi non poteva vedere né la posizione
    /// né la forma del pannello vero. Un difetto di geometria che nessun banco misura torna.
    ///
    /// **Il polo negativo non è dichiarato, è calcolato:** la sonda stampa anche quanto sarebbe
    /// stato il distacco con la vecchia scena SwiftUI (49 punti misurati sulla sua fotografia del
    /// 31/08), così un verde a zero si legge accanto al rosso che sostituisce.
    /// **Aspetta prima di misurare.** A fine lancio l'elemento nella barra ha ancora rettangolo
    /// zero: misurando subito, il pannello risultava ancorato al bordo sinistro dello schermo, che
    /// non è un difetto dell'app ma della sonda. Ottocento millesimi sono la stessa attesa che
    /// Otium ha già dovuto imparare per `--scatta-menu`.
    ///
    /// Il timer è in `.common` e non un `asyncAfter`, così scatta anche mentre gira un ciclo di
    /// tracking.
    static func scheduleMeasure() {
        // L'elemento nasce **adesso**, la misura arriva dopo: è l'attesa a servire, e aspettare
        // senza aver ancora creato l'elemento non aspetterebbe niente.
        let model = AppModel()
        let panel = StatusPanel(model: model)
        panel.panel = panel.makePanel()
        let t = Timer(timeInterval: 0.8, repeats: false) { _ in
            MainActor.assumeIsolated { _ = measure(panel) }
        }
        RunLoop.main.add(t, forMode: .common)
    }

    private static func measure(_ panel: StatusPanel) -> Never {
        let size = panel.fittingSize()
        let origin = panel.origin(for: size)
        let screen = NSScreen.main!
        let barBottom = screen.visibleFrame.maxY
        let gap = barBottom - (origin.y + size.height)

        print("schermo: \(Int(screen.frame.width))×\(Int(screen.frame.height)) pt, barra alta \(Int(screen.frame.maxY - barBottom))")
        print("pannello: \(String(format: "%.1f", size.width)) × \(String(format: "%.1f", size.height)) pt")
        print("bordo alto del pannello: \(String(format: "%.1f", screen.frame.maxY - (origin.y + size.height))) pt dal bordo dello schermo")
        print("distacco dalla barra: \(String(format: "%.1f", gap)) pt   (con MenuBarExtra era 16,0 — sua foto del 31/08)")
        print("raggio degli angoli: \(cornerRadius) pt (scelto, non misurato: vedi il commento)")

        var rotto = false
        if abs(gap) > 0.5 {
            print("✗ il pannello non è attaccato alla barra: \(gap) pt di vuoto")
            rotto = true
        }
        if size.width < MenuView.minWidth - 0.5 || size.width > MenuView.maxWidth + 0.5 {
            print("✗ larghezza fuori dagli estremi \(MenuView.minWidth)–\(MenuView.maxWidth)")
            rotto = true
        }
        // Il pannello deve stare tutto dentro lo schermo, altrimenti «attaccato alla barra» si
        // sarebbe potuto ottenere spingendolo fuori dal bordo.
        if origin.x < screen.frame.minX || origin.x + size.width > screen.frame.maxX {
            print("✗ il pannello esce dallo schermo: x da \(origin.x) a \(origin.x + size.width)")
            rotto = true
        }
        // **L'ancoraggio si pretende, non si spera.** Senza questo polo la sonda restava verde
        // anche col pannello ancorato al bordo sinistro dello schermo, che è esattamente ciò che
        // è successo al primo giro perché l'elemento nella barra non era ancora al suo posto.
        if let ancora = panel.anchorMaxX {
            let scarto = (origin.x + size.width) - (ancora + anchorOvershoot)
            print("ancora: bordo destro dell'elemento a \(Int(ancora)) pt, pannello a \(Int(origin.x + size.width)) pt")
            if abs(scarto) > 0.5 {
                print("✗ il pannello non è agganciato all'elemento: \(scarto) pt di scarto")
                rotto = true
            }
        } else {
            print("✗ l'elemento nella barra non ha un rettangolo: l'ancoraggio non si può verificare")
            rotto = true
        }
        if rotto { print("✗ misura fallita"); exit(1) }
        print("✓ attaccato alla barra, dentro lo schermo, larghezza nei limiti")

        // ── Il clic ──────────────────────────────────────────────────────────
        //
        // **La parte davvero rischiosa del passaggio ad AppKit non è la geometria, è il
        // collegamento**: con `MenuBarExtra` l'apertura la faceva SwiftUI e non c'era niente da
        // sbagliare, adesso è un `target`/`action` scritto a mano, e un'azione non collegata dà
        // un'icona che non fa niente — un difetto che nessuna misura di larghezza vedrebbe.
        //
        // `performClick` percorre la stessa strada del dito, cioè l'azione del bottone, non
        // `open()` chiamata direttamente: chiamare `open()` proverebbe che la finestra sa aprirsi,
        // che non è la domanda.
        panel.statusItem.button?.performClick(nil)
        guard panel.panel?.isVisible == true else {
            print("✗ il clic sull'icona non apre il pannello")
            exit(1)
        }
        let aperto = panel.panel!.frame
        print("✓ il clic apre: \(Int(aperto.width))×\(Int(aperto.height)) a x=\(Int(aperto.minX)) y=\(Int(aperto.minY))")

        panel.statusItem.button?.performClick(nil)
        guard panel.panel?.isVisible == false else {
            print("✗ il secondo clic non richiude il pannello")
            exit(1)
        }
        print("✓ il secondo clic richiude")
        print("— non provato da qui: chiusura con Esc e con un clic fuori, che vogliono eventi veri")
        exit(0)
    }
}

/// Una finestra che **può prendere il fuoco senza attivare l'app**.
///
/// `.nonactivatingPanel` da solo dà una finestra che non diventa mai chiave, e macOS disegna ogni
/// controllo nello stato inattivo: un interruttore acceso esce grigio come uno spento. È lo stesso
/// difetto che `Shot.swift` aveva già dovuto risolvere per le fotografie, con la differenza che qui
/// lo vedrebbe lui e non una sonda.
final class PanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// La carta e gli angoli, cioè tutto ciò che sta **fuori** dal contenuto.
///
/// Sta in una vista sua e non dentro `MenuView` per una ragione precisa: `--scatta` fotografa
/// `MenuView` da sola, e se la forma vivesse là dentro la fotografia mostrerebbe una cosa e il
/// pannello vero un'altra. Adesso la sonda può montare **questa**, e le due non possono divergere.
struct PanelChrome: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var s: SurfacePalette { scheme == .dark ? Surface.sera : Surface.giorno }

    var body: some View {
        MenuView(model: model)
            .background(Color(s.paper))
            .clipShape(RoundedRectangle(cornerRadius: StatusPanel.cornerRadius, style: .continuous))
            // Un filo appena visibile sul bordo: senza, sul tema notturno la carta scura sfuma nel
            // desktop scuro e l'angolo stondato non si legge più.
            .overlay(
                RoundedRectangle(cornerRadius: StatusPanel.cornerRadius, style: .continuous)
                    .strokeBorder(Color(s.rule).opacity(0.6), lineWidth: 0.5)
            )
    }
}
