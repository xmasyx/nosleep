# Changelog

Dates are release dates. Versions follow [semver](https://semver.org): the minor number moves when
something new arrives, the patch number when something already there gets fixed.

## Unreleased

### Forced sleep waits for Claude Code

- The grace before a forced sleep is now **three minutes**, not thirty seconds: on 2026-08-28 at 06:54 a
  lease renewal from the Claude Code hooks arrived late, the app saw zero leases, and put the Mac to
  sleep under a running turn. Two missed 30-second renewals must not switch the Mac off.
- While a `caffeinate` process is among the holders (Claude Code runs `caffeinate -i -t 300` for every
  turn), the forced sleep **waits** on both doors, lid closed or idle. It waits, it does not give up:
  `caffeinate` expires by itself. `sharingd`, `coreaudiod` and browsers stay ignored, as before.
- The log now says **which** lease changed: `prenotazione presa <id> (<ttl> s)`, `prenotazione
  restituita <id>`, `prenotazione scaduta <id>`, computed by diffing the live set tick by tick.

## 1.1.0 — 2026-08-22

### Clean the keyboard

Pick 1, 2 or 5 minutes and the keyboard stops answering: the screen goes black, a line from a book
sits in the middle of it, and you wipe the keys without typing anything anywhere. The black is the
point — it is what makes the dust visible while you take it off.

- **It always ends on its own**, by three routes that share no code: the timer runs out, an
  independent watchdog closes it three seconds later if the timer never fired, and killing the
  process drops everything with it, because the event tap belongs to the process.
- **Two doors are left open on purpose**: `⌃⌥⌘ esc` ends it immediately, and macOS's own `⌘⌥esc` is
  deliberately not swallowed, because a force-quit panel is the last door anyone has.
- **No permission needed for the floor.** Letters, clicks and `⌘Q` are stopped by the window itself.
  The function row — brightness, volume, Dictation — goes through an event tap and therefore through
  Accessibility, which NoSleep asks for the first time you clean and never at launch. Say no and
  cleaning still works; the preferences row tells you which keys stay alive instead of pretending.
- Twenty quotes, all public-domain literature, each with its author and work.
- The display is held awake for the duration and released on exit, so the countdown and the way out
  never disappear under your hands.

### Packaging

- First release with a **downloadable app**, signed with a stable certificate (not an Apple
  Developer ID, so Gatekeeper still asks you to allow it once — the README says how). The build
  refuses to produce a release artifact signed ad-hoc, and verifies the signature survives the trip
  through the zip before the file can be published.

### Sleeping, second half (shipped 2026-08-19, never tagged until now)

- A second door to sleep: with the lid **up**, the Mac now sleeps once the work is done *and* you
  have left it alone for five minutes. It is a state re-evaluated every five seconds, not a timer.
- Forced sleep never interrupts something that is playing, and waits a minute after a wake.
- A refusal from `pmset` is written to the log instead of vanishing, so the log can never claim a
  sleep that did not happen.

## 1.0.0 — 2026-08-14

First public release. The switch is the flaw: every app of this kind asks how long the work will
take and gets it wrong in both directions. Here sleep is the default and staying awake is a claim
that expires.

- Keep the Mac awake, on battery too, in two modes: screen and activity, or activity only.
- Work with the lid closed, through a privileged helper that asks for the password once.
- Claims from the command line (`nosleep hold` / `release`), so Claude Code hooks hold the Mac awake
  for exactly as long as the work is alive.
- Two safety nets with no switch to turn them off: a root watchdog that restores sleep if the app
  dies, and a thermal limiter that drops everything when the Mac is already throttling.
- A battery floor, login item, and a menu-bar icon that tells the three states apart at a glance.
