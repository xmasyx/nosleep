import SwiftUI
import NoSleepCore

/// Le righe che compaiono **in tutte e due le finestre**.
///
/// **Perché la duplicazione qui è giusta e altrove no.** Le Preferenze sono la superficie completa,
/// il pannello è la scorciatoia ai comandi che si toccano ogni giorno: chi cerca un'impostazione la
/// trova sempre in Preferenze, senza doversi ricordare in quale delle due finestre l'abbiamo messa
/// (sua scelta, 2026-08-07). Le due finestre non copiano lo stato, guardano lo stesso `AppModel`,
/// quindi non possono divergere; e siccome la riga è scritta **una volta sola qui**, non possono
/// divergere nemmeno nell'aspetto.
@MainActor
enum Rows {

    /// Le due caselle di modalità, attaccate all'interruttore che le userà e mai due volte nella
    /// stessa finestra: sotto «tieni sveglio» quando è acceso, altrimenti sotto l'automatismo.
    @ViewBuilder
    static func modeChips(model: AppModel, s: SurfacePalette) -> some View {
        HStack(spacing: 6) {
            NSChip(title: S.modeScreenAndActivity,
                   selected: model.config.awakeMode == .screenAndActivity, s: s) {
                model.setAwakeMode(.screenAndActivity)
            }
            NSChip(title: S.modeActivityOnly,
                   selected: model.config.awakeMode == .activityOnly, s: s) {
                model.setAwakeMode(.activityOnly)
            }
        }
    }

    static func awake(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.awakeTitle,
              note: S.awakeNote(screenToo: model.config.awakeMode == .screenAndActivity,
                                onAC: model.onAC),
              s: s) {
            NSSwitch(isOn: model.config.screenAwake, s: s) { model.setScreenAwake($0) }
        } extra: {
            if model.config.screenAwake { modeChips(model: model, s: s) }
        }
    }

    static func lid(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.lidTitle, note: S.lidNote, s: s) {
            NSSwitch(isOn: model.config.lidAwake, s: s) { model.setLidAwake($0) }
        }
    }

    static func auto(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.autoTitle, note: S.autoNote, s: s) {
            NSSwitch(isOn: model.config.autoArmOnWork, s: s) { model.setAutoArm($0) }
        } extra: {
            if model.config.autoArmOnWork && !model.config.screenAwake {
                modeChips(model: model, s: s)
            }
        }
    }

    /// Solo in Preferenze, per sua richiesta: si decide una volta e non è un comando di tutti i
    /// giorni. Quello che si vede ogni giorno è il suo effetto, cioè l'interruttore del coperchio
    /// che nel pannello si accende da sé.
    ///
    /// La nota cambia quando manca l'helper, altrimenti l'interruttore sarebbe acceso senza fare
    /// niente e la riga direbbe una cosa falsa.
    static func lidFollow(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.lidFollowTitle,
              note: model.helperInstalled ? S.lidFollowNote : S.lidFollowNoHelper,
              s: s) {
            NSSwitch(isOn: model.config.lidFollowsAwake, s: s) { model.setLidFollowsAwake($0) }
        }
    }

    static func release(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.releaseTitle, note: S.releaseNote, s: s) {
            NSSwitch(isOn: model.config.releaseWhenWorkEnds, s: s) { model.setReleaseWhenWorkEnds($0) }
        }
    }

    static func battery(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.batteryTitle, note: S.batteryNote, s: s) {
            NSSwitch(isOn: model.config.batteryFloorOn, s: s) { model.setBatteryFloorOn($0) }
        } extra: {
            if model.config.batteryFloorOn {
                HStack(spacing: 6) {
                    ForEach(Config.batteryFloorChoices, id: \.self) { v in
                        NSChip(title: "\(v)%", selected: model.config.batteryFloor == v, s: s) {
                            model.setBatteryFloor(v)
                        }
                    }
                }
            }
        }
    }

    /// La pulizia della tastiera: le tre durate scelgono, il bottone parte.
    ///
    /// **Due comandi su una riga sola, e la divisione dei ruoli è quella che rende innocuo un
    /// click sbagliato:** le caselle non fanno partire niente, quindi l'unica cosa che spegne lo
    /// schermo è un bottone che si chiama «Pulisci». La riga dice anche come si esce **prima** di
    /// partire, che è l'unico momento in cui si può ancora leggere con calma.
    static func wipe(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.wipeTitle,
              note: S.wipeNote + " " + S.wipeExitNote(WipeExit.label),
              s: s) {
            NSButton(title: S.wipeStartButton, s: s) { model.startWipe() }
        } extra: {
            HStack(spacing: 6) {
                wipeChip(.one, model: model, s: s)
                wipeChip(.two, model: model, s: s)
                wipeChip(.five, model: model, s: s)
            }
        }
    }

    /// Una casella di durata, e **scritte a mano una per una invece che con un `ForEach`**.
    ///
    /// Non è gusto: dentro il pannello della barra dei menu (`MenuBarExtra(.window)`) il contenuto
    /// di un `ForEach` non viene rivalutato quando cambia lo stato osservato. Il clic arrivava
    /// (la scelta finiva sul disco e la pulizia durava davvero 2 o 5 minuti), ma l'evidenziazione
    /// restava ferma su «1 min»: da fuori è indistinguibile da una casella che non si può
    /// selezionare, ed è così che l'ha vista lui il 2026-08-28. Nella finestra delle Preferenze lo
    /// stesso `ForEach` si aggiornava, il che è la prova che il difetto sta nel pannello e non nel
    /// modello. Le caselle scritte come figlie dirette si aggiornano in tutte e due le finestre —
    /// è la stessa forma delle due caselle di modalità qui sopra, che infatti non hanno mai
    /// sbagliato.
    private static func wipeChip(_ d: WipeDuration, model: AppModel, s: SurfacePalette) -> some View {
        NSChip(title: d.label, selected: model.config.wipeDuration == d, s: s) {
            model.setWipeDuration(d)
        }
    }

    /// Il cancello che tiene onesto l'elenco scritto a mano: il giorno che nasce una quarta durata
    /// questo `switch` non compila più, e chi la aggiunge è costretto a metterla anche nella riga.
    private static func wipeDurationsAreExhaustive(_ d: WipeDuration) {
        switch d {
        case .one, .two, .five: break
        }
    }

    /// Solo in Preferenze: il permesso si concede una volta e non è un comando di tutti i giorni.
    /// La riga cambia faccia quando manca, invece di mostrare uno stato che nessuno può leggere.
    static func wipeAccess(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.wipeAxTitle,
              note: model.accessibilityGranted ? S.wipeAxNote : S.wipeAxMissing,
              s: s) {
            if !model.accessibilityGranted {
                NSButton(title: S.wipeAxOpenSettings, s: s) { model.openAccessibilitySettings() }
            } else {
                Text(S.accessibilityActive)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(s.active))
            }
        }
    }

    static func login(model: AppModel, s: SurfacePalette) -> some View {
        NSRow(title: S.loginTitle, note: S.loginNote, s: s) {
            NSSwitch(isOn: model.launchesAtLogin, s: s) { model.setLaunchAtLogin($0) }
        }
    }

    static func updates(model: AppModel, s: SurfacePalette) -> some View {
        UpdatesRow(updater: model.updater, s: s)
    }
}

/// Gli aggiornamenti, **in Preferenze e non più nel pannello** (sua richiesta, 31/08: «il verifica
/// aggiornamenti lo metterai all'interno di preferenze, così risulta più piccolo»).
///
/// **È una `struct` e non una funzione statica come le altre righe**, e non è una scelta di stile:
/// lo stato vive nell'`Updater`, non nell'`AppModel`, quindi una vista che osservasse solo il
/// modello resterebbe ferma su «Controllo…» mentre la risposta arriva. Osservando l'`Updater` la
/// riga si muove da sola.
///
/// La nota dice che il controllo è **automatico**: senza quella frase un bottone da solo fa
/// credere che senza premerlo non ci si accorga mai di una versione nuova, che è il contrario di
/// come funziona.
struct UpdatesRow: View {
    @ObservedObject var updater: Updater
    let s: SurfacePalette

    var body: some View {
        NSRow(title: S.updatesTitle, note: nota, s: s) {
            switch updater.state {
            case .available(_, let action):
                switch action {
                case .upgradeAndRelaunch:
                    NSButton(title: S.updatesUpgradeButton, s: s) { updater.perform(action) }
                case .openReleasePage:
                    NSButton(title: S.updatesDownloadButton, s: s) { updater.perform(action) }
                }
            case .checking, .upgrading:
                // Niente bottone mentre sta già lavorando: premerlo di nuovo ripartirebbe da capo.
                EmptyView()
            case .idle, .upToDate, .failed:
                NSButton(title: S.checkUpdatesButton, s: s) { updater.checkNow() }
            }
        }
    }

    /// Lo stato per esteso vive qui, dove uno viene apposta a chiederlo. Nel pannello resta solo
    /// ciò che richiede una decisione.
    private var nota: String {
        switch updater.state {
        case .idle: return S.updatesNote
        case .checking: return S.updatesChecking
        case .upToDate(let current): return S.updatesUpToDate(current) + " · " + S.updatesNote
        case .available(let version, _): return S.updatesAvailable(version)
        case .upgrading(let line): return line
        case .failed(let reason): return reason
        }
    }
}
