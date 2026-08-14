import AppKit
import NoSleepCore

/// Il cavallo di `Horse` disegnato come immagine, per la barra dei menu e per l'intestazione.
///
/// **Un disegnatore solo, usato da tutti e tre.** La barra dei menu, il pannello e la sonda
/// `--cavallo` passano di qui: se il disegno esistesse in due posti, la fotografia proverebbe la
/// copia invece dell'originale, che è il modo classico di avere un banco verde e un difetto in
/// esercizio.
///
/// **Perché un'immagine e non una `Canvas` di SwiftUI.** L'etichetta di `MenuBarExtra` diventa
/// comunque un'immagine, e costruirla noi ci lascia due cose che servono: la marchiamo `isTemplate`,
/// così macOS la tinge da sé di nero sulla barra chiara e di bianco su quella scura senza che
/// dobbiamo indovinare il tema; e la disegniamo dentro un blocco che macOS richiama **a ogni fattore
/// di scala**, quindi resta nitida su Retina invece di essere una miniatura ingrandita.
///
/// **Le quindici immagini si costruiscono una volta sola.** A dodici pose al secondo, ricostruirle
/// a ogni fotogramma sarebbe centocinquanta cerchi dodici volte e mezzo al secondo per sempre; costruite una
/// volta, l'animazione è un indice che cambia.
@MainActor
enum HorseImage {

    private static var cache: [Double: [NSImage]] = [:]

    /// Quanti fotogrammi si disegnano per ogni posa vera.
    ///
    /// **Uno vuol dire dodici fotogrammi e mezzo al secondo, ed è lì che il movimento si vedeva a
    /// scatti** (sua osservazione, due volte). Con tre, i fotogrammi diventano quarantacinque per
    /// giro, cioè **37,5 al secondo**, sopra i ventiquattro del cinema. I due in mezzo non sono pose
    /// nuove e non sono inventati: sono gli stessi pallini in viaggio da una posa all'altra, vedi
    /// `HorseMotion`.
    ///
    /// Si pagano in disegno, non in memoria: quarantacinque immagini da venti punti per quindici
    /// pesano meno di un'icona, e si costruiscono una volta sola.
    static let substeps = 3

    /// Tutti i fotogrammi del giro a una certa altezza in punti. La larghezza esce dalla forma della
    /// griglia e non si sceglie: il cavallo non si deforma.
    static func frames(height: Double) -> [NSImage] {
        if let pronte = cache[height] { return pronte }
        var fatte: [NSImage] = []
        fatte.reserveCapacity(Horse.poses.count * substeps)
        for posa in 0..<Horse.poses.count {
            for s in 0..<substeps {
                fatte.append(disegna(dots: HorseMotion.dots(from: posa, t: Double(s) / Double(substeps)),
                                     height: height))
            }
        }
        cache[height] = fatte
        return fatte
    }

    /// Quanti fotogrammi al secondo scorrono davvero.
    static var frameRate: Double { Horse.fps * Double(substeps) }

    static func image(pose: Int, height: Double) -> NSImage {
        let f = frames(height: height)
        return f[((pose % f.count) + f.count) % f.count]
    }

    /// La larghezza che il cavallo occupa a una data altezza.
    static func width(height: Double) -> Double {
        height * Double(Horse.columns) / Double(Horse.rows)
    }

    /// Quanto grosso è un pallino, in frazione della cella, **alla misura a cui lo stai guardando**.
    ///
    /// **Perché non è una costante, che è la cosa che ho dovuto imparare guardando la prima
    /// fotografia.** A quindici punti di altezza una cella vale sette decimi di pixel: lì i pallini
    /// non si distinguono più uno dall'altro, e disegnarli alla misura vera della mezzatinta lascia
    /// sulla barra un cavallo pallido, molto più leggero del fulmine e delle zeta che gli stanno
    /// accanto. Sotto i due pixel per cella il disegno smette quindi di essere una mezzatinta e
    /// diventa una **sagoma**: i pallini pieni si allargano fino a toccarsi e il corpo si chiude.
    ///
    /// È lo stesso cavallo guardato da lontano, non un secondo disegno: sopra i due pixel per cella
    /// la mezzatinta torna esatta, e il passaggio fra le due è continuo, così non esiste una misura
    /// in cui il cavallo cambia di colpo.
    static func radiusFactor(cell cella: Double) -> Double {
        let mezzatinta = Horse.maxRadius   // 0,45: i pallini pieni quasi si toccano
        let sagoma = 0.75                  // si sovrappongono: il corpo diventa pieno
        let t = min(1, max(0, (2.0 - cella) / 1.5))
        return mezzatinta + (sagoma - mezzatinta) * t
    }

    private static func disegna(dots: [HorseMotion.Dot], height: Double) -> NSImage {
        let cella = height / Double(Horse.rows)
        let size = NSSize(width: width(height: height), height: height)

        // `flipped: true` mette l'origine in alto a sinistra, cioè dove sta l'origine della griglia:
        // senza, il cavallo galoppa a testa in giù e non è una battuta, è successo.
        let fattore = radiusFactor(cell: cella)
        let img = NSImage(size: size, flipped: true) { _ in
            for d in dots {
                let r = d.r * fattore * cella
                // **Specchiato: il cavallo corre verso sinistra** (sua richiesta, 2026-08-11). Il
                // verso è una scelta di presentazione, non un fatto delle pose, quindi si ribalta
                // qui e non nei dati: le pose restano quelle della registrazione da cui vengono, e
                // il giorno che il verso cambia idea si tocca questa riga sola.
                let cx = (Double(Horse.columns - 1) - d.x + 0.5) * cella
                let cy = (d.y + 0.5) * cella
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
            }
            return true
        }
        // Marcata come sagoma: il colore lo decide chi la mostra, la barra dei menu da sé e il
        // pannello con l'accento della livrea.
        img.isTemplate = true
        return img
    }
}
