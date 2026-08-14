#!/usr/bin/env bun
//
// Da quindici maschere in bianco e nero al file Swift che l'app disegna.
//
// **Da dove vengono le maschere.** Da una registrazione dello schermo del cavallo di Muybridge reso
// a pallini, dalla registrazione di riferimento del 2026-08-11. Il ciclo si chiude dopo **15 pose** a **12,5 al
// secondo**: la sedicesima torna identica alla prima (RMSE 1886 contro 8000-10000 di tutte le
// altre). Le pose vivono in `Scripts/cavallo/`, perché un filmato da 5,7 MB in un repo è un peso che
// nessuno rilegge.
//
// **Come si tagliano, e questa lezione è costata un giro.** Il primo taglio era a passo fisso
// (`fps=12`) e sembrava giusto: quattordici pose, ciclo chiuso, banchi verdi. Era sbagliato. La
// sorgente non va a dodici esatti, è un'animazione di browser, e ogni posa dura 4, 5 o 6 fotogrammi
// dei 60 della registrazione: un pettine a passo fisso ne **duplica una e ne perde un'altra** a ogni
// giro. Il difetto non esiste in nessun singolo fotogramma, esiste solo nel movimento, dove si vede
// come uno scatto. L'ha visto lui, e nessuno dei miei controlli poteva vederlo.
//
// Il taglio giusto non campiona a tempo, **insegue i cambi**: si estrae a 60 al secondo, si misura
// la differenza fra fotogrammi consecutivi, ogni salto sopra il rumore apre una posa nuova, e di
// ogni posa si prende il fotogramma di mezzo.
//
//     ffmpeg -ss 0.5 -i registrazione.mov -vf fps=60 -frames:v 110 f_%03d.png
//     # i confini sono i salti: compare -metric RMSE f_N.png f_N+1.png  → sopra ~1000 è una posa nuova
//     magick f_MEZZO.png -colorspace Gray -statistic Median 3x3 -threshold 60% -negate \
//            -depth 1 Scripts/cavallo/posa-NN.png
//
// **Perché pallini e non immagini.** Le pose ridisegnate come cerchi restano nitide a qualunque
// misura, prendono il colore della livrea invece di portarne uno loro, e pesano nove righe di testo
// invece di ventotto file PNG a due risoluzioni. Nella barra dei menu, dove una cella di griglia
// vale meno di un punto, i cerchi si toccano e il cavallo diventa una sagoma: è lo stesso disegno,
// guardato da lontano.
//
// Uso: bun Scripts/horse-frames.ts [--check]
//   --check  non riscrive niente, fallisce se il file generato è diverso da quello sul disco.
//
// Serve `magick` (ImageMagick), che è una dipendenza di questo script e non dell'app.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";

const RADICE = join(import.meta.dir, "..");
const MASCHERE = join(RADICE, "Scripts", "cavallo");
const USCITA = join(RADICE, "Sources", "NoSleepCore", "Horse.swift");

/** Le dimensioni della registrazione e il passo della griglia, misurati e non stimati. */
const W = 660, H = 610, POSE = 15;
/** Passo della griglia in pixel: picco dell'autocorrelazione sulle proiezioni, 20 su entrambi gli assi. */
const PASSO = 20;
/** Quanta parte di una cella deve essere accesa perché lì ci sia un pallino. */
const SOGLIA_CELLA = 0.02;
/** I raggi si quantizzano in decimi di passo: 0 vuol dire nessun pallino, 9 il pallino pieno. */
const LIVELLI = 9;

function leggiMaschera(n: number): Uint8Array {
  const png = join(MASCHERE, `posa-${String(n).padStart(2, "0")}.png`);
  if (!existsSync(png)) throw new Error(`manca la posa ${png}`);
  const tmp = mkdtempSync(join(tmpdir(), "cavallo-"));
  try {
    const grezzo = join(tmp, "m.gray");
    execFileSync("magick", [png, "-depth", "8", `gray:${grezzo}`]);
    const dati = new Uint8Array(readFileSync(grezzo));
    if (dati.length !== W * H) throw new Error(`posa ${n}: ${dati.length} byte invece di ${W * H}`);
    return dati;
  } finally {
    rmSync(tmp, { recursive: true, force: true });
  }
}

const maschere = Array.from({ length: POSE }, (_, i) => leggiMaschera(i + 1));

/** L'unione di tutte le pose: la griglia è la stessa per tutte, e insieme sono dense. */
const unione = new Uint8Array(W * H);
for (const m of maschere) for (let i = 0; i < W * H; i++) if (m[i] > 127) unione[i] = 255;

/**
 * La fase della griglia: lo scorrimento che porta i pixel accesi il più vicino possibile al centro
 * delle celle. Sbagliarla spezza un pallino su due celle e il cavallo si sgrana.
 */
function fase(asse: "x" | "y"): number {
  let scelta = 0, minimo = Infinity;
  for (let ph = 0; ph < PASSO; ph++) {
    let s = 0;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!unione[y * W + x]) continue;
      const v = asse === "x" ? x : y;
      s += Math.abs(((((v - ph) % PASSO) + PASSO) % PASSO) - PASSO / 2);
    }
    if (s < minimo) { minimo = s; scelta = ph; }
  }
  return scelta;
}
const fx = fase("x"), fy = fase("y");

/** Quanta parte della cella è accesa, fra 0 e 1. */
function copertura(m: Uint8Array, cx: number, cy: number): number {
  let accesi = 0, totale = 0;
  for (let y = cy * PASSO + fy; y < (cy + 1) * PASSO + fy; y++) {
    if (y < 0 || y >= H) continue;
    for (let x = cx * PASSO + fx; x < (cx + 1) * PASSO + fx; x++) {
      if (x < 0 || x >= W) continue;
      totale++;
      if (m[y * W + x] > 127) accesi++;
    }
  }
  return totale ? accesi / totale : 0;
}

/**
 * Il riquadro si prende sull'**unione**, mai posa per posa: un riquadro che si stringe e si allarga
 * a ogni posa farebbe saltellare il cavallo dentro la sua cornice, che è il difetto che si nota
 * subito e non si capisce da dove venga.
 */
const colonneTot = Math.ceil(W / PASSO), righeTot = Math.ceil(H / PASSO);
let c0 = colonneTot, c1 = -1, r0 = righeTot, r1 = -1;
for (let cy = 0; cy < righeTot; cy++) for (let cx = 0; cx < colonneTot; cx++) {
  if (copertura(unione, cx, cy) <= SOGLIA_CELLA) continue;
  if (cx < c0) c0 = cx;
  if (cx > c1) c1 = cx;
  if (cy < r0) r0 = cy;
  if (cy > r1) r1 = cy;
}
const colonne = c1 - c0 + 1, righe = r1 - r0 + 1;

/**
 * Il cavaliere si toglie, e resta il cavallo (sua richiesta, 2026-08-11).
 *
 * **La regola è una sola e vale per tutte e quindici le pose**, verificata stampandole a
 * caratteri una per una: il fantino sta raccolto sul garrese, cioè sempre **nelle prime sette righe
 * e a sinistra della colonna 20**, mentre in quelle stesse righe il cavallo ci mette solo collo,
 * testa e orecchie, che stanno **dalla colonna 20 in poi**. Le due cose non si sovrappongono mai,
 * per cui non serve una maschera diversa per ogni posa.
 *
 * Il resto del fantino, gambe e stivali, sta dentro la sagoma del corpo: toglierlo non cambierebbe
 * niente di visibile e aprirebbe buchi nel cavallo.
 */
const CAVALIERE_RIGHE = 7;
const CAVALIERE_COLONNE = 20;

function senzaCavaliere(cx: number, cy: number): boolean {
  return cy - r0 < CAVALIERE_RIGHE && cx - c0 < CAVALIERE_COLONNE;
}

/** Una posa: una riga di cifre per riga di griglia, `0` dove non c'è niente. */
function quantizza(m: Uint8Array): string[] {
  const out: string[] = [];
  for (let cy = r0; cy <= r1; cy++) {
    let riga = "";
    for (let cx = c0; cx <= c1; cx++) {
      if (senzaCavaliere(cx, cy)) { riga += "0"; continue; }
      const cov = copertura(m, cx, cy);
      if (cov <= SOGLIA_CELLA) { riga += "0"; continue; }
      // area = cov * passo^2 = pi * r^2, con r in frazione di passo
      const r = Math.sqrt(cov / Math.PI);
      // Il pallino pieno di questa animazione ha raggio circa 0,45 del passo: quello è il livello 9.
      const livello = Math.max(1, Math.min(LIVELLI, Math.round((r / 0.45) * LIVELLI)));
      riga += String(livello);
    }
    out.push(riga);
  }
  return out;
}

const pose = maschere.map(quantizza);
const pallini = pose.map((p) => p.join("").split("").filter((c) => c !== "0").length);

// Il cancello della maschera, e misura **quanto ha tolto**, non quanto resta.
//
// Se un domani il riquadro si spostasse, la maschera finirebbe altrove: o non toglie niente, o si
// mangia un pezzo di cavallo. Un conteggio assoluto non distingue i due casi da una posa
// naturalmente più fitta; la differenza fra con e senza sì, ed è il fantino, che pesa fra i dieci e
// i quindici pallini in ogni posa (misurati: da 8 a 15, 165 in tutto).
const conCavaliere = maschere.map((m) => {
  let n = 0;
  for (let cy = r0; cy <= r1; cy++) for (let cx = c0; cx <= c1; cx++) {
    if (copertura(m, cx, cy) > SOGLIA_CELLA) n++;
  }
  return n;
});
for (const [i, n] of pallini.entries()) {
  const tolti = conCavaliere[i] - n;
  if (tolti < 5 || tolti > 25) {
    console.error(`✗ posa ${i + 1}: la maschera ha tolto ${tolti} pallini, fuori dall'atteso 5-25`);
    process.exit(2);
  }
}

const swift = `import Foundation

/// Il cavallo al galoppo, quindici pose di pallini.
///
/// **Generato da \`Scripts/horse-frames.ts\` — non si modifica a mano.** Le pose vengono da una
/// registrazione di riferimento, 2026-08-11: il cavallo di Muybridge reso a mezzatinta, che
/// gira a dodici pose e mezzo al secondo e chiude il ciclo dopo quindici. Le maschere in bianco e nero
/// da cui questi numeri escono vivono in \`Scripts/cavallo/\`.
///
/// **Perché nel nucleo e non nell'interfaccia.** Sono dati, non disegno: qui possono essere contati
/// da un test senza aprire una finestra, ed è così che il banco verifica che il ciclo sia chiuso e
/// che nessuna posa sia vuota.
///
/// **La cornice è la stessa per tutte le pose**, presa sull'unione: un riquadro calcolato posa per
/// posa farebbe saltellare il cavallo dentro la sua cornice a ogni fotogramma.
public enum Horse {
    /// Quante pose al secondo, misurate sulla registrazione: 15 pose in 1,2 secondi.
    public static let fps: Double = 12.5
    /// Le colonne e le righe della griglia. Il rapporto fra le due è la forma della cornice.
    public static let columns = ${colonne}
    public static let rows = ${righe}

    /// Il raggio massimo di un pallino, in frazione del passo della griglia. Misurato: i pallini
    /// pieni si toccano quasi, ed è quel «quasi» a fare la mezzatinta.
    public static let maxRadius = 0.45

    /// Una posa per elemento; dentro, una stringa per riga di griglia e una cifra per cella:
    /// \`0\` è vuoto, da \`1\` a ${LIVELLI} è il raggio in noni del massimo.
    public static let poses: [[String]] = [
${pose.map((p) => "        [\n" + p.map((r) => `            "${r}",`).join("\n") + "\n        ],").join("\n")}
    ]

    /// I pallini di una posa, come coordinate di griglia e raggio fra 0 e 1.
    ///
    /// Ricalcolati a ogni chiamata di proposito: sono ${Math.round(pallini.reduce((a, b) => a + b, 0) / POSE)} elementi in media, e una cache
    /// costerebbe più righe di quante ne risparmi.
    public static func dots(pose i: Int) -> [(x: Int, y: Int, r: Double)] {
        let posa = poses[((i % poses.count) + poses.count) % poses.count]
        var out: [(x: Int, y: Int, r: Double)] = []
        for (y, riga) in posa.enumerated() {
            for (x, c) in riga.enumerated() where c != "0" {
                let livello = Double(c.wholeNumberValue ?? 0)
                out.append((x: x, y: y, r: livello / ${LIVELLI}.0))
            }
        }
        return out
    }
}
`;

const modo = process.argv.includes("--check") ? "check" : "write";
const attuale = existsSync(USCITA) ? readFileSync(USCITA, "utf8") : "";

if (modo === "check") {
  if (attuale !== swift) {
    console.error(`✗ ${USCITA} non corrisponde alle maschere in Scripts/cavallo/. Rigenera con: bun Scripts/horse-frames.ts`);
    process.exit(1);
  }
  console.log("✓ Horse.swift corrisponde alle maschere");
  process.exit(0);
}

writeFileSync(USCITA, swift);
console.log(`✓ ${USCITA}`);
console.log(`  griglia ${colonne}×${righe}, fase ${fx}/${fy}, passo ${PASSO}px`);
console.log(`  pallini per posa: ${pallini.join(" ")}`);
