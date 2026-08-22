import AppKit
import SwiftUI
import Carbon.HIToolbox
import IOKit.pwr_mgt
import NoSleepCore

// ─────────────────────────────────────────────────────────────────────────────
// La schermata di pulizia della tastiera: i tasti smettono di rispondere, lo schermo diventa nero,
// e ci si passa lo straccio sopra senza scrivere niente da nessuna parte. Il nero non è decorazione:
// è quello che rende visibile lo sporco mentre lo togli, e serve alla tastiera retroilluminata come
// allo schermo.
//
// **La cosa che questo file deve garantire prima di ogni altra è di sapersi spegnere.** Tutto il
// resto — il nero, la frase, il conto alla rovescia — è contorno; il blocco della tastiera è una
// cosa che, se resta accesa, lascia il principale davanti a un Mac inservibile. Da qui le tre vie
// d'uscita indipendenti, che non condividono nessun pezzo di codice:
//
//   1. il tempo scade e il giro da un secondo chiude (la strada normale);
//   2. il cane da guardia chiude comunque tre secondi dopo la scadenza, anche se il giro fosse
//      morto — è un secondo timer che non sa niente del primo;
//   3. il processo muore, e il tap muore con lui perché appartiene al processo: `kill -9` è
//      sempre l'ultima parola, e non dipende da niente che abbiamo scritto noi.
//
// Più due porte che restano aperte apposta: la combinazione d'uscita e il ⌘⌥Esc di sistema.
// ─────────────────────────────────────────────────────────────────────────────

/// Perché la pulizia è finita. Va nel registro: senza, un blocco che si chiude da solo e uno
/// chiuso dal cane da guardia si leggono uguali, e sono due fatti molto diversi.
enum WipeEnd {
    case manual
    case expired
    case watchdog
}

/// Il tap vive fuori dall'oggetto perché la funzione di richiamata di CoreGraphics è una funzione
/// C: non può catturare niente. Sono due variabili, toccate solo dal thread principale.
private var wipeTapPort: CFMachPort?
private var wipeTapArmed = false

/// La richiamata del tap. Gira sul thread principale, perché è lì che la sorgente è agganciata.
///
/// **Ingoia tutto per costruzione, e lascia passare per eccezione.** Il verso conta: scritta al
/// contrario — passa tutto tranne un elenco di tasti — ogni tasto dimenticato sarebbe un buco, e i
/// tasti dimenticati sono esattamente quelli che non conosco.
private func wipeTapCallback(proxy: CGEventTapProxy,
                             type: CGEventType,
                             event: CGEvent,
                             refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Il sistema disattiva un tap troppo lento o dopo certe interazioni. Se non lo riaccendessimo,
    // il blocco cadrebbe **senza dirlo a nessuno**, che è il guasto peggiore: la schermata resta
    // nera e i tasti ricominciano a scrivere dentro le app di sotto.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let port = wipeTapPort, wipeTapArmed { CGEvent.tapEnable(tap: port, enable: true) }
        return Unmanaged.passUnretained(event)
    }

    guard wipeTapArmed else { return Unmanaged.passUnretained(event) }

    let flags = event.flags
    let control = flags.contains(.maskControl)
    let option = flags.contains(.maskAlternate)
    let command = flags.contains(.maskCommand)
    let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))

    if type == .keyDown {
        if WipeExit.matches(keyCode: code, control: control, option: option, command: command) {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { WipeScreen.shared.stop(.manual) }
            }
            return nil
        }
        // La via di fuga del sistema passa apposta: vedi `WipeExit.isForceQuit`.
        if WipeExit.isForceQuit(keyCode: code, control: control, option: option, command: command) {
            return Unmanaged.passUnretained(event)
        }
    }

    return nil
}

/// Una finestra senza bordi non diventa mai la finestra di tastiera, e senza quello i tasti
/// finirebbero all'app di sotto anche con lo schermo nero davanti.
private final class WipeWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// La vista che si mangia tastiera e mouse **anche senza il permesso di Accessibilità**.
///
/// È il pavimento della funzione: il tap è il piano di sopra e blocca i tasti di sistema, ma
/// richiede un permesso che l'utente può non dare. Qui sotto, senza chiedere niente a nessuno, i
/// tasti normali e i click non arrivano da nessuna parte perché questa vista li tiene e non li
/// passa. `NSResponder` di serie li rimanderebbe su per la catena facendo suonare il Mac.
private final class WipeSwallowView: NSView {
    override var acceptsFirstResponder: Bool { true }

    /// **Anche qui si guarda la combinazione, e non è una ripetizione inutile.** Senza il permesso
    /// di Accessibilità il tap non esiste, e allora l'unica cosa che vede i tasti è questa vista.
    /// Provato dal vivo il 2026-08-22: mandando la combinazione con il tap spento, la pulizia
    /// **non** usciva, perché `performKeyEquivalent` da solo non riceve un Esc con modificatori.
    private func esceSeCombinazione(_ event: NSEvent) -> Bool {
        let f = event.modifierFlags
        guard WipeExit.matches(keyCode: UInt16(event.keyCode),
                               control: f.contains(.control),
                               option: f.contains(.option),
                               command: f.contains(.command)) else { return false }
        WipeScreen.shared.stop(.manual)
        return true
    }

    override func keyDown(with event: NSEvent) { _ = esceSeCombinazione(event) }
    override func keyUp(with event: NSEvent) {}
    /// Esc arriva qui e non da `keyDown` quando la finestra lo tratta come «annulla».
    override func cancelOperation(_ sender: Any?) {
        if let e = NSApp.currentEvent { _ = esceSeCombinazione(e) }
    }
    override func flagsChanged(with event: NSEvent) {}
    override func mouseDown(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Vero vuol dire «l'ho gestito io»: è così che ⌘Q e ⌘W non chiudono niente mentre pulisci.
        // L'unica eccezione è la combinazione d'uscita, che qui serve nel caso in cui il tap non
        // ci sia — senza permesso di Accessibilità questa vista è l'unica cosa che ascolta.
        _ = esceSeCombinazione(event)
        return true
    }
}

@MainActor
final class WipeScreen: ObservableObject {
    static let shared = WipeScreen()

    /// Quanto manca, in secondi. È `@Published` perché il piede della schermata lo conta alla
    /// rovescia sotto gli occhi di chi pulisce: senza numero visibile, un minuto al buio sembra
    /// molto più lungo di un minuto.
    @Published private(set) var remaining: Double = 0
    @Published private(set) var isActive = false

    /// La frase di questa pulizia, scelta all'avvio e ferma fino alla fine.
    private(set) var quote: Quote = Quotes.all[0]

    private var windows: [NSWindow] = []
    private var source: CFRunLoopSource?
    private var assertionID = IOPMAssertionID(0)
    private var savedPresentation: NSApplication.PresentationOptions = []
    private var ticker: Timer?
    private var watchdog: Timer?
    private var deadline = Date.distantPast

    /// Dove finisce una riga di registro. Iniettabile perché i banchi girano in una casa loro e
    /// non devono scrivere nel registro vero.
    var record: (String) -> Void = { event in
        Log.append(LogEntry(at: Date().timeIntervalSince1970,
                            who: "app",
                            event: event,
                            screenAwake: false,
                            lidAwake: false,
                            leases: 0,
                            thermal: "normale"),
                   to: Paths.log())
    }

    /// Il permesso di Accessibilità c'è? Iniettabile per provare il ramo «non c'è» su una macchina
    /// dove c'è.
    var isTrusted: () -> Bool = { AXIsProcessTrusted() }

    /// Un'altra app tiene l'input protetto (un campo password aperto)? In quel caso i tasti non
    /// passano nemmeno da noi, e prometterlo sarebbe falso.
    var secureInputHeld: () -> Bool = { IsSecureEventInputEnabled() }

    private init() {}

    // ── Accendere ────────────────────────────────────────────────────────────

    /// Avvia la pulizia. `seconds` è separato da `WipeDuration` solo perché i banchi la comprimono
    /// a un secondo: nessuna interfaccia passa di qui con un numero che non venga dalle tre durate.
    func start(seconds: Double) {
        guard !isActive else { return }
        isActive = true
        quote = Quotes.random()
        deadline = Date().addingTimeInterval(seconds)
        remaining = seconds

        record(S.logWipeStart(max(1, Int((seconds / 60).rounded()))))

        holdDisplayAwake()
        buildWindows()
        takeOverPresentation()
        installTap()
        armTimers(seconds: seconds)
    }

    /// Lo schermo deve restare acceso: se si spegnesse a metà pulizia spariscono il conto alla
    /// rovescia e la riga che dice come si esce, cioè le due cose che servono a chi ha le mani
    /// sulla tastiera e non sa più che sta succedendo. È un'asserzione tutta sua, separata da quelle
    /// del resto dell'app, così si prende e si molla senza toccare lo stato che l'utente ha scelto.
    private func holdDisplayAwake() {
        var id = IOPMAssertionID(0)
        let ok = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                             IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                             "NoSleep - pulizia tastiera" as CFString,
                                             &id)
        assertionID = (ok == kIOReturnSuccess) ? id : IOPMAssertionID(0)
    }

    private func buildWindows() {
        let main = NSScreen.main
        for screen in NSScreen.screens {
            let w = WipeWindow(contentRect: screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
            w.setFrame(screen.frame, display: true)
            w.isOpaque = true
            w.backgroundColor = .black
            w.hasShadow = false
            // Sopra il salvaschermo: sotto quel livello resterebbero davanti la barra dei menu e
            // le finestre a tutto schermo altrui, e lo schermo non sarebbe nero per davvero.
            w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            w.ignoresMouseEvents = false
            w.isReleasedWhenClosed = false

            let swallow = WipeSwallowView(frame: screen.frame)
            swallow.autoresizingMask = [.width, .height]
            // La frase sta sullo schermo principale. Sugli altri il nero e basta: la stessa frase
            // ripetuta su tre schermi sembra un difetto di disegno, non una scelta.
            if screen == main {
                let host = NSHostingView(rootView: WipeView(screen: self))
                host.frame = screen.frame
                host.autoresizingMask = [.width, .height]
                swallow.addSubview(host)
            }
            w.contentView = swallow
            w.makeKeyAndOrderFront(nil)
            w.makeFirstResponder(swallow)
            windows.append(w)
        }
    }

    /// Toglie all'utente le vie di uscita del sistema che non passano dalla tastiera: cambio di
    /// applicazione, Dock, barra dei menu. Il tap copre i tasti; questo copre il resto.
    private func takeOverPresentation() {
        NSApp.activate(ignoringOtherApps: true)
        savedPresentation = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar,
                                     .disableProcessSwitching, .disableHideApplication]
    }

    private func installTap() {
        if secureInputHeld() { record(S.logWipeSecureInput) }
        guard isTrusted() else {
            record(S.logWipeNoAX)
            return
        }

        // Tastiera **e** puntatore: i click non devono raggiungere quello che sta sotto, e con lo
        // straccio addosso al trackpad ne parte più di uno.
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.rightMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            // 14 è `NX_SYSDEFINED`, la famiglia dei tasti fisici della fila alta: luminosità,
            // volume, riproduzione, Dettatura. Non ha una costante in `CGEventType`, e senza
            // questa riga sono proprio i tasti che lui ha chiesto di bloccare a passare.
            (1 << 14)

        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: wipeTapCallback,
                                           userInfo: nil) else {
            record(S.logWipeNoAX)
            return
        }
        wipeTapPort = port
        wipeTapArmed = true
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
    }

    private func armTimers(seconds: Double) {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Il cane da guardia non guarda il giro, guarda l'orologio: è indipendente apposta, e la
        // sua ragione d'essere è il caso in cui il primo timer non scatti affatto.
        watchdog = Timer.scheduledTimer(withTimeInterval: seconds + 3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                self.stop(.watchdog)
            }
        }
        // Senza questo i due timer non scattano mentre una finestra modale o un menu tiene il giro
        // principale in un'altra modalità, e la pulizia non finirebbe.
        if let t = ticker { RunLoop.main.add(t, forMode: .common) }
        if let w = watchdog { RunLoop.main.add(w, forMode: .common) }
    }

    private func tick() {
        remaining = max(0, deadline.timeIntervalSinceNow)
        if remaining <= 0 { stop(.expired) }
    }

    // ── Spegnere ─────────────────────────────────────────────────────────────

    /// Molla tutto, nell'ordine inverso a come è stato preso. Si può chiamare più volte: la seconda
    /// non fa niente.
    func stop(_ why: WipeEnd) {
        guard isActive else { return }
        isActive = false

        wipeTapArmed = false
        if let port = wipeTapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
            CFMachPortInvalidate(port)
        }
        wipeTapPort = nil
        source = nil

        ticker?.invalidate(); ticker = nil
        watchdog?.invalidate(); watchdog = nil

        NSApp.presentationOptions = savedPresentation
        savedPresentation = []

        for w in windows { w.orderOut(nil); w.close() }
        windows.removeAll()

        if assertionID != IOPMAssertionID(0) {
            IOPMAssertionRelease(assertionID)
            assertionID = IOPMAssertionID(0)
        }

        remaining = 0
        switch why {
        case .manual: record(S.logWipeManual)
        case .expired: record(S.logWipeExpired)
        case .watchdog: record(S.logWipeWatchdog)
        }
    }

    // ── Quello che il banco apre ─────────────────────────────────────────────

    /// Spegne il giro da mezzo secondo **senza** toccare il cane da guardia: è l'unico modo di
    /// provare che la seconda via d'uscita esiste davvero. Nessuno la chiama in esercizio.
    func disarmTickerForBench() {
        ticker?.invalidate()
        ticker = nil
    }

    var benchWindowCount: Int { windows.count }
    var benchTapInstalled: Bool { wipeTapPort != nil }
    var benchAssertionHeld: Bool { assertionID != IOPMAssertionID(0) }
    var benchPresentation: NSApplication.PresentationOptions { NSApp.presentationOptions }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Il nero, la frase, il piede. Niente altro: ogni elemento in più su uno schermo che serve a
/// vedere le ditate è una cosa che nasconde le ditate.
private struct WipeView: View {
    @ObservedObject var screen: WipeScreen

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 22) {
                Text(screen.quote.text)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .foregroundStyle(Color(white: 0.92))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)

                Text(screen.quote.attribution)
                    .font(.system(size: 12.5, weight: .regular, design: .serif))
                    .foregroundStyle(Color(white: 0.45))

                footer.padding(.top, 18)
            }
            .padding(.horizontal, 80)
        }
        .ignoresSafeArea()
    }

    /// Tre cose, sempre: che cosa sta succedendo, quanto manca, come si esce. La terza è in
    /// grassetto perché è l'unica che qualcuno cercherà con gli occhi, e la cercherà di fretta.
    private var footer: some View {
        HStack(spacing: 7) {
            Text(S.wipeStatus)
                .foregroundStyle(Color(white: 0.42))
            Text(WipeClock.countdown(remaining: screen.remaining))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.72))
            Text(S.wipeRemaining)
                .foregroundStyle(Color(white: 0.42))
            Text("·")
                .foregroundStyle(Color(white: 0.30))
            Text(S.wipeExitWord)
                .foregroundStyle(Color(white: 0.42))
            Text(WipeExit.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(white: 0.86))
        }
        .font(.system(size: 12))
    }
}
