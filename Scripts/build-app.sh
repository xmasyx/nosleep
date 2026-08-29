#!/bin/bash
# Costruisce NoSleep.app e la installa in /Applications.
#
# «Compilato» non vuol dire «consegnato»: la copia che lui apre è quella installata, e fermarsi a
# `dist/` è la figura già fatta due volte su Otium. La destinazione è /Applications.
#
#   NOSLEEP_SKIP_INSTALL=1 Scripts/build-app.sh   → costruisce senza toccare l'installata

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# **Il bundle di lavorazione NON sta nel progetto.** Con una copia in `dist/`, Spotlight indicizza
# due NoSleep e cercandola ne compaiono due, una in Applicazioni e una in una cartella di sviluppo:
# lui non deve scegliere fra due icone identiche. La copia intermedia vive in una cartella
# temporanea e l'unica destinazione vera è /Applications (2026-08-07, sua segnalazione).
DEST="${1:-${TMPDIR:-/tmp}/NoSleep-build}"
APP="$DEST/NoSleep.app"
VERSION="1.1.0"

cd "$ROOT"

# Il cancello che mancava: uno script di shell che finisce nel bundle viene ANALIZZATO prima di
# essere spedito. Senza, `install-helper.sh` è uscito rotto in sintassi, ha passato la firma, ed è
# fallito in faccia a lui **dopo** che aveva già digitato la password (2026-08-07). Un file di
# codice che nessuno compila va comunque controllato da qualcosa.
echo "▸ controllo la sintassi degli script…"
for s in "$ROOT"/Scripts/*.sh; do
    bash -n "$s" || { echo "✗ sintassi rotta in $s" >&2; exit 5; }
done

echo "▸ controllo l'italiano del testo che si legge…"
bash "$ROOT/Scripts/check-italian.sh"

# `Horse.swift` è generato dalle maschere in `Scripts/cavallo/`. Se le due cose divergono, l'app
# disegna un cavallo che non viene più da lì e nessun test se ne accorge, perché ciascun lato resta
# coerente con se stesso: è il file derivato che invecchia in silenzio, preso prima che invecchi.
echo "▸ controllo che il cavallo corrisponda alle sue pose…"
bun "$ROOT/Scripts/horse-frames.ts" --check

echo "▸ compilo (release)…"
swift build -c release --product NoSleepApp
swift build -c release --product nosleep-helper
swift build -c release --product nosleep

echo "▸ icona…"
mkdir -p "$ROOT/.build/icon.iconset"
# L'icona è un asset committato, non un disegno rifatto a ogni build: `Scripts/icon.sh` la rigenera
# con ImageMagick, che serve a chi la ridisegna e non a chi compila. Se manca si torna al fulmine
# disegnato in Swift, così la build non dipende da un file binario per funzionare.
if [[ -f "$ROOT/Icon/icon-1024.png" ]]; then
    cp "$ROOT/Icon/icon-1024.png" "$ROOT/.build/icon-1024.png"
else
    swift "$ROOT/Scripts/MakeIcon.swift" "$ROOT/.build/icon-1024.png" >/dev/null
fi
for size in 16 32 64 128 256 512; do
    sips -z $size $size "$ROOT/.build/icon-1024.png" \
        --out "$ROOT/.build/icon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$ROOT/.build/icon-1024.png" \
        --out "$ROOT/.build/icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ROOT/.build/icon.iconset" -o "$ROOT/.build/NoSleep.icns"

# Le icone della barra devono essere tutte della stessa larghezza, altrimenti il pannello si sposta
# di lato quando cambia stato. Il banco gira qui, così un simbolo sbagliato ferma la build.
echo "▸ banco delle icone…"
"$ROOT/.build/release/NoSleepApp" --selftest-icons

# Il cavallo: quindici pose distinte, nessuna vuota, nessuna ripetuta di fila. Una posa persa
# nella generazione non rompe niente, fa solo zoppicare il galoppo, che è il difetto che si nota e
# non si sa spiegare.
echo "▸ banco del cavallo…"
"$ROOT/.build/release/NoSleepApp" --selftest-horse

# Il limitatore termico provato end-to-end: non che la politica decida giusto, che l'app AGISCA.
echo "▸ banco del limitatore termico…"
"$ROOT/.build/release/NoSleepApp" --selftest-thermal

# La soglia di batteria, e soprattutto il suo RITORNO: molla sotto soglia e riaccende quando la
# corrente torna, perché il fronte del lavoro non ricapita mai (difetto vivo del 2026-08-30).
echo "▸ banco della soglia di batteria…"
"$ROOT/.build/release/NoSleepApp" --selftest-battery

# L'addormentamento provato end-to-end, con la sua condizione più importante: **mai** a coperchio
# alzato.
echo "▸ banco dell'addormentamento…"
"$ROOT/.build/release/NoSleepApp" --selftest-sleep

# Il coperchio che segue «tieni sveglio», provato sul cablaggio e non solo sulla regola: il difetto
# che i test puri non vedono è la regola giusta chiamata con gli argomenti sbagliati.
echo "▸ banco del coperchio che segue…"
"$ROOT/.build/release/NoSleepApp" --selftest-lidfollow

# La pulizia della tastiera, provata sull'unica cosa che conta davvero: si spegne da sola? Il polo
# del cane da guardia gira col giro principale ucciso a mano, cioè nel caso in cui la tastiera
# resterebbe bloccata. Accende la schermata nera per un paio di secondi: è voluto, è la prova.
echo "▸ banco della pulizia della tastiera…"
"$ROOT/.build/release/NoSleepApp" --selftest-wipe

# Le Preferenze provate sulla trappola che Otium ha spedito: l'icona che resta nel Dock.
echo "▸ banco delle Preferenze…"
"$ROOT/.build/release/NoSleepApp" --selftest-prefs

echo "▸ assemblo il bundle…"
mkdir -p "$DEST"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/NoSleepApp" "$APP/Contents/MacOS/NoSleep"
cp "$ROOT/.build/release/nosleep-helper" "$APP/Contents/MacOS/nosleep-helper"
# `nosleep-cli` e NON `nosleep`: il disco di questo Mac è APFS **senza distinzione fra maiuscole
# e minuscole**, quindi `MacOS/nosleep` e `MacOS/NoSleep` sono lo stesso file, e questa riga
# sovrascriveva l'app con la riga di comando. Il bundle risultava firmato, valido e lanciabile,
# e moriva stampando l'aiuto della CLI su uno stdout che nessuno guardava (2026-08-07).
cp "$ROOT/.build/release/nosleep" "$APP/Contents/MacOS/nosleep-cli"
cp "$ROOT/Scripts/install-helper.sh" "$APP/Contents/Resources/install-helper.sh"

# Il cancello che avrebbe preso il difetto qui sopra: l'eseguibile dichiarato nell'Info.plist deve
# essere byte per byte quello che ho compilato. Un confronto, non un conteggio di file.
if ! cmp -s "$ROOT/.build/release/NoSleepApp" "$APP/Contents/MacOS/NoSleep"; then
    echo "✗ l'eseguibile del bundle NON è NoSleepApp — build interrotta" >&2
    exit 4
fi
chmod +x "$APP/Contents/Resources/install-helper.sh"
cp "$ROOT/.build/NoSleep.icns" "$APP/Contents/Resources/NoSleep.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>NoSleep</string>
    <key>CFBundleDisplayName</key><string>NoSleep</string>
    <key>CFBundleExecutable</key><string>NoSleep</string>
    <key>CFBundleIdentifier</key><string>app.nosleep.mac</string>
    <key>CFBundleIconFile</key><string>NoSleep</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <!-- Vive nella barra dei menu, non nel Dock. -->
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Locale. Nessuna rete, nessuna telemetria.</string>
</dict>
</plist>
PLIST

# Identità stabile se c'è, ad-hoc altrimenti, e lo si dice invece di firmare di nascosto in un
# modo diverso da quello atteso.
IDENTITY="NoSleep Dev"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "▸ firma con identità stabile «${IDENTITY}»…"
    codesign --force --deep --sign "$IDENTITY" --timestamp=none "$APP"
elif [[ "${NOSLEEP_RELEASE:-0}" == "1" ]]; then
    # Un artefatto pubblicato NON può essere firmato ad-hoc, e il motivo non è estetico: la firma
    # ad-hoc cambia identità a ogni ricostruzione, quindi macOS tratta ogni aggiornamento come
    # un'app diversa e azzera i permessi che l'utente aveva concesso. Meglio fermarsi qui che
    # spedire uno zip che si rompe da solo al primo aggiornamento.
    echo "✗ manca l'identità stabile «${IDENTITY}»: un artefatto di rilascio non si firma ad-hoc" >&2
    echo "  creala una volta sola con Scripts/make-signing-cert.sh" >&2
    exit 6
else
    echo "▸ firma ad-hoc (per quella stabile: Scripts/make-signing-cert.sh)…"
    codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null 2>&1 \
        || echo "  (firma saltata: non blocca l'avvio in locale)"
fi

# Il pacchetto da allegare a una release. `ditto` e non `zip`: `zip` non conserva i metadati del
# bundle e la firma esce dall'altra parte rotta, cosa che si scopre solo quando qualcuno scarica.
if [[ "${NOSLEEP_RELEASE:-0}" == "1" ]]; then
    ZIP="$DEST/NoSleep-${VERSION}.zip"
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
    # Il cancello vero: la firma deve sopravvivere al giro dentro e fuori dallo zip, altrimenti
    # l'utente scarica un'app che macOS rifiuta e non lo sa nessuno fino a quel momento.
    PROVA="$DEST/prova-firma"
    rm -rf "$PROVA" && mkdir -p "$PROVA"
    ditto -x -k "$ZIP" "$PROVA"
    if ! codesign --verify --deep --strict "$PROVA/NoSleep.app"; then
        echo "✗ la firma NON sopravvive allo zip: non pubblicare questo file" >&2
        exit 7
    fi
    echo "✓ pacchetto di rilascio: $ZIP (firma verificata dopo il giro nello zip)"
    rm -rf "$PROVA"
fi

INSTALLED="/Applications/NoSleep.app"
if [[ "${NOSLEEP_SKIP_INSTALL:-0}" == "1" ]]; then
    echo "▸ installazione saltata (NOSLEEP_SKIP_INSTALL=1)"
# Le àncore nel modello non sono decorative: senza, basta un `grep` o un editor che nomina quel
# percorso per far credere che l'app sia viva, e l'installazione viene saltata in silenzio.
elif pgrep -f "^$INSTALLED/Contents/MacOS/NoSleep( |\$)" >/dev/null; then
    echo "⚠︎ NoSleep è in esecuzione da $INSTALLED — esci dall'app e rilancia questo script"
    echo "  (il bundle nuovo resta pronto in $APP)"
else
    echo "▸ installo in ${INSTALLED}…"
    rm -rf "$INSTALLED"
    ditto "$APP" "$INSTALLED"
fi

# ── La riga di comando dove gli hook la trovano ──────────────────────────────
#
# Gli hook di Claude Code girano con il PATH dell'utente, non con quello del bundle: la CLI deve
# stare su un percorso raggiungibile per nome. `~/.local/bin` è già nel suo PATH e non chiede root.
CLI_DIR="$HOME/.local/bin"
mkdir -p "$CLI_DIR"
cp "$ROOT/.build/release/nosleep" "$CLI_DIR/nosleep"
chmod +x "$CLI_DIR/nosleep"

# ── Pulizia delle copie che confondono la ricerca ────────────────────────────
#
# Una copia `.app` fuori da /Applications non sparisce cancellandola: macOS la tiene REGISTRATA in
# LaunchServices per identificatore, e la registrazione sopravvive al file. Va tolta dal registro
# per prima, altrimenti resta a produrre voci fantasma nella ricerca e avvisi al login.
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
if [[ -d "$ROOT/dist/NoSleep.app" ]]; then
    echo "▸ tolgo la vecchia copia in dist/ dal registro di macOS…"
    "$LSR" -u "$ROOT/dist/NoSleep.app" 2>/dev/null || true
    rm -rf "$ROOT/dist"
fi

echo "✓ pronto: $APP"
echo "  riga di comando: $CLI_DIR/nosleep"
echo "  installata: $INSTALLED"
echo "  apri con:   open \"$INSTALLED\""
echo "  registro:   ~/Library/Application Support/NoSleep/log.jsonl"
