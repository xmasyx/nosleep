import Foundation
import IOKit

/// Il termometro: legge i sensori termici del Mac **senza alcun privilegio**.
///
/// **Perché esiste.** `ProcessInfo.thermalState` risponde a «il sistema sta rallentando per il
/// caldo?», e la notte del 7/08 ha risposto no per sei ore mentre il Mac, ripreso in mano, era
/// caldo davvero. Non è un difetto di quell'API: è il suo perimetro. Un Mac sveglio e quasi fermo,
/// chiuso e senza aria, scalda senza mai mettere in difficoltà il chip. Serviva un numero.
///
/// **Due strade, e non a caso.** La batteria, che è il numero su cui poggia la soglia, arriva da
/// `AppleSmartBattery` in IORegistry, che è **API pubblica**. Die e scocca non hanno alternative e
/// passano dai sensori HID.
///
/// **Il costo della seconda, dichiarato.** Passa da simboli **privati** di IOKit, quindi può smettere di
/// funzionare con un aggiornamento di macOS, senza preavviso. Per questo qui non c'è nessuna
/// `!`: se un simbolo manca, se il client non nasce o se nessun sensore risponde, la lettura è
/// `nil` e l'app torna a comportarsi esattamente come prima. **La sicurezza non ci si appoggia
/// mai**: `thermalState` resta la guardia principale, questo è un secondo paio d'occhi.
enum Thermometer {

    struct Reading {
        /// Il die del SoC, il più caldo dei suoi sensori. È il chip, non la scocca.
        let die: Double?
        /// I sensori di scheda e dispositivo, il più caldo. È il proxy migliore che esista per
        /// quello che sente la scocca, e quindi lo schermo appoggiato sopra a coperchio chiuso:
        /// **non esiste alcun sensore sul pannello**, verificato elencandoli tutti e 46.
        let board: Double?
        /// La batteria. È il pezzo che invecchia davvero col caldo, ed è il più lento a scaldarsi,
        /// quindi quando sale vuol dire che il calore è lì da un po'.
        let battery: Double?

        var isEmpty: Bool { die == nil && board == nil && battery == nil }
    }

    // ── I simboli privati, risolti una volta e mai forzati ───────────────────

    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias MatchFn = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias ServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias PropFn = @convention(c) (AnyObject, CFString) -> Unmanaged<CFTypeRef>?
    private typealias EventFn = @convention(c) (AnyObject, Int64, Int32, Int32) -> Unmanaged<AnyObject>?
    private typealias FloatFn = @convention(c) (AnyObject, Int32) -> Double

    private struct Api {
        let create: CreateFn, match: MatchFn, services: ServicesFn
        let prop: PropFn, event: EventFn, float: FloatFn
    }

    private static let api: Api? = {
        guard let h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return nil }
        func sym<T>(_ n: String) -> T? {
            guard let p = dlsym(h, n) else { return nil }
            return unsafeBitCast(p, to: T.self)
        }
        guard let c: CreateFn = sym("IOHIDEventSystemClientCreate"),
              let m: MatchFn = sym("IOHIDEventSystemClientSetMatching"),
              let s: ServicesFn = sym("IOHIDEventSystemClientCopyServices"),
              let p: PropFn = sym("IOHIDServiceClientCopyProperty"),
              let e: EventFn = sym("IOHIDServiceClientCopyEvent"),
              let f: FloatFn = sym("IOHIDEventGetFloatValue") else { return nil }
        return Api(create: c, match: m, services: s, prop: p, event: e, float: f)
    }()

    /// `0xff00` è la pagina d'uso del fornitore Apple, `5` sono i sensori di temperatura,
    /// `15` è il tipo di evento «temperatura». Sono i numeri del protocollo HID, non nostri.
    private static let vendorPage = 0xff00, temperatureUsage = 5, temperatureEvent: Int64 = 15

    /// Il client vive quanto il processo: ricrearlo a ogni giro costa e non serve.
    private static let client: AnyObject? = {
        guard let api else { return nil }
        guard let c = api.create(kCFAllocatorDefault)?.takeRetainedValue() else { return nil }
        api.match(c, ["PrimaryUsagePage": vendorPage, "PrimaryUsage": temperatureUsage] as CFDictionary)
        return c
    }()

    /// La temperatura della batteria, dal posto giusto: `AppleSmartBattery.Temperature` in
    /// IORegistry, in **decimi di grado**.
    ///
    /// **Perché non dai sensori HID.** Là dentro ci sono sei voci «gas gauge battery» che leggono
    /// 35-36 gradi, e prendendone il massimo l'app diceva 36 mentre Mole diceva 31. Aveva ragione
    /// Mole: il valore ufficiale è 30,9, e quei sensori sono la `VirtualTemperature` del chip
    /// contatore (3579, cioè 35,8), non la temperatura della cella. Se n'è accorto lui confrontando
    /// due app (2026-08-07).
    ///
    /// In più questa è API **pubblica**: il numero su cui si appoggia la soglia non dipende più da
    /// simboli privati, e la strada privata resta solo per die e scocca, che non hanno alternative.
    static func batteryFromRegistry() -> Double? {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault,
                                              IOServiceMatching("AppleSmartBattery"))
        guard svc != 0 else { return nil }
        defer { IOObjectRelease(svc) }
        guard let raw = IORegistryEntryCreateCFProperty(svc, "Temperature" as CFString,
                                                        kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? NSNumber else { return nil }
        let c = raw.doubleValue / 100
        // Una cella fra -20 e 80 gradi è plausibile; fuori di lì la chiave ha cambiato unità e un
        // numero assurdo dentro una soglia spegnerebbe tutto per niente.
        return (c > -20 && c < 80) ? c : nil
    }

    /// Una lettura, o `nil` per ogni campo che non si è potuto leggere. Non lancia, non blocca.
    static func read() -> Reading {
        // La batteria arriva dalla strada pubblica e non dipende dai sensori HID: se un domani
        // quelli chiudono, il numero che regge la soglia resta.
        let battery = batteryFromRegistry()

        guard let api, let client,
              let raw = api.services(client)?.takeRetainedValue() as? [AnyObject] else {
            return Reading(die: nil, board: nil, battery: battery)
        }
        var die: Double?, board: Double?
        for service in raw {
            let name = (api.prop(service, "Product" as CFString)?.takeRetainedValue() as? String) ?? ""
            guard let ev = api.event(service, temperatureEvent, 0, 0)?.takeRetainedValue() else { continue }
            let v = api.float(ev, Int32(temperatureEvent << 16))
            // Zero vuol dire «non risponde», e sopra i 130 gradi non è una lettura, è spazzatura:
            // un valore assurdo che entrasse in una soglia spegnerebbe tutto per niente.
            guard v > 0, v < 130 else { continue }

            // I sensori «gas gauge battery» si saltano: sono la temperatura virtuale del chip
            // contatore, non della cella, e leggono cinque gradi più alti del vero.
            if name.lowercased().contains("batt") {
                continue
            } else if name.contains("tdie") || name.contains("tcal") {
                die = max(die ?? v, v)
            } else {
                board = max(board ?? v, v)
            }
        }
        return Reading(die: die, board: board, battery: battery)
    }
}
