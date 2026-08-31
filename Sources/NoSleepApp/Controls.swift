import SwiftUI
import NoSleepCore

extension Color {
    init(_ c: RGB) { self.init(red: c.r, green: c.g, blue: c.b) }
}

/// I comandi disegnati da noi, condivisi fra il pannello e le Preferenze.
///
/// Stanno in un file solo perché la seconda finestra non deve ridisegnarli: due interruttori
/// scritti due volte divergono al primo ritocco, e la differenza si vede solo mettendo le due
/// finestre accanto, cosa che non fa nessuno.
struct NSSwitch: View {
    let isOn: Bool
    let s: SurfacePalette
    let set: (Bool) -> Void

    /// `Toggle(.switch)` con `.tint()` disegna acceso e spento quasi uguali quando la finestra non è
    /// in primo piano, e resta solo la posizione della pallina a distinguerli: nelle fotografie tre
    /// interruttori accesi si leggevano come spenti.
    var body: some View {
        Button { set(!isOn) } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(Color(isOn ? s.accent : s.card))
                    .overlay(Capsule().stroke(Color(s.rule), lineWidth: isOn ? 0 : 1))
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(Color(isOn ? s.paper : s.dim))
                    .frame(width: 14, height: 14)
                    .padding(.horizontal, 3)
            }
            .frame(width: 34, height: 20)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .animation(.easeOut(duration: 0.12), value: isOn)
    }
}

/// Una casella di scelta: modalità, percentuali. Un controllo di sistema dentro questa livrea
/// porterebbe i colori di qualcun altro e si vedrebbe subito.
struct NSChip: View {
    let title: String
    let selected: Bool
    let s: SurfacePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundStyle(Color(selected ? s.paper : s.text))
                .padding(.vertical, 4)
                .padding(.horizontal, 9)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(selected ? s.accent : s.card)))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(s.rule), lineWidth: selected ? 0 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}

/// Una riga: il testo in una colonna, il comando in un'altra.
///
/// **Perché due colonne e non un titolo con l'interruttore appeso a destra.** Prima il titolo stava
/// in una riga con l'interruttore, e la nota sotto correva per quasi tutta la larghezza con un
/// riempimento a occhio per non finirgli sotto. Risultato: tre bordi destri diversi nella stessa
/// riga, e l'interruttore che sembrava staccato da ciò che comanda. Con due colonne il margine
/// destro del testo **è** il bordo sinistro del comando, quindi il corridoio è uno solo e nasce
/// dalla struttura invece che da un numero indovinato (sua osservazione, 2026-08-07).
struct NSRow<Trailing: View, Extra: View>: View {
    let title: String
    let note: String
    let s: SurfacePalette
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var extra: Extra

    /// **La nota passa sotto l'interruttore, non gli sta accanto** (sua richiesta del 31/08:
    /// «puoi allargare il testo delle descrizioni che vada anche sotto il toggle se c'è la giusta
    /// distanza»).
    ///
    /// Prima titolo, chip e nota stavano nella stessa colonna stretta accanto al comando, quindi
    /// la nota perdeva una cinquantina di punti che nessuno usava: «Si attiva automaticamente solo
    /// Tieni sveglio il Mac…» andava a capo tre volte con mezzo pannello vuoto alla sua destra.
    /// Adesso divide la riga con l'interruttore **solo il titolo**, che è la parte che deve stargli
    /// accanto per dire a che cosa si riferisce; la nota prende tutta la larghezza sotto.
    ///
    /// «La giusta distanza» è la parte da non sbagliare, ed è il motivo degli 8 punti al posto dei
    /// 7 di prima: la nota adesso passa sotto un comando alto 20 e non sotto un testo alto 16.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color(s.text))
                        .fixedSize(horizontal: false, vertical: true)
                    extra
                }
                Spacer(minLength: 0)
                // Un pelo più in basso del bordo del testo: l'interruttore è alto 20 e la riga del
                // titolo 16, quindi allineandoli in cima l'interruttore sembra salito.
                trailing.padding(.top, -1)
            }

            Text(note)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(s.dim))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension NSRow where Extra == EmptyView {
    init(title: String, note: String, s: SurfacePalette, @ViewBuilder trailing: () -> Trailing) {
        self.init(title: title, note: note, s: s, trailing: trailing, extra: { EmptyView() })
    }
}

/// Un bottone che **si vede** che è un bottone: prima era testo tenue e non si capiva che fosse
/// premibile. L'area cliccabile è tutto il rettangolo, non la parola.
struct NSButton: View {
    let title: String
    let s: SurfacePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(s.text))
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(s.card)))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(s.rule), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }
}
