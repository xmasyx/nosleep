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
                ForEach(WipeDuration.allCases, id: \.rawValue) { d in
                    NSChip(title: d.label, selected: model.config.wipeDuration == d, s: s) {
                        model.setWipeDuration(d)
                    }
                }
            }
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
                Text("attivo")
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
}
