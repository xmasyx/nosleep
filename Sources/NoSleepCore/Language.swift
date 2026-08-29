import Foundation

/// Le lingue restano due per scelta: aggiungerne una qui significa anche scrivere ogni sua frase,
/// non inventare un'infrastruttura che faccia sembrare tradotta un'interfaccia ancora incompleta.
public enum Lang: String, Sendable, CaseIterable {
    case en
    case it

    /// La riga di comando e l'app ricevono segnali diversi: la prima può essere avviata con una
    /// lingua scelta dalla shell, mentre la seconda, aperta dal Finder, conosce soprattutto le
    /// preferenze di macOS. Gli ingressi arrivano dall'esterno perché questa precedenza delicata
    /// possa essere provata senza cambiare il processo che esegue i test.
    public static func detect(
        environment: [String: String],
        preferredLanguages: [String]
    ) -> Lang {
        if let value = environment["AppleLanguages"],
           let language = language(for: firstAppleLanguage(in: value)) {
            return language
        }

        for key in ["LC_ALL", "LC_MESSAGES", "LANG"] {
            if let value = environment[key],
               let language = language(for: posixLanguage(in: value)) {
                return language
            }
        }

        if let preferred = preferredLanguages.first,
           let language = language(for: preferred) {
            return language
        }

        return .en
    }

    private static func firstAppleLanguage(in value: String) -> String {
        let first = String(value.prefix { $0 != "," })
        let decoration = CharacterSet(charactersIn: "()\"'")
            .union(.whitespacesAndNewlines)
        return first.trimmingCharacters(in: decoration)
    }

    private static func posixLanguage(in value: String) -> String {
        let end = value.firstIndex { character in
            character == "." || character == "_"
        } ?? value.endIndex
        return String(value[..<end])
    }

    private static func language(for tag: String) -> Lang? {
        let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty, normalized != "c", normalized != "posix" else {
            return nil
        }
        return normalized.hasPrefix("it") ? .it : .en
    }
}

/// La lingua ambiente viene fotografata una volta sola, ma ogni task può sostituirla nel proprio
/// perimetro. Così un test non modifica memoria condivisa, non richiede ripristini e non può
/// cambiare sotto i piedi di un altro test eseguito nello stesso momento.
public enum L {
    @TaskLocal public static var current: Lang = Lang.detect(
        environment: ProcessInfo.processInfo.environment,
        preferredLanguages: Locale.preferredLanguages
    )

    /// Le etichette rendono visibile quale frase appartiene a quale lingua: con due argomenti dello
    /// stesso tipo, invertirli sarebbe altrimenti un errore perfettamente valido per il compilatore.
    public static func t(en: String, it: String) -> String {
        switch current {
        case .en: en
        case .it: it
        }
    }
}
