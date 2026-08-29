#!/usr/bin/env bash
# Impedisce che un artefatto racconti dove è stato costruito. Cercare soltanto `/Users/` non
# basta: una build fatta in `/private/tmp` passerebbe mentre conserva lo stesso identico difetto.
# La mappa di debug OSO e la radice reale della build sono i due poli che rendono il cancello
# indipendente dalla macchina che lo esegue.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "uso: Scripts/check-paths.sh <path/to/NoSleep.app> [build-root]" >&2
    exit 8
fi

APP="$1"
BUILD_ROOT="${2:-$ROOT}"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

if [[ ! -d "$MACOS" || ! -d "$RESOURCES" || -z "$BUILD_ROOT" ]]; then
    echo "✗ bundle incompleto o radice di build vuota: il controllo dei percorsi non può essere eseguito" >&2
    exit 8
fi

fail_path() {
    local file="$1"
    local path="$2"
    echo "✗ ${file}: il rilascio contiene il percorso ${path}" >&2
    exit 8
}

scan_bytes() {
    local file="$1"
    local name="$2"
    local found

    # Il match finisce al primo byte di controllo o spazio: così il messaggio mostra il percorso
    # trovato davvero, non un conteggio che costringe chi legge a fidarsi del cancello.
    found="$(LC_ALL=C grep -aoE '/Users/[^[:cntrl:][:space:]]*|/home/[^[:cntrl:][:space:]]*' "$file" \
        | head -n 1 || true)"
    if [[ -n "$found" ]]; then
        fail_path "$name" "$found"
    fi

    found="$(LC_ALL=C grep -aoF -- "$BUILD_ROOT" "$file" | head -n 1 || true)"
    if [[ -n "$found" ]]; then
        fail_path "$name" "$found"
    fi
}

count=0
while IFS= read -r -d '' bin; do
    [[ -x "$bin" ]] || continue
    name="${bin##*/}"
    nm_output=""
    if ! nm_output="$(nm -pa "$bin" 2>&1)"; then
        echo "✗ ${name}: nm non riesce a leggere l'eseguibile, quindi il controllo OSO non è affidabile" >&2
        exit 8
    fi
    oso_line="$(printf '%s\n' "$nm_output" | grep ' OSO ' | head -n 1 || true)"
    if [[ -n "$oso_line" ]]; then
        oso_path="${oso_line#* OSO }"
        fail_path "$name" "$oso_path"
    fi
    scan_bytes "$bin" "$name"
    count=$((count + 1))
done < <(find "$MACOS" -type f -print0)

# Zero eseguibili sarebbe un verde vuoto: non prova l'invariante e quindi deve fermare il rilascio.
if [[ $count -eq 0 ]]; then
    echo "✗ nessun eseguibile trovato in $MACOS: il controllo dei percorsi non ha verificato niente" >&2
    exit 8
fi

while IFS= read -r -d '' resource; do
    # `grep -I` separa i testi dagli asset binari senza affidarsi all'estensione; un file vuoto non
    # può contenere un percorso e viene ammesso senza trasformare l'assenza di match in un errore.
    if [[ -s "$resource" ]] && ! LC_ALL=C grep -Iq '' "$resource"; then
        continue
    fi
    scan_bytes "$resource" "Resources/${resource#"$RESOURCES"/}"
done < <(find "$RESOURCES" -type f -print0)

if [[ $count -eq 1 ]]; then
    echo "✓ percorsi puliti: controllato 1 eseguibile"
else
    echo "✓ percorsi puliti: controllati ${count} eseguibili"
fi
