import Foundation

/// Che cosa vuol dire «tieni sveglio».
///
/// Due modi, non tre. «Solo schermo» esiste in altre app e lui l'ha escluso: tenere acceso il
/// display mentre il sistema si addormenta non serve a nessuno che stia lavorando.
public enum AwakeMode: String, Codable, Equatable, Sendable, CaseIterable {
    /// Il display resta acceso e il lavoro va avanti.
    case screenAndActivity
    /// Il lavoro va avanti e il display è libero di spegnersi. È il modo che consuma meno, ed è
    /// quello giusto quando il Mac sta macinando e nessuno lo guarda.
    case activityOnly
}

/// Gli interruttori, e nient'altro.
///
/// **Quello che NON c'è qui è la parte importante.** Il ritorno al sonno quando l'app muore e il
/// rilascio quando il Mac scotta non sono chiavi di configurazione: sono le due reti di sicurezza,
/// e un interruttore che le spegne trasformerebbe il caso peggiore in «il Mac non dorme più e non
/// te lo dice». Se un giorno qualcuno aggiunge una chiave che le disattiva, il test `ISC-23` la
/// trova.
public struct Config: Codable, Equatable, Sendable {
    /// Tiene sveglio il Mac. Nessun privilegio, funziona a batteria.
    public var screenAwake: Bool
    /// Con che cosa: schermo e attività, oppure la sola attività.
    public var awakeMode: AwakeMode
    /// Impedisce il sonno a coperchio chiuso. Richiede l'helper installato.
    public var lidAwake: Bool
    /// Quando l'ultima prenotazione cade, molla tutto. **Nasce acceso** (sua decisione, 2026-08-07).
    public var releaseWhenWorkEnds: Bool
    /// Quando arriva la prima prenotazione, accende da sé lo schermo sveglio. **Nasce spento.**
    ///
    /// Accende *solo* lo schermo, mai il coperchio da sé: il coperchio ha un costo fisico (calore in
    /// uno zaino chiuso). Chi vuole anche quello lo dice una volta con `lidFollowsAwake`, che è
    /// l'interruttore sotto.
    public var autoArmOnWork: Bool
    /// Se il Mac è tenuto sveglio, il coperchio è già pronto: abbassandolo il lavoro va avanti.
    /// **Nasce spento** (2026-08-11, sua richiesta).
    ///
    /// **Perché prepara invece di reagire, che è la parte non ovvia.** Abbassato il coperchio, macOS
    /// addormenta il Mac in una frazione di secondo: un'app che se ne accorgesse dopo si sveglierebbe
    /// a cose fatte, e il giro di NoSleep passa ogni cinque secondi. L'unico momento in cui la
    /// decisione si può ancora prendere è **prima**, quindi acceso questo, il coperchio si arma
    /// insieme a «tieni sveglio» e si disarma con lui.
    ///
    /// Il costo, che va detto perché è vero: da armato il sonno resta disattivato anche a coperchio
    /// alzato. Le due reti di sicurezza e la soglia di batteria restano al loro posto, e «disattiva
    /// quando il lavoro finisce» chiude il giro.
    public var lidFollowsAwake: Bool
    /// Sotto questa carica, a batteria, NoSleep molla tutto e lascia dormire il Mac.
    ///
    /// **Nasce acceso a 20**, che è la soglia sotto cui macOS stesso comincia ad avvisare. Tenere
    /// sveglio un portatile che sta per spegnersi non finisce il lavoro, lo fa morire più in là.
    public var batteryFloorOn: Bool
    public var batteryFloor: Int

    public init(screenAwake: Bool = false,
                awakeMode: AwakeMode = .screenAndActivity,
                lidAwake: Bool = false,
                releaseWhenWorkEnds: Bool = true,
                autoArmOnWork: Bool = false,
                lidFollowsAwake: Bool = false,
                batteryFloorOn: Bool = true,
                batteryFloor: Int = 20) {
        self.screenAwake = screenAwake
        self.awakeMode = awakeMode
        self.lidAwake = lidAwake
        self.releaseWhenWorkEnds = releaseWhenWorkEnds
        self.autoArmOnWork = autoArmOnWork
        self.lidFollowsAwake = lidFollowsAwake
        self.batteryFloorOn = batteryFloorOn
        self.batteryFloor = batteryFloor
    }

    /// I valori proposti. Cinque, non un cursore: una soglia di batteria non ha bisogno della
    /// precisione al punto percentuale, e un cursore la chiederebbe.
    public static let batteryFloorChoices = [10, 15, 20, 30, 50]

    private enum CodingKeys: String, CodingKey {
        case screenAwake, awakeMode, lidAwake, releaseWhenWorkEnds, autoArmOnWork
        case lidFollowsAwake, batteryFloorOn, batteryFloor
    }

    /// Un campo aggiunto dopo non deve far fallire la lettura di un file scritto prima: senza
    /// questo, l'arrivo di `awakeMode` avrebbe riportato in silenzio ogni configurazione esistente
    /// agli stati di nascita, e l'utente avrebbe visto i suoi interruttori tornare indietro da soli.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        screenAwake = try c.decodeIfPresent(Bool.self, forKey: .screenAwake) ?? false
        awakeMode = try c.decodeIfPresent(AwakeMode.self, forKey: .awakeMode) ?? .screenAndActivity
        lidAwake = try c.decodeIfPresent(Bool.self, forKey: .lidAwake) ?? false
        releaseWhenWorkEnds = try c.decodeIfPresent(Bool.self, forKey: .releaseWhenWorkEnds) ?? true
        autoArmOnWork = try c.decodeIfPresent(Bool.self, forKey: .autoArmOnWork) ?? false
        lidFollowsAwake = try c.decodeIfPresent(Bool.self, forKey: .lidFollowsAwake) ?? false
        batteryFloorOn = try c.decodeIfPresent(Bool.self, forKey: .batteryFloorOn) ?? true
        batteryFloor = try c.decodeIfPresent(Int.self, forKey: .batteryFloor) ?? 20
    }

    /// Gli stati di nascita, che sono un requisito e non un default di comodo (ISC-40).
    public static let atBirth = Config()

    // ── Persistenza ──────────────────────────────────────────────────────────

    /// Le due prese (`screenAwake`, `lidAwake`) **non si ricordano fra un avvio e l'altro**, e non
    /// è una dimenticanza: un'app che riparte dopo un crash ricominciando a tenere sveglio il Mac
    /// senza che nessuno gliel'abbia chiesto è esattamente il guasto contro cui esiste il cane da
    /// guardia. Si ricordano solo le due preferenze di comportamento.
    public static func load(from url: URL) -> Config {
        guard let data = try? Data(contentsOf: url),
              let saved = try? JSONDecoder().decode(Config.self, from: data) else {
            return .atBirth
        }
        return Config(screenAwake: false,
                      awakeMode: saved.awakeMode,
                      lidAwake: false,
                      releaseWhenWorkEnds: saved.releaseWhenWorkEnds,
                      autoArmOnWork: saved.autoArmOnWork,
                      lidFollowsAwake: saved.lidFollowsAwake,
                      batteryFloorOn: saved.batteryFloorOn,
                      batteryFloor: saved.batteryFloor)
    }

    @discardableResult
    public func save(to url: URL) -> Bool {
        guard let data = try? JSONEncoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
