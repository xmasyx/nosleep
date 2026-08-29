import Foundation
import NoSleepCore

// `nosleep` — la riga di comando delle prenotazioni.
//
// È il pezzo che gli hook di Claude Code chiamano: una sessione che comincia prende una
// prenotazione, una sessione che finisce il turno la restituisce. L'app conta e decide.
//
//   nosleep hold --id <x> [--ttl <secondi>] [--label <testo>]
//   nosleep release --id <x>
//   nosleep status [--json]
//   nosleep list

let args = CommandLine.arguments

func value(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
    exit(1)
}

let usage = S.cliUsage

guard args.count > 1 else { print(usage); exit(0) }

Paths.ensureSupport()
let store = LeaseStore(directory: Paths.leases())
let now = Date().timeIntervalSince1970

switch args[1] {
case "hold":
    guard let id = value("--id"), !id.isEmpty else { fail(S.claimNeedsID) }
    // Sei ore di default: abbastanza per un lavoro lungo, poco abbastanza perché una sessione
    // morta non tenga sveglio il Mac per un giorno intero.
    let ttl = Double(value("--ttl") ?? "") ?? 21600
    let label = value("--label") ?? id
    guard store.hold(id: id, ttl: ttl, label: label, now: now) else {
        fail(S.claimWriteFailed(Paths.leases().path))
    }
    print(S.claimHeld(id, ttl: Int(ttl), alive: store.count(now: now)))

case "release":
    guard let id = value("--id"), !id.isEmpty else { fail(S.claimNeedsID) }
    let existed = store.release(id: id)
    print(S.claimReleased(id, existed: existed, alive: store.count(now: now)))

case "status":
    let alive = store.alive(now: now)
    if args.contains("--json") {
        let payload: [String: Any] = [
            "count": alive.count,
            "ids": alive.map(\.id),
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    } else {
        switch alive.count {
        case 0: print(S.noWork)
        case 1: print(S.oneWork)
        case let n: print(S.manyWork(n))
        }
    }

case "list":
    let alive = store.alive(now: now)
    if alive.isEmpty { print(S.noLiveClaims) }
    for l in alive {
        let left = Int(l.expires - now)
        print(S.liveClaim(l.id, label: l.label, secondsLeft: left))
    }

case "-h", "--help", "help":
    print(usage)

default:
    fail("\(S.unknownCommand(args[1]))\n\n\(usage)")
}
