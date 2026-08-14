#!/bin/bash
# Fa passare TUTTO il testo che l'utente legge da un cancello di stile italiano.
#
# Perché esiste: la punteggiatura italiana veniva controllata sui documenti (PDF, docx, email) e
# **non sulle stringhe di un'interfaccia**, che sono testo italiano esattamente come gli altri.
# Risultato: l'app è uscita in traduttese (2026-08-07). La regola c'era, il cancello no.
#
# Gira dentro build-app.sh, quindi non si può consegnare un bundle senza averci pensato.
#
# Il cancello è esterno e opzionale: si indica con ITALIAN_GATE, e senza quella variabile lo
# script salta e non blocca niente. Un controllo di stile che impedisce a un estraneo di
# compilare sarebbe un difetto peggiore del traduttese che previene.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STRINGS="$ROOT/Sources/NoSleepCore/Strings.swift"
GATE="${ITALIAN_GATE:-}"
TMP="$(mktemp -t nosleep-strings).md"

if [[ -z "$GATE" || ! -f "$GATE" ]]; then
    echo "▸ nessun cancello di italiano configurato (ITALIAN_GATE), salto"
    exit 0
fi

python3 - "$STRINGS" "$TMP" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
righe = []
for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', src):
    t = m.group(1)
    # Le stringhe corte sono etichette, non prosa: un titolo di due parole non ha punteggiatura
    # da giudicare, e infilarlo qui dentro diluirebbe le medie del cancello fino a farlo tacere.
    if len(t) > 12 and not t.startswith('\\('):
        righe.append('- ' + re.sub(r'\\\([a-zA-Z]+\)', 'valore', t))
testo = '# Testo di NoSleep\n\n' + '\n'.join(dict.fromkeys(righe)) + '\n'
open(sys.argv[2], 'w').write(testo)
PY

bun "$GATE" "$TMP"
