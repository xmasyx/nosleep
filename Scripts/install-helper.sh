#!/bin/bash
# Installa (o rimuove) il cane da guardia di NoSleep.
#
# Gira DA ROOT, lanciato una volta sola dall'app con `do shell script … with administrator
# privileges`. Da qui in poi il daemon vive per conto suo e la password non serve più.
#
#   install-helper.sh <uid> <percorso-richiesta>
#   install-helper.sh --remove
#
# Vive dentro il bundle, accanto all'eseguibile che installa: cercare l'helper con un percorso
# relativo a QUESTO file è ciò che rende lo script indipendente da dove è stata messa l'app.

set -euo pipefail

LABEL="app.nosleep.helper"
DEST="/Library/PrivilegedHelperTools/${LABEL}"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
LOG="/var/log/nosleep-helper.log"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

remove() {
    # `bootout` fallisce se il servizio non c'è: qui non è un errore, è lo stato voluto.
    launchctl bootout "system/${LABEL}" 2>/dev/null || true
    # Prima di sparire, il daemon deve aver rimesso il sonno a posto. Se è già morto lo facciamo
    # noi: disinstallare NoSleep non può lasciare il Mac che non dorme più.
    /usr/bin/pmset -a disablesleep 0 || true
    rm -f "$DEST" "$PLIST"
    echo "rimosso"
}

if [[ "${1:-}" == "--remove" ]]; then
    remove
    exit 0
fi

# **Niente apostrofi qui dentro.** Dentro `${var:?messaggio}` la shell ri-analizza il messaggio, e
# un apostrofo apre una quota che non si chiude più: da lì in poi bash legge il resto del file come
# stringa e muore con «unexpected EOF» a una riga a caso, decine di righe più in basso. Scritto
# `${1:?serve l'uid}`, questo script era sintatticamente rotto e falliva dopo la password
# (2026-08-07). Non è una regola sulle shell: è una regola su cosa succede quando si scrive in
# italiano dentro un costrutto che la shell ri-analizza.
UID_ALLOWED="${1:?manca uid}"
REQUEST="${2:?manca il percorso del file di richiesta}"

# L'helper sta in Contents/MacOS, questo script in Contents/Resources.
SRC="${HERE}/../MacOS/nosleep-helper"
if [[ ! -x "$SRC" ]]; then
    echo "non trovo l'helper in $SRC" >&2
    exit 3
fi

# Se c'era già una versione, si smonta prima di sovrascrivere: rimpiazzare il binario sotto un
# processo vivo è il modo di ritrovarsi due daemon che litigano sulla stessa chiave.
launchctl bootout "system/${LABEL}" 2>/dev/null || true

mkdir -p /Library/PrivilegedHelperTools
cp "$SRC" "$DEST"
chown root:wheel "$DEST"
chmod 755 "$DEST"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${DEST}</string>
        <string>--uid</string><string>${UID_ALLOWED}</string>
        <string>--request</string><string>${REQUEST}</string>
    </array>
    <key>RunAtLoad</key><true/>
    <!-- Se muore, launchd lo rimette in piedi: un cane da guardia che può morire senza essere
         rianimato non è un cane da guardia. -->
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>${LOG}</string>
    <key>StandardErrorPath</key><string>${LOG}</string>
</dict>
</plist>
PLISTEOF

chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootstrap system "$PLIST"
launchctl enable "system/${LABEL}"

echo "installato"
