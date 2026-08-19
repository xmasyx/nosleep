import CoreAudio
import Foundation

/// Sta suonando qualcosa, adesso?
///
/// **Perché la domanda è questa e non «qualcuno tiene acceso lo schermo».** Il sonno imposto a
/// coperchio alzato non deve cadere addosso a chi sta guardando un film, e la prima idea era
/// leggere le asserzioni sul display. Misurato sul suo Mac il 19/08, quell'idea era morta in
/// partenza: **WhatsApp teneva il display da sei ore di fila**, in secondo piano, senza che nessuno
/// guardasse niente. Con quel veto la funzione non sarebbe mai scattata, e una funzione che non
/// scatta mai è peggio di una assente, perché non lo dice a nessuno. Sua obiezione, e riguardava
/// Chrome, che fa lo stesso.
///
/// Il dispositivo audio invece non mente: `kAudioDevicePropertyDeviceIsRunningSomewhere` è vero
/// mentre qualcuno riproduce e torna falso appena smette. Provato in tre tempi lo stesso giorno,
/// con Chrome aperto: silenzio `false`, durante un suono `true`, due secondi dopo la fine `false`.
///
/// **Il buco che resta, e va detto invece che nascosto:** un video **muto** non tocca il
/// dispositivo audio, quindi non ferma niente. Chi guarda un video muto senza toccare il Mac per
/// cinque minuti se lo vede addormentare, e lo risveglia. È il prezzo scelto per non regalare un
/// veto perpetuo a ogni scheda di Chrome lasciata aperta.
enum Audio {

    /// Solo per i banchi, come `PowerAssertion.idleOverride`. In esercizio resta `nil`.
    static var override: Bool?

    /// **Il verso dell'errore è scelto:** se la lettura non riesce si risponde «sta suonando», cioè
    /// non si impone il sonno. Un dispositivo che non risponde non è una stanza in silenzio, ed è
    /// la stessa direzione del lettore di inattività e del termometro.
    static func isPlaying() -> Bool {
        if let f = override { return f }
        var indirizzo = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &indirizzo,
                                         0, nil, &size, &device) == noErr, device != 0 else {
            return true
        }
        indirizzo.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        var acceso = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &indirizzo, 0, nil, &size, &acceso) == noErr else {
            return true
        }
        return acceso != 0
    }
}
