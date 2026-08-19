import AppKit
import SwiftUI
import NoSleepCore
import ServiceManagement

/// **Limite dichiarato dello scatto:** la riga «Avvia all'accesso» esce sempre **spenta** nelle
/// fotografie, e non è un difetto dell'app. `SMAppService.mainApp` parla del bundle che lo chiama,
/// e la sonda gira da `.build/release/`, fuori da un `.app`: da lì lo stato è `notFound`, che la
/// riga rende come spento. Lo stato vero si legge con `--selftest-login` **eseguito dal bundle
/// installato**. Chi guarda uno scatto non deve dedurne che l'avvio automatico è disattivato.
///
/// `--scatta <file.png>` — fotografa il pannello **vero**, quello che si apre dalla barra dei menu.
///
/// Serve perché l'armonia non è una proprietà di un interruttore, è la relazione fra interruttori
/// vicini: guardare il comando appena scritto non dice niente, guardare la pagina intera sì. Senza
/// questa sonda l'unico modo di vedere il pannello sarebbe cliccarci sopra a mano.
final class ShotDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    /// Il banco delle icone: tutte quelle che possono comparire nella barra devono avere la stessa
    /// larghezza, altrimenti il pannello si sposta di lato quando cambia stato.
    ///
    /// Non asserisce l'ambiente, asserisce **la nostra scelta**: se un domani qualcuno mette un
    /// simbolo di larghezza diversa in `Icons`, questo diventa rosso e la build si ferma.
    @MainActor static func checkIcons() -> Never {
        let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        var widths: [String: CGFloat] = [:]
        for n in Icons.all {
            guard let img = NSImage(systemSymbolName: n, accessibilityDescription: nil)?
                .withSymbolConfiguration(cfg) else {
                print("✗ il simbolo «\(n)» non esiste su questo macOS")
                exit(1)
            }
            widths[n] = img.size.width
        }
        for (n, w) in widths.sorted(by: { $0.key < $1.key }) {
            print(String(format: "  %-30@ %5.1f pt", n as NSString, w))
        }
        // L'invariante non è più «tutti uguali», è «nessuno più largo della cornice»: a tenere
        // fermo il pannello è la cornice fissa dell'etichetta, e questo controlla solo che nessun
        // simbolo venga tagliato.
        let troppoLarghi = widths.filter { $0.value > Icons.frameWidth }
        if !troppoLarghi.isEmpty {
            print("✗ più larghi della cornice da \(Icons.frameWidth) pt: \(troppoLarghi.keys.sorted())")
            exit(1)
        }
        // Il polo negativo: `bolt.horizontal.fill` è largo 24pt, cioè oltre la cornice, ed è
        // proprio il simbolo che causò lo spostamento. Se il banco non lo bocciasse, non starebbe
        // controllando niente e il verde qui sopra non varrebbe.
        let control = NSImage(systemSymbolName: "bolt.horizontal.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)?.size.width ?? 0
        guard control > Icons.frameWidth else {
            print("✗ il banco non discrimina: il controllo da \(control) pt starebbe nella cornice")
            exit(1)
        }
        print("✓ tutte dentro la cornice da \(Icons.frameWidth) pt, e il controllo a \(control) pt viene bocciato")

        // ── Quale stato mostra quale segno ───────────────────────────────────
        //
        // **Tre stati devono dare tre segni DIVERSI**, e il controllo è quello, non l'elenco dei
        // nomi. Ereditato il 12/08 dal banco del cavallo, dove viveva attaccato a un timer che non
        // esiste più.
        //
        // **Quel che questo banco NON può giudicare, e va detto:** `bolt` e `bolt.fill` sono due
        // nomi diversi e passano, ma sono lo stesso segno in due pesi, che è più difficile da
        // distinguere di due disegni diversi. È una scelta sua del 12/08, presa dopo aver provato
        // sia il cavallo che la tazza e aver deciso che la larghezza contava di più. Un banco che
        // pretendesse anche disegni diversi renderebbe rossa una decisione, non un difetto.
        let stati: [(String, String)] = [
            ("a riposo", Icons.glyph(awake: false, mode: .activityOnly, lid: false)),
            ("solo attività", Icons.glyph(awake: true, mode: .activityOnly, lid: false)),
            ("schermo e attività", Icons.glyph(awake: true, mode: .screenAndActivity, lid: false)),
        ]
        for (nome, segno) in stati { print(String(format: "  %-20@ → %@", nome as NSString, segno as NSString)) }
        guard Set(stati.map(\.1)).count == stati.count else {
            print("✗ due stati mostrano lo stesso segno: dalla barra non si distinguono")
            exit(1)
        }
        // Il coperchio armato SENZA «tieni sveglio»: il Mac non dorme, il display è libero, ed è
        // «solo attività».
        guard Icons.glyph(awake: false, mode: .screenAndActivity, lid: true) == Icons.awakeActivity else {
            print("✗ col solo coperchio armato la barra non mostra il segno di «solo attività»")
            exit(1)
        }
        // **Il polo che era rosso fino al 19/08.** Con «prepara il coperchio» accesa la presa del
        // coperchio è armata a ogni lavoro, e prima decideva lei il segno: il fulmine restava vuoto
        // anche in «schermo e attività», cioè la barra mentiva sulla modalità scelta a mano.
        guard Icons.glyph(awake: true, mode: .screenAndActivity, lid: true) == Icons.awakeScreen else {
            print("✗ col coperchio armato la modalità «schermo e attività» non mostra il fulmine pieno")
            exit(1)
        }
        guard Icons.glyph(awake: true, mode: .activityOnly, lid: true) == Icons.awakeActivity else {
            print("✗ col coperchio armato «solo attività» non mostra il fulmine vuoto")
            exit(1)
        }
        print("✓ tre stati, tre segni diversi, e il coperchio armato non cancella la modalità")
        exit(0)
    }

    /// Il banco del cavallo: i dati e il disegno.
    ///
    /// **Il cavallo non è più nella barra dal 12/08** — costava il 19,9% di un core — ma il disegno
    /// resta nel repo, e questo banco è ciò che lo tiene vivo e rimettibile: finché passa, `Horse`,
    /// `HorseMotion` e `HorseImage` sono ancora d'accordo fra loro e con le maschere in
    /// `Scripts/cavallo/`. Il pezzo che è caduto con lui è la prova di *quando* galoppava, che
    /// misurava un timer che adesso non esiste.
    ///
    /// `--selftest-horse [file.png]` — senza file controlla e basta, con un file scrive anche il
    /// foglio delle quindici pose alla misura vera della barra dei menu, che è l'unico modo di
    /// vedere se a quindici punti il cavallo si legge ancora o è diventato una macchia.
    @MainActor static func checkHorse() -> Never {
        guard Horse.poses.count == 15 else {
            print("✗ \(Horse.poses.count) pose invece di 15: il ciclo del galoppo non torna")
            exit(1)
        }
        for (i, posa) in Horse.poses.enumerated() {
            guard posa.count == Horse.rows else {
                print("✗ posa \(i): \(posa.count) righe invece di \(Horse.rows)")
                exit(1)
            }
            guard posa.allSatisfy({ $0.count == Horse.columns }) else {
                print("✗ posa \(i): una riga non è larga \(Horse.columns) celle")
                exit(1)
            }
            let n = Horse.dots(pose: i).count
            guard n > 80 else {
                print("✗ posa \(i): solo \(n) pallini, il cavallo non si vedrebbe")
                exit(1)
            }
        }
        // Due pose uguali di fila sono un fotogramma perso: l'animazione zoppica e non si capisce
        // perché. Vale anche fra l'ultima e la prima, che è il punto in cui il ciclo si richiude.
        for i in 0..<Horse.poses.count {
            let a = Horse.poses[i], b = Horse.poses[(i + 1) % Horse.poses.count]
            guard a != b else {
                print("✗ le pose \(i) e \((i + 1) % Horse.poses.count) sono identiche")
                exit(1)
            }
        }
        // Il polo negativo: il confronto deve saper dire «uguali» quando lo sono davvero. Senza,
        // il verde qui sopra non escluderebbe un confronto che approva tutto.
        guard Horse.poses[0] == Horse.poses[0], Horse.poses[0] != Horse.poses[1] else {
            print("✗ il banco non discrimina: non distingue due pose uguali da due diverse")
            exit(1)
        }
        print("  \(Horse.poses.count) pose, \(Horse.columns)×\(Horse.rows) celle, "
              + "pallini \(Horse.dots(pose: 0).count)…\(Horse.dots(pose: 2).count), nessuna ripetuta")

        let file = CommandLine.arguments.firstIndex(of: "--selftest-horse")
            .flatMap { i -> String? in
                let j = i + 1
                guard j < CommandLine.arguments.count,
                      !CommandLine.arguments[j].hasPrefix("--") else { return nil }
                return CommandLine.arguments[j]
            }
        if let file {
            let h = Icons.horseHeight, w = HorseImage.width(height: h)
            // Tre righe: la misura vera, il doppio e il quadruplo. La prima dice se funziona, le
            // altre due dicono perché — a occhio nudo quindici punti sono troppo pochi per capire
            // che cosa si sta guardando.
            let scale: [Double] = [1, 2, 4]
            let foglio = NSImage(size: NSSize(width: w * Double(Horse.poses.count * HorseImage.substeps + 2) * 4, height: h * (1 + 2 + 4) + 24))
            foglio.lockFocus()
            NSColor.white.setFill()
            NSRect(origin: .zero, size: foglio.size).fill()
            var y = 8.0
            for k in scale.reversed() {
                for p in 0..<(Horse.poses.count * HorseImage.substeps) {
                    let img = HorseImage.image(pose: p, height: h * k)
                    img.draw(in: NSRect(x: Double(p) * w * k, y: y, width: w * k, height: h * k),
                             from: .zero, operation: .sourceOver, fraction: 1)
                }
                // Accanto, alla stessa altezza, i due simboli di sistema che si alternano al
                // cavallo nella barra: il peso di un'icona non è una sua proprietà, è il rapporto
                // con quelle che le stanno vicino, e a occhio da solo non si giudica.
                let cfg = NSImage.SymbolConfiguration(pointSize: 15 * k, weight: .regular)
                for (i, nome) in Icons.all.enumerated() {
                    guard let sym = NSImage(systemSymbolName: nome, accessibilityDescription: nil)?
                        .withSymbolConfiguration(cfg) else { continue }
                    sym.draw(in: NSRect(x: Double(Horse.poses.count * HorseImage.substeps) * w * k + Double(i) * 20 * k, y: y,
                                        width: sym.size.width, height: sym.size.height),
                             from: .zero, operation: .sourceOver, fraction: 1)
                }
                y += h * k + 8
            }
            foglio.unlockFocus()
            guard let tiff = foglio.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
                  (try? png.write(to: URL(fileURLWithPath: file))) != nil else {
                print("✗ non sono riuscito a scrivere \(file)")
                exit(1)
            }
            print("  foglio: \(file) (\(png.count) byte)")
        }
        // ── I fotogrammi in mezzo ────────────────────────────────────────────
        //
        // Quindici pose al giro sono dodici e mezzo al secondo, e a occhio si vedono a scatti. Fra
        // una posa e l'altra i pallini adesso si spostano invece di saltare: qui si prova che quel
        // viaggio non inventa niente e non spara pallini attraverso il cavallo.
        for k in 0..<Horse.poses.count {
            let vera = Horse.dots(pose: k)
            let a0 = HorseMotion.dots(from: k, t: 0)
            guard a0.count == vera.count,
                  zip(a0, vera).allSatisfy({ $0.x == Double($1.x) && $0.y == Double($1.y) && $0.r == $1.r }) else {
                print("✗ posa \(k): a t=0 l'interpolazione non restituisce la posa vera")
                exit(1)
            }
            let mezzo = HorseMotion.dots(from: k, t: 0.5)
            // Nessun pallino può finire fuori dalla griglia: un appaiamento sbagliato che lo
            // spedisse dall'altra parte si vedrebbe come una scintilla che attraversa il cavallo.
            guard mezzo.allSatisfy({ $0.x >= 0 && $0.x <= Double(Horse.columns - 1)
                                     && $0.y >= 0 && $0.y <= Double(Horse.rows - 1) }) else {
                print("✗ posa \(k): un pallino intermedio è finito fuori dalla griglia")
                exit(1)
            }
            // Il polo negativo del viaggio: a metà strada il fotogramma dev'essere DIVERSO da tutte
            // e due le pose vere. Se fosse uguale a una delle due, l'interpolazione non starebbe
            // interpolando e i tre fotogrammi sarebbero lo stesso disegno ripetuto.
            let dopo = Horse.dots(pose: (k + 1) % Horse.poses.count)
            func uguale(_ a: [HorseMotion.Dot], _ b: [(x: Int, y: Int, r: Double)]) -> Bool {
                a.count == b.count && zip(a, b).allSatisfy { $0.x == Double($1.x) && $0.y == Double($1.y) }
            }
            guard !uguale(mezzo, vera), !uguale(mezzo, dopo) else {
                print("✗ posa \(k): il fotogramma di mezzo è identico a una posa vera")
                exit(1)
            }
        }
        print("  \(Horse.poses.count * HorseImage.substeps) fotogrammi al giro, "
              + String(format: "%.1f al secondo", HorseImage.frameRate)
              + ", viaggio al massimo \(Int(HorseMotion.maxTravel)) celle")

        print("✓ il cavallo tiene: \(Horse.poses.count) pose distinte, fotogrammi intermedi in viaggio")
        exit(0)
    }

    /// Il banco del limitatore termico, **end-to-end**.
    ///
    /// I test unitari provano che la politica decide giusto; questo prova che l'app **agisce** su
    /// quella decisione, cioè che le asserzioni cadono davvero. Sono due cose diverse, e fra le due
    /// c'è tutto il cablaggio che un test puro non vede.
    @MainActor static func checkThermal() -> Never {
        let model = AppModel()
        var livello = ThermalLevel.nominal
        model.thermalSource = { livello }
        // Le altre due reti si mettono a tacere: un banco sul termico deve misurare **il termico**.
        // Senza, con il Mac caldo per le build in corso (scocca sopra i 60 gradi) era la soglia sui
        // gradi misurati a mollare la presa, e il banco segnava rosso su un limitatore che
        // funzionava benissimo (2026-08-07). Un banco che non isola la regola che prova, prova le
        // altre.
        model.setBatteryFloorOn(false)
        model.temperatureSource = { .init(die: 40, board: 40, battery: 30) }

        // 1. Freddo e acceso a mano: deve tenere.
        model.setScreenAwake(true)
        model.tickNow()
        guard model.isActuallyHolding else {
            print("✗ a Mac freddo non tiene niente: il banco non sta misurando la cosa giusta")
            exit(1)
        }
        print("  freddo, acceso  → tiene   (polo positivo)")

        // 2. Tiepido: NON deve mollare. È il polo negativo, e senza di lui un'app che molla sempre
        //    passerebbe questo banco.
        livello = .fair
        model.tickNow()
        guard model.isActuallyHolding else {
            print("✗ molla già a «tiepido»: la soglia è sbagliata")
            exit(1)
        }
        print("  tiepido         → tiene   (polo negativo)")

        // 3. Caldo: deve mollare, e devono cadere le asserzioni vere, non solo la configurazione.
        livello = .serious
        model.tickNow()
        guard !model.isActuallyHolding else {
            print("✗ a «caldo» le asserzioni sono ancora vive: il limitatore non agisce")
            exit(1)
        }
        print("  caldo           → molla   (limitatore)")

        print("✓ il limitatore termico agisce sulle asserzioni, non solo sulla configurazione")
        exit(0)
    }

    /// Il banco del coperchio che segue, **end-to-end**.
    ///
    /// I test puri provano la regola; questo prova il **cablaggio**, cioè che l'app tenga davvero il
    /// conto del fronte e della memoria fra un comando e l'altro. È lì che vive il difetto che i test
    /// puri non possono vedere: la regola giusta chiamata con gli argomenti sbagliati.
    ///
    /// Non tocca l'helper vero: la richiesta finisce nella casa della sonda, come ogni altro banco.
    @MainActor static func checkLidFollow() -> Never {
        let m = AppModel()
        m.setBatteryFloorOn(false)
        m.temperatureSource = { .init(die: 40, board: 40, battery: 30) }
        guard m.helperInstalled else {
            print("  saltato: l'helper non è installato su questa macchina, e senza non c'è niente da provare")
            exit(0)
        }

        // 1. Regola spenta: acceso «tieni sveglio», il coperchio resta com'era. È il polo negativo.
        m.setScreenAwake(true)
        guard !m.config.lidAwake else { print("✗ il coperchio si è armato senza che la regola fosse accesa"); exit(1) }
        print("  regola spenta, tieni sveglio acceso → coperchio fermo   (polo negativo)")
        m.setScreenAwake(false)

        // 2. Regola accesa, poi «tieni sveglio»: il coperchio deve armarsi.
        m.setLidFollowsAwake(true)
        m.setScreenAwake(true)
        guard m.config.lidAwake else { print("✗ il coperchio non si è armato"); exit(1) }
        print("  regola accesa, tieni sveglio acceso  → coperchio armato (polo positivo)")

        // 3. Spento a mano mentre tutto è acceso: NON deve tornare su da solo, nemmeno dopo un giro.
        m.setLidAwake(false)
        m.tickNow()
        guard !m.config.lidAwake else { print("✗ riarmato dopo che l'avevo spento a mano: l'app combatte contro la mano"); exit(1) }
        print("  spento a mano                        → resta spento     (il fronte, non lo stato)")

        // 4. Spegni e riaccendi «tieni sveglio»: adesso il fronte c'è, e deve riarmarsi.
        m.setScreenAwake(false)
        m.setScreenAwake(true)
        guard m.config.lidAwake else { print("✗ non si è riarmato al fronte successivo"); exit(1) }
        print("  spento e riacceso                    → riarmato         (il fronte dopo)")

        // 5. Spento «tieni sveglio»: quello che aveva armato la regola se ne va con lui.
        m.setScreenAwake(false)
        guard !m.config.lidAwake else { print("✗ il coperchio è rimasto armato senza tieni sveglio"); exit(1) }
        print("  tieni sveglio spento                 → coperchio mollato")

        print("✓ il coperchio segue «tieni sveglio» e lascia l'ultima parola alla sua mano")
        exit(0)
    }

    /// Il banco dell'addormentamento, **end-to-end**: non che la decisione sia giusta, che l'app
    /// arrivi davvero a chiamare il comando, e che lo annulli quando deve.
    @MainActor static func checkSleep() -> Never {
        // **Prima dei poli finti, la lettura vera.** Tutto il banco gira su un'inattività iniettata,
        // e un banco tutto iniettato non prova mai che la sonda sappia leggere il mondo: si
        // confronta con `ioreg -c IOHIDSystem | grep HIDIdleTime`, che è la stessa proprietà.
        print(String(format: "  inattività letta dal sistema: %.1f s", PowerAssertion.userIdleSeconds()))
        var chiamate = 0
        func nuovo(lidClosed: Bool, idle: Double) -> AppModel {
            PowerAssertion.clamshellOverride = lidClosed
            PowerAssertion.idleOverride = idle
            let m = AppModel()
            // Niente respiro: qui si misura **quale porta si apre**, non l'attesa, che ha il suo
            // polo apposta più sotto.
            m.grace = 0
            m.sleepAction = { chiamate += 1 }
            // Il rilascio a fine lavoro scatta solo se c'era qualcosa da rilasciare: senza questo
            // il banco misurava un non-evento e sembrava un difetto dell'app.
            // Stessa ragione del banco termico: qui si prova l'addormentamento, non le reti.
            m.setBatteryFloorOn(false)
            m.temperatureSource = { .init(die: 40, board: 40, battery: 30) }
            m.setScreenAwake(true)
            return m
        }
        func fineLavoro(_ m: AppModel, giri: Int = 2) {
            m.simulateWorkEnded()
            for _ in 0..<giri { m.tickNow() }
        }

        // 1. Coperchio ALZATO con lui alla tastiera: **il polo negativo che conta più di tutti**.
        //    Un Mac che si addormenta in faccia a chi lo sta leggendo è il difetto che farebbe
        //    disinstallare l'app.
        chiamate = 0
        fineLavoro(nuovo(lidClosed: false, idle: 5))
        guard chiamate == 0 else { print("✗ ha addormentato mentre lui stava usando il Mac"); exit(1) }
        print("  alzato, lui c'è      → non addormenta   (polo negativo)")

        // 2. Coperchio alzato e nessuno alla tastiera da più di cinque minuti: la porta nuova del
        //    19/08.
        chiamate = 0
        fineLavoro(nuovo(lidClosed: false, idle: SleepDecision.idleThreshold + 10))
        guard chiamate == 1 else { print("✗ alzato e fermo da 5 minuti: non ha addormentato (\(chiamate))"); exit(1) }
        print("  alzato, fermo da 5\'  → addormenta       (polo positivo)")

        // 3. Coperchio chiuso: la porta di sempre, che l'inattività non deve aver rotto.
        chiamate = 0
        fineLavoro(nuovo(lidClosed: true, idle: 0))
        guard chiamate == 1 else { print("✗ a coperchio chiuso non ha addormentato (\(chiamate))"); exit(1) }
        print("  chiuso               → addormenta       (era già così)")

        // 4. Coperchio riaperto durante l'attesa, con lui alla tastiera: **non annulla, aspetta**,
        //    ed è la differenza che questa riga diceva sbagliata fino al 19/08. L'attesa resta
        //    viva perché la porta dell'inattività può ancora aprirsi: se lui riapre il coperchio e
        //    poi se ne va, il Mac dorme lo stesso, che è tutto il punto della modifica di oggi.
        chiamate = 0
        let riaperto = nuovo(lidClosed: true, idle: 0)
        riaperto.simulateWorkEnded()
        PowerAssertion.clamshellOverride = false
        riaperto.tickNow(); riaperto.tickNow()
        guard chiamate == 0 else { print("✗ ha addormentato dopo che il coperchio si era riaperto"); exit(1) }
        print("  riaperto, lui c'è    → aspetta          (la porta dell'inattività resta)")

        // 5. NoSleep riacceso durante l'attesa: l'attesa decade, e non riparte da sola.
        chiamate = 0
        let riacceso = nuovo(lidClosed: false, idle: SleepDecision.idleThreshold + 10)
        riacceso.simulateWorkEnded()
        riacceso.setScreenAwake(true)
        riacceso.tickNow(); riacceso.tickNow()
        guard chiamate == 0 else { print("✗ ha addormentato con «tieni sveglio» riacceso"); exit(1) }
        print("  riacceso in attesa   → annulla          (nessuno dorme sotto una presa viva)")

        // 6. Il respiro esiste: con la grazia vera, il primo giro non addormenta nessuno.
        chiamate = 0
        let subito = nuovo(lidClosed: true, idle: 0)
        subito.grace = SleepDecision.grace
        fineLavoro(subito)
        guard chiamate == 0 else { print("✗ ha addormentato prima dei \(Int(SleepDecision.grace)) secondi di respiro"); exit(1) }
        print("  primo giro           → aspetta          (il respiro è vero)")

        PowerAssertion.idleOverride = nil
        print("✓ addormenta a coperchio chiuso, e da alzato solo quando lui ha lasciato stare il Mac")
        exit(0)
    }

    /// Lo stato dell'avvio all'accesso.
    ///
    /// **Va eseguito dal bundle installato**, non dal binario in `.build`: `SMAppService.mainApp`
    /// parla del bundle che lo chiama, e fuori da un `.app` risponde `notFound`. Ci ho perso una
    /// sonda prima di accorgermene (2026-08-07).
    @MainActor static func checkLogin() -> Never {
        let nomi: [SMAppService.Status: String] = [
            .enabled: "registrata e attiva",
            .notRegistered: "non registrata",
            .notFound: "bundle non trovato (stai girando fuori dal .app?)",
            .requiresApproval: "registrata, in attesa che l'utente la approvi in Impostazioni",
        ]
        let st = SMAppService.mainApp.status
        print("  avvio all'accesso: \(nomi[st] ?? "sconosciuto (\(st.rawValue))")")
        exit(st == .enabled || st == .requiresApproval ? 0 : 1)
    }

    /// Il banco delle Preferenze, e prova **la cosa che si è rotta il 7/08**: l'app non deve mai
    /// cambiare politica di attivazione, perché farlo scombina l'elemento nella barra dei menu e il
    /// fulmine smette di rispondere al clic. La finestra deve venire avanti restando `.accessory`.
    @MainActor static func checkPreferences() -> Never {
        let model = AppModel()
        // La condizione di partenza dell'app vera gliela dà `LSUIElement` nell'Info.plist; il
        // binario del banco gira fuori dal bundle, quindi nasce `.regular` e qui la si stabilisce a
        // mano. Non è barare: quel che si prova è che da qui in poi **non cambi più**.
        NSApp.setActivationPolicy(.accessory)
        guard NSApp.activationPolicy() == .accessory else {
            print("✗ non riesco a mettere l'app accessoria: il banco non può misurare niente")
            exit(1)
        }
        PreferencesWindow.shared.show(model: model)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        guard NSApp.activationPolicy() == .accessory else {
            print("✗ aprendo le Preferenze l'app è diventata .regular: l'icona della barra si rompe")
            exit(1)
        }
        guard let w = NSApp.windows.first(where: { $0.title.contains("Preferenze") }), w.isVisible else {
            print("✗ la finestra non è visibile")
            exit(1)
        }
        print("  apro le Preferenze   → finestra visibile, politica ancora .accessory")

        w.performClose(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        guard NSApp.activationPolicy() == .accessory else {
            print("✗ chiudendo, la politica è cambiata")
            exit(1)
        }
        print("  chiudo le Preferenze → politica invariata  (l'icona resta viva)")
        print("✓ la finestra viene avanti senza mai toccare la politica di attivazione")
        exit(0)
    }

    /// `--barra <file.png>` — fotografa la **barra dei menu vera**, con l'elemento vero dentro.
    ///
    /// **Perché serve, dopo il foglio delle pose.** Il foglio prova il disegno; questa prova
    /// l'elemento nella barra, cioè larghezza, allineamento, tinta automatica e peso accanto alle
    /// icone di sistema, che sono cose che il disegno da solo non dice. È la stessa lezione della
    /// regola sull'armonia: si guarda la pagina intera, e qui la pagina è la barra.
    ///
    /// **E soprattutto non tocca la sua app.** Gira in una casa tutta sua (`Paths.homeOverride`),
    /// quindi la configurazione, il registro e la richiesta all'helper sono altri file; l'unica cosa
    /// vera che prende è un'asserzione di risparmio energia per i pochi secondi dello scatto. La sua
    /// NoSleep resta accesa e compare accanto, che è anche il confronto migliore.
    static var wantsBarProbe: Bool { CommandLine.arguments.contains("--barra") }

    /// `--sveglio` — la sonda nasce come se il Mac fosse tenuto sveglio in «solo attività», che è lo
    /// stato in cui il cavallo si vede. Vale per `--barra` e per `--scatta`: senza, ogni fotografia
    /// mostrerebbe lo stato a riposo, cioè l'unico in cui il cavallo non c'è.
    static var wantsAwake: Bool { wantsBarProbe || CommandLine.arguments.contains("--sveglio") }

    private static var barProbePath: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--barra"), i + 1 < a.count, !a[i + 1].hasPrefix("--") else { return nil }
        return a[i + 1]
    }

    /// Questo processo è una sonda? Le sonde non toccano lo stato vero e non contano come istanza.
    static var isProbe: Bool {
        requestedPath != nil
            || CommandLine.arguments.contains("--selftest-icons")
            || CommandLine.arguments.contains("--selftest-horse")
            || wantsBarProbe
            || CommandLine.arguments.contains("--selftest-thermal")
            || CommandLine.arguments.contains("--selftest-sleep")
            || CommandLine.arguments.contains("--selftest-lidfollow")
            || CommandLine.arguments.contains("--selftest-login")
            || CommandLine.arguments.contains("--selftest-prefs")
    }

    static func sandbox() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nosleep-sonda-\(ProcessInfo.processInfo.processIdentifier)")
    }

    static var requestedPath: String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "--scatta"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    /// La faccia da fotografare: `--chiaro` o `--scuro`, perché un pannello va guardato in
    /// entrambe e il sistema ne mostra una sola per volta.
    private static var appearance: NSAppearance? {
        if CommandLine.arguments.contains("--scuro") { return NSAppearance(named: .darkAqua) }
        if CommandLine.arguments.contains("--chiaro") { return NSAppearance(named: .aqua) }
        return nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // **Ogni** sonda lavora su uno stato tutto suo, non solo il banco termico. `--scatta`
        // costruisce l'`AppModel` vero, quindi scriveva la richiesta all'helper e **spegneva il
        // coperchio dell'app in esecuzione**: successo il 2026-08-07 mentre lui aveva il coperchio
        // attivo, e l'eccezione delle sonde alla istanza singola non basta a proteggerlo. La regola
        // resta quella già scritta in `Paths.homeOverride`: chi costruisce l'oggetto vero deve
        // prima dirottarne lo stato.
        if Self.isProbe { Paths.homeOverride = Self.sandbox() }

        if CommandLine.arguments.contains("--selftest-icons") { Self.checkIcons() }
        if CommandLine.arguments.contains("--selftest-horse") { Self.checkHorse() }
        if CommandLine.arguments.contains("--selftest-thermal") { Self.checkThermal() }
        if CommandLine.arguments.contains("--selftest-sleep") { Self.checkSleep() }
        if CommandLine.arguments.contains("--selftest-lidfollow") { Self.checkLidFollow() }
        if CommandLine.arguments.contains("--selftest-login") { Self.checkLogin() }
        if CommandLine.arguments.contains("--selftest-prefs") { Self.checkPreferences() }

        // Le sonde (`--scatta`, `--selftest-*`) sono processi usa-e-getta e devono poter girare
        // accanto all'app installata; l'app vera invece è una sola.
        if !Self.isProbe { SingleInstance.enforceOrExit() }

        if Self.wantsBarProbe, let file = Self.barProbePath {
            // Uno scatto solo. **Erano tre a mezzo secondo l'uno dall'altro** finché nella barra
            // c'era il cavallo, perché uno solo avrebbe detto che c'è e non che galoppa; con un
            // segno fermo tre scatti sono tre volte la stessa fotografia.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                // La striscia in alto a destra, dove vivono gli elementi della barra.
                let larghezza = Int((NSScreen.main?.frame.width ?? 1600))
                p.arguments = ["-R\(larghezza - 700),0,700,26", "-o", "-x", file]
                try? p.run()
                p.waitUntilExit()
            }
            // `--secondi N` tiene in vita la sonda: serve a misurare quanto costa davvero l'elemento
            // nella barra, che con tre secondi di vita sarebbe indistinguibile dal costo dell'avvio.
            let vita = CommandLine.arguments.firstIndex(of: "--secondi")
                .flatMap { i in i + 1 < CommandLine.arguments.count ? Double(CommandLine.arguments[i + 1]) : nil } ?? 3.0
            DispatchQueue.main.asyncAfter(deadline: .now() + max(3.0, vita)) { exit(0) }
            return
        }

        guard let path = Self.requestedPath else { return }

        let model = AppModel()
        let prefs = CommandLine.arguments.contains("--preferenze")
        let host: NSHostingView<AnyView> = prefs
            ? NSHostingView(rootView: AnyView(PreferencesView(model: model)))
            : NSHostingView(rootView: AnyView(MenuView(model: model)))
        host.frame = NSRect(x: 0, y: 0, width: prefs ? 440 : 330, height: 340)

        let w = NSWindow(contentRect: host.frame,
                         styleMask: [.titled, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.contentView = host
        if let a = Self.appearance { w.appearance = a }
        w.setFrameOrigin(NSPoint(x: 200, y: 300))
        // Senza `.regular` l'app resta un accessorio della barra dei menu, la finestra non diventa
        // mai davvero attiva, e macOS disegna OGNI comando nello stato inattivo: un interruttore
        // acceso esce grigio identico a uno spento, e la fotografia mente su ciò che si sta
        // guardando. È esattamente il difetto che questa sonda dovrebbe trovare, non produrre.
        NSApp.setActivationPolicy(.regular)
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w

        // Sei secondi e mezzo, non uno: sotto i cinque il giro del modello non è ancora passato e
        // l'intestazione mostrerebbe lo stato iniziale invece di quello vero.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { [weak self] in
            guard let n = self?.window?.windowNumber else { exit(3) }
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            p.arguments = ["-l\(n)", "-o", "-x", path]
            try? p.run()
            p.waitUntilExit()
            // Il cancello: un file che non esiste o è vuoto non è una fotografia.
            let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            FileHandle.standardOutput.write(Data("scatto: \(path) (\(size ?? 0) byte)\n".utf8))
            exit((size ?? 0) > 1000 ? 0 : 4)
        }
    }
}
