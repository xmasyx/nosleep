import Foundation
import IOKit.pwr_mgt
import Darwin

/// Chi **altro** sta impedendo al Mac di dormire.
///
/// **Perché esiste.** Il 7/08 NoSleep ha mollato tutto alle 10:02, correttamente e con due registri
/// a provarlo, e il Mac è rimasto sveglio lo stesso per un'ora con il coperchio chiuso. A tenerlo
/// era il `caffeinate` che Claude Code lancia per conto suo. Dal pannello quel momento si leggeva
/// come «Il Mac può andare in sleep» mentre il Mac non dormiva: vero per la parte di NoSleep, e
/// indistinguibile da un difetto dell'app per chi guarda.
///
/// **NoSleep può solo smettere di impedire il sonno, non può imporlo.** Questa è la conseguenza, e
/// va detta invece che nascosta: se qualcun altro tiene, il pannello lo nomina.
///
/// Passa da `IOPMCopyAssertionsByProcess`, che è API **pubblica**: a differenza del termometro qui
/// non c'è niente che possa sparire con un aggiornamento.
enum OtherHolders {

    struct Holder: Equatable, Identifiable {
        let pid: pid_t
        let process: String
        let reason: String
        var id: pid_t { pid }
    }

    /// Solo i tipi che impediscono al **sistema** di dormire.
    ///
    /// `PreventUserIdleDisplaySleep` resta fuori di proposito: tiene acceso lo schermo e non
    /// impedisce al Mac di addormentarsi, quindi elencarlo qui risponderebbe a una domanda diversa
    /// da quella che si sta facendo chi guarda il pannello.
    private static let bloccanti: Set<String> = [
        kIOPMAssertionTypePreventUserIdleSystemSleep,
        kIOPMAssertionTypePreventSystemSleep,
        kIOPMAssertionTypeNoIdleSleep,
    ]

    static func current() -> [Holder] {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let byPid = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return [] }

        let me = ProcessInfo.processInfo.processIdentifier
        var out: [Holder] = []

        for (numero, asserzioni) in byPid {
            let pid = pid_t(truncating: numero)
            guard pid != me else { continue }
            guard let prima = asserzioni.first(where: {
                bloccanti.contains(($0[kIOPMAssertionTypeKey] as? String) ?? "")
            }) else { continue }
            let nome = (prima[kIOPMAssertionNameKey] as? String) ?? "senza nome"
            // `powerd` è il gestore del risparmio energia, non un colpevole: la sua asserzione
            // «Prevent sleep while display is on» è la **conseguenza** di uno schermo acceso, non
            // la causa per cui il Mac non dorme. Nominarla sarebbe un ragionamento circolare, e chi
            // legge il pannello andrebbe a cercare un processo che non ha fatto niente.
            guard !nome.hasPrefix("Powerd - ") else { continue }
            // E non nominiamo noi stessi. Il confronto sul pid non basta: una sonda è un altro
            // processo NoSleep, e nella fotografia del pannello l'app risultava «tenuta sveglia da
            // NoSleep», che è il genere di riga che fa dubitare di tutto il resto.
            guard !nome.hasPrefix("NoSleep - ") else { continue }
            out.append(Holder(pid: pid, process: processName(pid), reason: nome))
        }
        // Il pid più alto è quasi sempre il più recente, e chi guarda vuole vedere prima quello che
        // è appena comparso.
        return out.sorted { $0.pid > $1.pid }
    }

    /// Il nome del processo dal suo pid. `proc_name` basta e non richiede permessi.
    private static func processName(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return "pid \(pid)" }
        return String(cString: buf)
    }
}
