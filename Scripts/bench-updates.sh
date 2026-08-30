#!/bin/bash
# Il riavvio vero si misura a mano sul bundle installato: dopo l'upgrade deve comparire un pid
# nuovo soltanto quando il vecchio è uscito. Questa sonda ferma il giro prima di riaprire se stessa.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BINARY="$ROOT/dist/NoSleep.app/Contents/MacOS/NoSleep"

if [[ $# -gt 0 ]]; then
    if [[ $# -ne 2 || "$1" != "--binario" ]]; then
        echo "uso: Scripts/bench-updates.sh [--binario path/to/NoSleep]" >&2
        exit 2
    fi
    BINARY="$2"
fi

if [[ ! -x "$BINARY" ]]; then
    echo "binario non eseguibile: $BINARY" >&2
    exit 2
fi

BENCH="$(mktemp -d "${TMPDIR:-/tmp}/nosleep-updates.XXXXXX")"
export BENCH
trap 'rm -rf "$BENCH"' EXIT

SHIM="$BENCH/brew"
RELEASE="$BENCH/release.json"
CASKROOM="$BENCH/Caskroom"
mkdir -p "$BENCH/not-a-git-repository" "$CASKROOM/nosleep"

cat > "$SHIM" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$BENCH/brew.log"
if [[ "${1:-}" == "--repository" ]]; then
    printf '%s\n' "$BENCH/not-a-git-repository"
    exit 0
fi
printf '%s\n' "fake Homebrew: preparo NoSleep" "fake Homebrew: aggiornamento finito"
SH
chmod +x "$SHIM"
printf '%s\n' '{"tag_name":"v9.9.9","draft":false}' > "$RELEASE"

run_probe() {
    local caskroom="$1"
    local brew="$2"
    env NOSLEEP_BREW="$brew" \
        NOSLEEP_CASKROOM="$caskroom" \
        NOSLEEP_UPDATES_API="file://$RELEASE" \
        "$BINARY" --bench-updates 2>&1
}

rm -f "$BENCH/brew.log"
brew_output="$(run_probe "$CASKROOM" "$SHIM")"
printf '%s\n' "$brew_output"
[[ -f "$BENCH/brew.log" ]]
[[ "$(grep -Fxc -- '--repository xmasyx/tap' "$BENCH/brew.log")" -eq 1 ]]
[[ "$(grep -Fxc -- 'upgrade --cask xmasyx/tap/nosleep' "$BENCH/brew.log")" -eq 1 ]]
[[ "$(wc -l < "$BENCH/brew.log" | tr -d ' ')" -eq 2 ]]

rm -f "$BENCH/brew.log"
manual_output="$(run_probe "" "$SHIM")"
printf '%s\n' "$manual_output"
[[ ! -s "$BENCH/brew.log" ]]
grep -Fq -- 'openReleasePage https://github.com/xmasyx/nosleep/releases/tag/v9.9.9' \
    <<< "$manual_output"

rm -f "$BENCH/brew.log"
missing_output="$(run_probe "$CASKROOM" /nonexistent)"
printf '%s\n' "$missing_output"
grep -Fq -- 'failed' <<< "$missing_output"
grep -Fq -- 'openReleasePage https://github.com/xmasyx/nosleep/releases/tag/v9.9.9' \
    <<< "$missing_output"

echo "✓ banco aggiornamenti: Homebrew, manuale e Homebrew assente"
