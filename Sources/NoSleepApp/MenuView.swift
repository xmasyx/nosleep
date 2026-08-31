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
    @ObservedObject private var updater: Updater
    @Environment(\.colorScheme) private var scheme

    private var s: SurfacePalette { scheme == .dark ? Surface.sera : Surface.giorno }

    init(model: AppModel) {
        self.model = model
        _updater = ObservedObject(wrappedValue: model.updater)
    }

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


            // **Un filetto solo.** Ce n'erano due di fila, e due filetti attaccati disegnano una
            // riga più spessa e più scura delle altre quattro: nella fotografia del 31/08 quel
            // gruppo si stacca dagli altri senza che niente lo giustifichi. Un refuso di
            // impaginazione, non una scelta, e si vede solo guardando la pagina intera.
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
        .frame(minWidth: Self.minWidth, maxWidth: Self.maxWidth)
    }

    /// **I due estremi, non la larghezza.** Era `.frame(width: 340)`, cioè un numero scritto a
    /// mano: quel numero è la ragione per cui «Verifica aggiornamenti» usciva troncato e i comandi
    /// erano stati spezzati su due righe. Adesso la larghezza si **misura** dal piede
    /// (`StatusPanel.contentWidth`), e questi due valori sono soltanto il pavimento e il limite.
    ///
    /// **Oggi la misura dà 340, cioè il pavimento**, e questo va detto perché sembra un ritorno al
    /// punto di partenza e non lo è: prima 340 era una dichiarazione, adesso è un risultato. Se
    /// domani un'etichetta si allunga, il pannello cresce fino a 420 invece di tagliarla.
    ///
    /// I 340 sono il minimo perché è la misura con cui il pannello è stato disegnato e con cui
    /// ogni nota è stata riletta. Il limite superiore esiste perché un pannello della barra che si
    /// allarga senza fine smette di leggersi come un menu: **su una riga sola i tre comandi ne
    /// chiedevano 464, e lui li ha guardati e ha detto che era troppo largo** (31/08).
    static let minWidth: CGFloat = 340
    static let maxWidth: CGFloat = 420

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
    var footer: some View {
        // **Due righe, che sono la sua scelta del 30/08 rimessa al suo posto.** Il 31/08 le avevo
        // riunite in una sola: era possibile, perché la larghezza non è più un numero scritto a
        // mano, ma i tre comandi in fila chiedono **464 punti** e lui li ha guardati e ha detto
        // che è troppo. Su due righe la fila più lunga ne chiede molti meno e il pannello torna al
        // suo pavimento.
        //
        // La differenza che resta rispetto a prima del 31/08: la larghezza è **misurata**, non
        // dichiarata. Se un giorno un'etichetta si allunga, il pannello cresce invece di
        // troncarla, che era il difetto che aveva costretto a spezzare la fila.
        //
        // Il testo dello stato sta fuori dal gruppo dei comandi: è l'unica parte che può diventare
        // lunga a piacere (la riga di `brew` durante un aggiornamento) e quando lo spazio manca è
        // lui ad accorciarsi, mai un comando.
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                commands

                Spacer(minLength: 8)

                Text("NoSleep")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Color(s.dim))
                    .fixedSize()
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)

                updateStatusText
                    .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .trailing)

                updateAction
            }
        }
        .padding(.horizontal, Self.hPadding)
        .padding(.vertical, 9)
    }

    /// I due comandi della prima riga.
    ///
    /// `fixedSize` vuol dire «questa è la mia misura vera, non restringermi»: è ciò che rende la
    /// larghezza del pannello misurabile invece che dichiarata. La misura vera però si chiede a
    /// `footer`, non a questa: qui mancano lo spazio e l'etichetta «NoSleep», e sommarli a mano è
    /// riscrivere il layout in un secondo posto. La fotografia del 31/08 col piede tagliato da
    /// tutte e due le parti è costata esattamente quella somma fatta a mano.
    var commands: some View {
        HStack(spacing: 7) {
            NSButton(title: S.quitButton, s: s) { model.releaseEverythingAndQuit() }

            NSButton(title: S.preferencesButton, s: s) {
                // Il pannello si chiude PRIMA di aprire le Preferenze, altrimenti la finestra
                // nasce dietro un pannello ancora aperto e lui non la vede (sua osservazione,
                // 2026-08-07).
                MenuBarPanel.dismiss()
                PreferencesWindow.shared.show(model: model)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Il respiro orizzontale del pannello, condiviso da ogni sezione. Sta qui perché
    /// `StatusPanel` lo somma alla fila dei comandi per ricavare la larghezza.
    static let hPadding: CGFloat = 14

    /// **Il comando** degli aggiornamenti: sta nel gruppo a misura fissa, accanto agli altri due,
    /// e uno solo per volta — quando c'è qualcosa da fare (aggiorna, scarica) prende il posto di
    /// «Verifica aggiornamenti» invece di aggiungersi.
    ///
    /// Mentre l'aggiornamento gira non c'è nessun comando: l'unica cosa da mostrare è la riga di
    /// `brew`, che vive dall'altra parte.
    @ViewBuilder
    private var updateAction: some View {
        switch updater.state {
        case .idle, .upToDate, .failed:
            checkButton
        case .available(_, let action):
            switch action {
            case .upgradeAndRelaunch:
                NSButton(title: S.updatesUpgradeButton, s: s) { updater.perform(action) }
            case .openReleasePage:
                NSButton(title: S.updatesDownloadButton, s: s) { updater.perform(action) }
            }
        case .checking, .upgrading:
            EmptyView()
        }
    }

    /// **Il testo** degli aggiornamenti, cioè la parte che può allungarsi a piacere e che perciò
    /// non deve mai poter allargare il pannello: qui si accorcia, i comandi mai.
    @ViewBuilder
    private var updateStatusText: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            updateText(S.updatesChecking)
        case .upToDate(let current):
            updateText(S.updatesUpToDate(current))
        case .available(let version, _):
            updateText(S.updatesAvailable(version))
        case .upgrading(let line):
            // La coda della riga di `brew` è la parte che dice a che punto è: si taglia la testa.
            Text(line)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color(s.dim))
                .lineLimit(1)
                .truncationMode(.head)
        case .failed(let reason):
            Text(reason)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(s.dim))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var checkButton: some View {
        NSButton(title: S.checkUpdatesButton, s: s) { updater.checkNow() }
    }

    private func updateText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(Color(s.dim))
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
