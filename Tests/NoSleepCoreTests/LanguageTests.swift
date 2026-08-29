import Testing
@testable import NoSleepCore

@Suite("La lingua scelta per le parole rivolte all'utente")
struct LanguageTests {

    @Test("AppleLanguages inglese vince sulla preferenza italiana di macOS")
    func appleLanguagesEnglishWins() {
        let language = Lang.detect(
            environment: ["AppleLanguages": "(en)"],
            preferredLanguages: ["it-IT"]
        )
        #expect(language == .en)
    }

    @Test("AppleLanguages legge la prima voce italiana fra parentesi e virgolette")
    func appleLanguagesItalianList() {
        let language = Lang.detect(
            environment: ["AppleLanguages": "(\"it-IT\", \"en\")"],
            preferredLanguages: ["en-GB"]
        )
        #expect(language == .it)
    }

    @Test("AppleLanguages riconosce una singola preferenza italiana")
    func appleLanguagesItalian() {
        #expect(Lang.detect(
            environment: ["AppleLanguages": "(it-IT)"],
            preferredLanguages: []
        ) == .it)
    }

    @Test("AppleLanguages senza una preferenza lascia parlare la locale POSIX")
    func unusableAppleLanguagesFallsThrough() {
        #expect(Lang.detect(
            environment: ["AppleLanguages": "(C)", "LANG": "it_IT.UTF-8"],
            preferredLanguages: ["en-GB"]
        ) == .it)
    }

    @Test("LANG inglese vince sulla preferenza italiana di macOS")
    func langEnglishWins() {
        let language = Lang.detect(
            environment: ["LANG": "en_US.UTF-8"],
            preferredLanguages: ["it-IT"]
        )
        #expect(language == .en)
    }

    @Test("LANG riconosce la forma POSIX italiana")
    func langItalian() {
        #expect(Lang.detect(
            environment: ["LANG": "it_IT.UTF-8"],
            preferredLanguages: []
        ) == .it)
    }

    @Test("la locale C non cancella la preferenza italiana di macOS")
    func cLocaleFallsThrough() {
        #expect(Lang.detect(
            environment: ["LANG": "C.UTF-8"],
            preferredLanguages: ["it-IT"]
        ) == .it)
    }

    @Test("LC_ALL ha precedenza su LANG")
    func lcAllWins() {
        #expect(Lang.detect(
            environment: ["LC_ALL": "it_IT.UTF-8", "LANG": "en_US.UTF-8"],
            preferredLanguages: []
        ) == .it)
    }

    @Test("LC_MESSAGES viene consultata quando LC_ALL non esprime una preferenza")
    func lcMessagesAfterUnusableLCAll() {
        #expect(Lang.detect(
            environment: [
                "LC_ALL": "POSIX",
                "LC_MESSAGES": "it_IT.UTF-8",
                "LANG": "en_US.UTF-8",
            ],
            preferredLanguages: []
        ) == .it)
    }

    @Test("un valore ambiente vuoto lascia decidere macOS")
    func emptyEnvironmentValueFallsThrough() {
        #expect(Lang.detect(
            environment: ["LC_ALL": ""],
            preferredLanguages: ["it-IT"]
        ) == .it)
    }

    @Test("senza ambiente la prima preferenza italiana viene rispettata")
    func preferredItalian() {
        #expect(Lang.detect(environment: [:], preferredLanguages: ["it-IT"]) == .it)
    }

    @Test("senza ambiente la prima preferenza inglese viene rispettata")
    func preferredEnglish() {
        #expect(Lang.detect(environment: [:], preferredLanguages: ["en-GB"]) == .en)
    }

    @Test("una lingua non supportata si sbaglia verso l'inglese")
    func unsupportedLanguageFallsBackToEnglish() {
        #expect(Lang.detect(environment: [:], preferredLanguages: ["de-DE"]) == .en)
    }

    @Test("una lingua ambiente non supportata ferma la ricerca e sceglie l'inglese")
    func unsupportedEnvironmentLanguageStopsSearch() {
        #expect(Lang.detect(
            environment: ["AppleLanguages": "(de)", "LANG": "it_IT.UTF-8"],
            preferredLanguages: ["it-IT"]
        ) == .en)
    }

    @Test("senza alcun segnale la lingua di ripiego è l'inglese")
    func noSignalsFallBackToEnglish() {
        #expect(Lang.detect(environment: [:], preferredLanguages: []) == .en)
    }

    @Test("la stessa chiave produce davvero entrambi i poli")
    func realKeyUsesTaskLocalLanguage() {
        #expect(L.$current.withValue(.en) { S.noWork } == "no active work")
        #expect(L.$current.withValue(.it) { S.noWork } == "nessun lavoro attivo")
    }
}
