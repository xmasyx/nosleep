#!/bin/zsh
# NO SLEEP — hero in stile trasmissione VHS su tubo catodico, costruita e non generata.
# Il testo esce corretto per costruzione, che è esattamente ciò che un modello sbaglia.
set -e
W=1920; H=1080
FONT="/System/Library/Fonts/Helvetica.ttc"
OUT="${1:-docs/hero-source.png}"
T=$(mktemp -d)

# --- 1. il testo, come maschera in grigio -----------------------------------
magick -size ${W}x${H} xc:black -font "$FONT" -weight 700 -pointsize 175 \
  -fill white -gravity center -kerning 18 -annotate +0+70 "NO SLEEP" "$T/t.png"

# --- 2. aberrazione cromatica: i tre canali non si sovrappongono -------------
magick "$T/t.png" -colorspace gray -roll +9+0  "$T/r.png"
magick "$T/t.png" -colorspace gray -roll +0+1  "$T/g.png"
magick "$T/t.png" -colorspace gray -roll -9+2  "$T/b.png"
magick "$T/r.png" "$T/g.png" "$T/b.png" -combine -colorspace sRGB "$T/text.png"
# un alone: il fosforo non si ferma al bordo della lettera
magick "$T/text.png" \( +clone -blur 0x22 -evaluate multiply 0.85 \) \
  -compose screen -composite "$T/text-glow.png"

# --- 3. il lampo di luce sopra il testo --------------------------------------
# nucleo + alone magenta
# La caduta è il punto: un gradiente lineare dà un disco piatto, e un disco piatto
# non è una luce, è una bandiera. `pow` la rende ripida.
magick -size 620x620 radial-gradient:white-black -evaluate pow 3.4 \
  -fill "#ff3ecb" -tint 100 -evaluate multiply 0.9 "$T/halo.png"
magick -size 620x620 xc:black -fill white -draw "circle 310,310 310,292" \
  -blur 0x30 "$T/core.png"
# la maschera che fa morire le punte prima del bordo
magick -size 620x620 radial-gradient:white-black -evaluate pow 1.8 "$T/mask.png"
magick -size 620x620 xc:black -fill white \
  -draw "rectangle 307,52 313,568" -draw "rectangle 52,307 568,313" \
  -blur 0x7 "$T/spikes.png"
magick "$T/spikes.png" "$T/mask.png" -compose multiply -composite \
  -evaluate multiply 1.5 "$T/star.png"
magick "$T/halo.png" "$T/core.png" -compose screen -composite \
  "$T/star.png" -compose screen -composite "$T/flare.png"

# schizzi di luce intorno, come il video degradato del riferimento
magick -size 620x620 xc:black -attenuate 6 +noise Poisson -colorspace gray \
  -black-threshold 92% -blur 0x1.2 -fill "#c39bff" -tint 60 "$T/speck.png"
magick "$T/flare.png" "$T/speck.png" -compose screen -composite "$T/flare2.png"

# --- 4. composizione sul nero ------------------------------------------------
magick -size ${W}x${H} xc:black \
  \( "$T/flare2.png" -geometry +650+70 \) -compose screen -composite \
  \( "$T/text-glow.png" \) -compose screen -composite \
  "$T/stage.png"

# detriti luminosi in basso, l'eco del segnale
magick "$T/stage.png" \
  \( "$T/speck.png" -resize 60% -geometry +700+760 \) -compose screen -composite \
  "$T/stage2.png"

# --- 5. errore di tracking: una banda che scivola ---------------------------
magick "$T/stage2.png" -crop ${W}x26+0+690 +repage -roll +14+0 "$T/band.png"
magick "$T/stage2.png" "$T/band.png" -geometry +0+690 -composite "$T/stage3.png"

# --- 6. scanline --------------------------------------------------------------
magick -size 4x4 xc:"#ffffff" -fill "#9a9a9a" -draw "rectangle 0,0 3,1" \
  -write mpr:scan +delete -size ${W}x${H} tile:mpr:scan "$T/scan.png"
magick "$T/stage3.png" "$T/scan.png" -compose multiply -composite "$T/stage4.png"

# --- 7. il tubo: curvatura, vignettatura, grana ------------------------------
magick "$T/stage4.png" -virtual-pixel black -distort Barrel "0.0 0.0 0.055 0.95" "$T/stage5.png"
magick -size ${W}x${H} radial-gradient:white-"#101010" -resize ${W}x${H}\! "$T/vig.png"
magick "$T/stage5.png" "$T/vig.png" -compose multiply -composite "$T/stage6.png"
# la maschera del tubo: gli angoli tondi sono la firma che dice «schermo», più della curvatura
magick -size ${W}x${H} xc:black -fill white \
  -draw "roundrectangle 6,6 $((W-7)),$((H-7)) 110,110" -blur 0x22 "$T/tube.png"
magick "$T/stage6.png" "$T/tube.png" -compose multiply -composite "$T/stage7.png"
magick "$T/stage7.png" -attenuate 0.22 +noise Gaussian -modulate 104,118,100 "$OUT"

echo "scritto: $OUT"
magick identify "$OUT"
rm -rf "$T"
