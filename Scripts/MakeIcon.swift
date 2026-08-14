#!/usr/bin/env swift
// Disegna l'icona di NoSleep a 1024px e la salva come PNG.
//
// Un fulmine chiaro su fondo d'inchiostro: gli stessi due colori di famiglia (Kalamos, Otium), e
// l'ambra che nell'app significa «sto tenendo sveglio il Mac».
//
//   swift Scripts/MakeIcon.swift out.png

import AppKit

let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Fondo: inchiostro, angoli morbidi come le icone di sistema.
let inset = size * 0.06
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let bg = NSBezierPath(roundedRect: rect,
                      xRadius: size * 0.22,
                      yRadius: size * 0.22)
NSColor(srgbRed: 0x14 / 255, green: 0x1A / 255, blue: 0x22 / 255, alpha: 1).setFill()
bg.fill()

// Il fulmine, in ambra.
let amber = NSColor(srgbRed: 0xE5 / 255, green: 0xB1 / 255, blue: 0x68 / 255, alpha: 1)
amber.setFill()

let bolt = NSBezierPath()
func p(_ x: Double, _ y: Double) -> NSPoint {
    NSPoint(x: size * x, y: size * y)
}
bolt.move(to: p(0.58, 0.86))
bolt.line(to: p(0.32, 0.50))
bolt.line(to: p(0.47, 0.50))
bolt.line(to: p(0.42, 0.14))
bolt.line(to: p(0.68, 0.52))
bolt.line(to: p(0.53, 0.52))
bolt.close()
bolt.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("non riesco a produrre il PNG\n".utf8))
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: out))
    print("scritto \(out)")
} catch {
    FileHandle.standardError.write(Data("scrittura fallita: \(error)\n".utf8))
    exit(1)
}
