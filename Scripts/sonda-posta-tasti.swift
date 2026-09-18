// Il mittente del banco del blocco tasti: manda eventi sintetici e stampa l'istante esatto, così
// le righe del registro dell'app testimone si attribuiscono per timbro di tempo e non a occhio.
//
//   swiftc -O Scripts/sonda-posta-tasti.swift -o /tmp/banco/posta
//   /tmp/banco/posta opt        # ⌥ SINISTRO, premuto e rilasciato
//
// **Limite misurato il 2026-09-18, e va saputo prima di credere a un polo verde:** macOS ignora gli
// eventi sintetici della fila alta (`NX_SYSDEFINED`). Un volume-giù sintetico non muove il volume
// nemmeno col tap spento, quindi per luminosità e volume il polo di controllo è morto e la prova
// resta una mano su una tastiera vera.
// destro (0x3D), così la misura non apre una dettatura vera — una lettera, e un tasto volume giù.
import Cocoa

func flags(_ raw: UInt64, code: Int64) {
    guard let e = CGEvent(source: nil) else { return }
    e.type = .flagsChanged
    e.flags = CGEventFlags(rawValue: raw)
    e.setIntegerValueField(.keyboardEventKeycode, value: code)
    e.post(tap: .cghidEventTap)
}

func lettera() {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: true)
    d?.post(tap: .cghidEventTap)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: 0x00, keyDown: false)
    u?.post(tap: .cghidEventTap)
}

// NX_SYSDEFINED, sottotipo 8: la fila alta (volume, luminosità, riproduzione).
func tastoDiSistema(_ key: Int32) {
    for giu in [true, false] {
        let f = giu ? 0xA00 : 0xB00
        let data1 = (Int(key) << 16) | (f << 8)
        guard let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero,
                                          modifierFlags: [], timestamp: 0, windowNumber: 0,
                                          context: nil, subtype: 8, data1: data1, data2: -1),
              let cg = ev.cgEvent else { continue }
        cg.post(tap: .cghidEventTap)
    }
}

let quale = CommandLine.arguments.dropFirst().first ?? "tutto"
print("POSTA: comincio a t=\(String(format: "%.4f", ProcessInfo.processInfo.systemUptime))")
if quale == "tutto" || quale == "opt" {
    flags(0x0008_0020, code: 0x3A)   // ⌥ sinistro premuto (maskAlternate + bit del tasto sinistro)
    usleep(120_000)
    flags(0, code: 0x3A)             // e rilasciato
    usleep(120_000)
}
if quale == "tutto" || quale == "lettera" { lettera(); usleep(120_000) }
if quale == "tutto" || quale == "volume" { tastoDiSistema(1); usleep(120_000) }   // NX_KEYTYPE_SOUND_DOWN
print("POSTA: finito a t=\(String(format: "%.4f", ProcessInfo.processInfo.systemUptime)) (\(quale))")
