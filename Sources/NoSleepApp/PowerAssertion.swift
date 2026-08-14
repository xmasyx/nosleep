import Foundation
import IOKit.pwr_mgt
import IOKit.ps
import IOKit
import NoSleepCore

/// Le asserzioni di risparmio energia che tengono sveglio il Mac **senza alcun privilegio**.
///
/// Sono tre, e quale sia viva dipende da come il Mac è alimentato adesso.
///
/// - `PreventUserIdleDisplaySleep` tiene acceso il display.
/// - `PreventUserIdleSystemSleep` impedisce il sonno per inattività. Serve perché la prima da sola
///   non basta: lo schermo resta acceso e il sistema si addormenta lo stesso.
/// - `PreventSystemSleep` è **la via ufficiale con l'alimentatore collegato**, ed è più forte delle
///   altre due: non chiede «non addormentarti perché l'utente è inattivo», dice «non addormentarti».
///   Apple la onora **solo a corrente**, e per questo va presa e mollata seguendo la spina invece
///   che una volta sola all'accensione.
final class PowerAssertion {
    private var displayID: IOPMAssertionID = IOPMAssertionID(0)
    private var systemID: IOPMAssertionID = IOPMAssertionID(0)
    private var acID: IOPMAssertionID = IOPMAssertionID(0)

    /// I nomi finiscono dritti in `pmset -g assertions`, ed è così che si verifica dall'esterno che
    /// l'app stia davvero facendo quello che dice (ISC-1). Cambiarli rompe la sonda.
    ///
    /// **Solo ASCII, e non è pignoleria.** Con la lineetta lunga `pmset` stampava un byte di
    /// sostituzione al suo posto, e la sonda documentata (`grep "NoSleep —"`) non trovava niente
    /// mentre l'asserzione c'era eccome: mezz'ora spesa a cercare un difetto nell'app che stava
    /// invece nel filtro. Un nome destinato a un `grep` non contiene caratteri che lo strumento a
    /// valle può ri-codificare (2026-08-07).
    static let displayName = "NoSleep - schermo sveglio" as CFString
    static let systemName = "NoSleep - sistema sveglio" as CFString
    static let acName = "NoSleep - sistema sveglio (a corrente)" as CFString

    private(set) var held = false
    private(set) var onAC = false
    private(set) var mode: AwakeMode = .screenAndActivity

    /// Da quale fonte sta prendendo corrente il Mac, adesso.
    ///
    /// Letta dal sistema a ogni giro e non memorizzata: la spina si attacca e si stacca mentre
    /// l'app gira, ed è proprio quel momento che decide se l'asserzione forte vale qualcosa.
    static func isOnACPower() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return false }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String?
        return type == kIOPMACPowerKey
    }

    /// La carica in percentuale, o `nil` su una macchina senza batteria.
    static func batteryPercent() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for src in list {
            guard let d = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any],
                  let cur = d[kIOPSCurrentCapacityKey] as? Int,
                  let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            return Int((Double(cur) / Double(max) * 100).rounded())
        }
        return nil
    }

    /// Il coperchio è chiuso **adesso**? Letto dal registro di IOKit, non dedotto.
    ///
    /// `AppleClamshellState` è la proprietà che il sistema aggiorna quando il portatile viene
    /// aperto o chiuso. Su un Mac fisso la proprietà non esiste, e l'assenza vale «aperto», che è
    /// la risposta giusta per una macchina senza coperchio.
    /// Solo per i banchi: chiudere davvero il coperchio per provare il codice non è una prova
    /// ripetibile, è un gesto. In esercizio resta `nil` e nessuno la tocca.
    static var clamshellOverride: Bool?

    static func isClamshellClosed() -> Bool {
        if let f = clamshellOverride { return f }
        let root = IOServiceGetMatchingService(kIOMainPortDefault,
                                               IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        let raw = IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString,
                                                  kCFAllocatorDefault, 0)?.takeRetainedValue()
        // Doppia lettura voluta: sondato su questo Mac, la proprietà stampa `0`, e da lì non si
        // distingue un CFBoolean da un CFNumber. Il ramo `true` non è verificabile senza chiudere
        // davvero il coperchio, quindi si accettano entrambe le forme invece di scommettere.
        if let b = raw as? Bool { return b }
        if let n = raw as? NSNumber { return n.boolValue }
        return false
    }

    /// La modalità che conta davvero, che non è sempre quella scelta.
    ///
    /// **A coperchio chiuso il display non si trattiene mai.** Tenere viva un'asserzione sul
    /// display mentre lo schermo è fisicamente ripiegato non serve a niente sul portatile e fa
    /// danno con un monitor esterno attaccato, che resterebbe acceso per nessuno. Quello che
    /// interessa a coperchio chiuso è solo che il lavoro vada avanti (sua richiesta, 2026-08-07).
    ///
    /// Il vincolo è sullo **stato fisico**, non sull'interruttore: accendere «lavora a coperchio
    /// chiuso» mentre il coperchio è ancora alzato non deve spegnere lo schermo sotto il naso.
    static func effectiveMode(_ wanted: AwakeMode) -> AwakeMode {
        isClamshellClosed() ? .activityOnly : wanted
    }

    /// Applica lo stato voluto. Va chiamata a ogni giro, anche quando niente sembra cambiato: è qui
    /// che si insegue il passaggio da batteria a corrente, che avviene mentre l'app gira.
    ///
    /// **L'asserzione forte non è una cosa da spuntare a parte.** Accendendo «tieni sveglio» a
    /// corrente, l'app la prende da sé; staccando la spina la molla. Un secondo interruttore per una
    /// cosa che dipende solo da dove è attaccato il cavo sarebbe una decisione scaricata addosso a
    /// chi legge (sua richiesta, 2026-08-07).
    func set(_ on: Bool, mode requested: AwakeMode = .screenAndActivity) {
        let ac = Self.isOnACPower()
        let wanted = Self.effectiveMode(requested)

        if !on {
            if held { dropAll() }
            held = false
            onAC = false
            return
        }

        // Cambio di modalità a presa aperta: si rifà la base, perché è proprio quale asserzione
        // tenere che cambia.
        if !held || wanted != mode {
            dropAll()
            takeBase(wanted)
            held = true
            mode = wanted
            onAC = ac
            syncAC(ac)
            return
        }

        if ac != onAC {
            syncAC(ac)
            onAC = ac
        }
    }

    // ── Dentro ───────────────────────────────────────────────────────────────

    /// In «solo attività» l'asserzione sul display **non** si prende: il Mac continua a lavorare e
    /// lo schermo è libero di spegnersi, che è il caso in cui il portatile macina e nessuno guarda.
    private func takeBase(_ m: AwakeMode) {
        if m == .screenAndActivity {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        Self.displayName, &displayID)
        }
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    Self.systemName, &systemID)
    }

    /// L'asserzione forte si prende **solo** a corrente, e si molla appena la spina esce.
    ///
    /// Tenerla viva a batteria non sarebbe pericoloso, sarebbe peggio: il sistema la ignora, e nel
    /// registro resterebbe scritta una protezione che non protegge niente.
    private func syncAC(_ ac: Bool) {
        if ac, acID == 0 {
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventSystemSleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        Self.acName, &acID)
        } else if !ac, acID != 0 {
            IOPMAssertionRelease(acID)
            acID = IOPMAssertionID(0)
        }
    }

    private func dropAll() {
        if displayID != 0 { IOPMAssertionRelease(displayID); displayID = IOPMAssertionID(0) }
        if systemID != 0 { IOPMAssertionRelease(systemID); systemID = IOPMAssertionID(0) }
        if acID != 0 { IOPMAssertionRelease(acID); acID = IOPMAssertionID(0) }
    }

    /// Il rilascio all'uscita, che copre la chiusura pulita e **non** copre `kill -9`.
    ///
    /// Per le asserzioni non serve altro: muore il processo, il kernel le raccoglie. È il coperchio
    /// che ha bisogno di un cane da guardia, perché quello è uno stato scritto su disco.
    deinit { dropAll() }
}
