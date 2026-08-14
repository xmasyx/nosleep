import Foundation

/// Le pose intermedie: fra una posa e l'altra i pallini **si spostano** invece di saltare.
///
/// **Perché serve, dopo aver già riparato il taglio delle pose.** La registrazione ha quindici pose
/// al giro, cioè dodici e mezzo al secondo, e sono poche: il cinema ne usa ventiquattro e l'occhio
/// la differenza la sente. Rimesse le pose giuste il movimento è diventato corretto ma è rimasto a
/// scatti, perché a quella cadenza fra un fotogramma e l'altro una zampa si sposta di mezzo corpo e
/// nessuno vede il tragitto.
///
/// **Come si riempie il vuoto senza inventare un cavallo che non c'è.** Non si disegna una posa
/// nuova: si prendono i pallini della posa che finisce e quelli della posa che comincia, si
/// **appaiano** quelli vicini, e nei fotogrammi intermedi ogni pallino sta a metà strada fra il suo
/// posto di prima e quello di dopo. Chi non trova un compagno non salta via, si spegne o si accende
/// gradualmente. Il risultato è che il cavallo continua a essere fatto dei pallini della
/// registrazione, e nessun fotogramma è un disegno inventato: è la stessa mezzatinta in transito.
///
/// **Il tetto sulla distanza è la parte che tiene il disegno insieme.** Senza, un pallino della coda
/// si appaia con uno della testa e attraversa il cavallo in volo, che è vistoso e sbagliato. Con il
/// tetto a tre celle, un pallino senza compagno vicino preferisce spegnersi, e spegnersi in un posto
/// non si nota: comparire dall'altra parte dello schermo sì.
public enum HorseMotion {

    public struct Dot: Equatable, Sendable {
        public let x: Double, y: Double, r: Double
    }

    /// Quanto lontano può stare il compagno di un pallino, in celle di griglia.
    ///
    /// Tre è misurato, non scelto a occhio: fra due pose consecutive di questo galoppo il 95% degli
    /// appaiamenti sta sotto le tre celle, e sopra quella soglia non è più lo stesso pallino che si
    /// muove, è un altro pallino che gli somiglia.
    public static let maxTravel = 3.0

    /// I pallini a un istante qualunque fra la posa `a` e la posa successiva, con `t` da 0 a 1.
    ///
    /// A `t = 0` restituisce esattamente la posa `a`: l'interpolazione non tocca i fotogrammi veri,
    /// li collega, e il banco lo verifica.
    public static func dots(from a: Int, t: Double) -> [Dot] {
        let n = Horse.poses.count
        let ia = ((a % n) + n) % n
        let ib = (ia + 1) % n
        let da = Horse.dots(pose: ia), db = Horse.dots(pose: ib)

        if t <= 0 { return da.map { Dot(x: Double($0.x), y: Double($0.y), r: $0.r) } }
        if t >= 1 { return db.map { Dot(x: Double($0.x), y: Double($0.y), r: $0.r) } }

        // L'appaiamento è avido sulla distanza: si prendono prima le coppie più vicine, che sono
        // quelle di cui siamo più sicuri, e ogni pallino entra in una coppia sola. Un algoritmo
        // ottimo (l'assegnamento ungherese) qui non cambierebbe il disegno e costerebbe dieci volte
        // tanto su un problema da centoquaranta pallini per parte.
        struct Coppia { let i: Int, j: Int, d: Double }
        var coppie: [Coppia] = []
        coppie.reserveCapacity(da.count * 4)
        for (i, p) in da.enumerated() {
            for (j, q) in db.enumerated() {
                let dx = Double(p.x - q.x), dy = Double(p.y - q.y)
                let d = (dx * dx + dy * dy).squareRoot()
                if d <= maxTravel { coppie.append(Coppia(i: i, j: j, d: d)) }
            }
        }
        coppie.sort { $0.d < $1.d }

        var presoA = [Bool](repeating: false, count: da.count)
        var presoB = [Bool](repeating: false, count: db.count)
        var out: [Dot] = []
        out.reserveCapacity(max(da.count, db.count))

        for c in coppie where !presoA[c.i] && !presoB[c.j] {
            presoA[c.i] = true
            presoB[c.j] = true
            let p = da[c.i], q = db[c.j]
            out.append(Dot(x: Double(p.x) + (Double(q.x) - Double(p.x)) * t,
                           y: Double(p.y) + (Double(q.y) - Double(p.y)) * t,
                           r: p.r + (q.r - p.r) * t))
        }
        // Chi resta solo si spegne o si accende, e non si sposta: muoversi verso il nulla sarebbe
        // un tragitto inventato.
        for (i, p) in da.enumerated() where !presoA[i] {
            out.append(Dot(x: Double(p.x), y: Double(p.y), r: p.r * (1 - t)))
        }
        for (j, q) in db.enumerated() where !presoB[j] {
            out.append(Dot(x: Double(q.x), y: Double(q.y), r: q.r * t))
        }
        return out
    }
}
