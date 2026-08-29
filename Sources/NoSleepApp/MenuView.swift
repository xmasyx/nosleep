import SwiftUI
import NoSleepCore

/// Il pannello che si apre dalla barra dei menu.
///
/// Regole di forma che valgono per tutta la pagina e non per il singolo comando: un interruttore
/// per riga, l'etichetta a sinistra e il comando allineato sullo stesso bordo destro, la nota sotto
/// la cosa che spiega e non sotto il gruppo.
///
/// Le parole non stanno qui: vivono tutte in `S`, così si possono leggere di seguito e far passare
/// da un controllo di lingua invece di essere riscritte una alla volta dentro le viste.
struct MenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private var s: SurfacePalette { scheme == .dark ? Surface.sera : Surface.giorno }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().overlay(Color(s.rule))

            VStack(alignment: .leading, spacing: 14) {
                Rows.awake(model: model, s: s)
                Rows.lid(model: model, s: s)

                if let msg = model.installMessage {
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(s.active))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)


            Divider().overlay(Color(s.rule))

            Divider().overlay(Color(s.rule))

            // Prima si attiva, poi si disattiva: l'ordine delle righe segue l'ordine dei fatti.
            VStack(alignment: .leading, spacing: 14) {
                Rows.auto(model: model, s: s)
                Rows.release(model: model, s: s)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().overlay(Color(s.rule))

            // La pulizia sta in fondo e da sola: non è un interruttore di stato come le righe
            // sopra, è una cosa che **succede adesso**, e mescolarla agli interruttori la farebbe
            // premere per sbaglio.
            VStack(alignment: .leading, spacing: 14) {
                Rows.wipe(model: model, s: s)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider().overlay(Color(s.rule))

            footer
        }
        .frame(width: 340)
        .background(Color(s.paper))
    }

    // ── Pezzi ────────────────────────────────────────────────────────────────

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                // Lo stesso glifo della barra dei menu, deciso dallo stesso codice: due scelte della
                // stessa cosa divergono, e qui il divario si vedrebbe.
                Image(systemName: model.glyph)
                    .foregroundStyle(Color(model.isHolding ? s.active : s.dim))
                Text(model.isHolding ? S.headerHolding : S.headerIdle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(s.text))
                Spacer()
            }
            Text(statusLine)
                .font(.system(size: 11))
                .foregroundStyle(Color(s.dim))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var statusLine: String {
        var parts: [String] = []
        // «1 lavoro/i attivo/i» è la barra obliqua di chi non ha voluto scrivere due parole.
        switch model.leaseCount {
        case 0: parts.append(S.noWork)
        case 1: parts.append(S.oneWork)
        case let n: parts.append(S.manyWork(n))
        }
        if model.thermal > .nominal { parts.append(S.macThermal(model.thermal.name)) }
        // I gradi si mostrano quando servono, cioè quando l'app sta tenendo qualcosa: a riposo
        // sarebbero un numero in più da leggere e nessuna decisione da prendere.
        if model.isHolding, let p = model.batteryPercent, !model.onAC {
            parts.append(S.batteryCharge(p))
        }
        if model.isHolding, let b = model.temp.battery {
            // Si diceva «scocca», e non lo era: quel sensore sta due gradi dal die. Adesso si
            // chiama chip, che è quello che misura, e la batteria resta il numero che decide.
            let chip = model.temp.die ?? model.temp.board
            parts.append(S.batteryTemperatures(battery: b, chip: chip))
        }
        // Il disaccordo fra ciò che l'app vuole e ciò che il sistema fa si dice, non si nasconde.
        if model.config.lidAwake && !model.lidAwakeReal { parts.append(S.lidPending) }
        if let n = model.lastNote { parts.append(n) }
        return parts.joined(separator: " · ")
    }

    /// Un selettore nostro, non un `Picker` di sistema: un controllo di serie dentro questa livrea
    /// porta i colori di qualcun altro e si vede subito.
    private var footer: some View {
        HStack {
            NSButton(title: S.quitButton, s: s) { model.releaseEverythingAndQuit() }

            NSButton(title: S.preferencesButton, s: s) {
                // Il pannello si chiude PRIMA di aprire le Preferenze, altrimenti la finestra nasce
                // dietro un pannello ancora aperto e lui non la vede (sua osservazione, 2026-08-07).
                MenuBarPanel.dismiss()
                PreferencesWindow.shared.show(model: model)
            }

            Spacer()

            Text("NoSleep")
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(Color(s.dim))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
