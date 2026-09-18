// Sonda del blocco tasti — il polo che misura CHE COSA ESCE dal tap.
//
// Domanda a cui risponde: durante la pulizia, un'altra app che tiene un event tap di sessione
// riceve ancora la pressione di un modificatore nudo? Il 2026-09-18 la risposta era sì, e quella
// pressione era il grilletto di una dettatura.
//
// Come si usa — il file del filtro si compila DENTRO la sonda, così il banco misura la regola vera
// e non una sua parafrasi:
//
//   cp Scripts/sonda-blocco-tasti.swift /tmp/banco/main.swift
//   swiftc -O /tmp/banco/main.swift Sources/NoSleepCore/WipeFilter.swift -o /tmp/banco/blocco
//   /tmp/banco/blocco new 6      # oppure `old 6` per la regola di prima
//
// Il mittente è `sonda-posta-tasti.swift`. Il testimone è l'app di sotto: qualunque app con un tap
// di sessione avviato PRIMA di questa sonda (la sonda si inserisce in testa, quindi la precede).
// --rule old  = la regola in produzione fino a oggi (i flagsChanged passano tutti)
// --rule new  = la regola nuova (registro WipeFilter)
// --hid       = tap a livello HID invece che di sessione
import Cocoa

let args = CommandLine.arguments
let regolaNuova = args.contains("new")
let usaHID = args.contains("--hid")
let durata = Double(args.first(where: { Double($0) != nil }) ?? "6") ?? 6

var filtro = WipeFilter(heldAtStart: CGEventSource.flagsState(.combinedSessionState).rawValue)
var porta: CFMachPort?
var armato = true

func callback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let p = porta, armato { CGEvent.tapEnable(tap: p, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
    FileHandle.standardError.write(Data("BLOCCO vede type=\(type.rawValue) code=\(code) flags=\(String(event.flags.rawValue, radix: 16))\n".utf8))

    if type == .keyUp || type == .leftMouseUp || type == .rightMouseUp || type == .otherMouseUp {
        return Unmanaged.passUnretained(event)
    }
    if type == .flagsChanged {
        if !regolaNuova { return Unmanaged.passUnretained(event) }   // regola vecchia
        switch filtro.modifiers(now: event.flags.rawValue) {
        case .swallow: return nil
        case .pass(let flags):
            event.flags = CGEventFlags(rawValue: flags)
            return Unmanaged.passUnretained(event)
        }
    }
    return nil
}

var mask: CGEventMask = [CGEventType.keyDown, .keyUp, .flagsChanged,
                         .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                         .otherMouseDown, .otherMouseUp, .scrollWheel]
    .reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }
mask |= (1 << 14)

guard let p = CGEvent.tapCreate(tap: usaHID ? .cghidEventTap : .cgSessionEventTap,
                                place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: callback, userInfo: nil) else {
    print("BLOCCO: tap non creato"); exit(2)
}
porta = p
let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, p, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
CGEvent.tapEnable(tap: p, enable: true)
print("BLOCCO armato regola=\(regolaNuova ? "new" : "old") tap=\(usaHID ? "hid" : "session") per \(durata)s")
Timer.scheduledTimer(withTimeInterval: durata, repeats: false) { _ in
    armato = false
    CGEvent.tapEnable(tap: p, enable: false)
    print("BLOCCO spento"); exit(0)
}
CFRunLoopRun()
