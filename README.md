# Lockin

A macOS menu bar app that pins you to one window. Flip the lock and the window in front of you becomes the only thing you can use. Cmd+Tab dies. Clicks on other windows die. Lock a browser and you also stay on the current tab: no new tabs, no switching, no typing a different URL. Scrolling, links, and redirects keep working, because reading is the point.

Built for focus sessions where the escape hatch is the problem.

## Install

You need macOS 14 or later and the Xcode command line tools (`xcode-select --install`). Nothing else.

```
git clone https://github.com/TequilaTejas/lockin.git
cd lockin
./build.sh
open build/Lockin.app
```

An open padlock appears in your menu bar. Click it, then click **Lock This Window**.

## Permissions

Lockin asks for two permissions through the standard macOS prompts.

**Accessibility** (required). The lock filters keyboard and mouse events and pulls focus back when another app steals it. Both mechanisms need Accessibility. macOS prompts on your first lock attempt. Grant it in System Settings › Privacy & Security › Accessibility, then reopen the menu.

**Automation** (browsers only). Tab pinning reads the active tab over Apple Events, and macOS prompts once per browser. Decline it and Lockin still locks the window; it stops policing tabs.

### Keeping the grant across rebuilds

macOS ties permission grants to the app's code signature. `build.sh` signs ad hoc by default, ad-hoc signatures change on every build, and each rebuild would send you back to System Settings. Run this once:

```
./scripts/make-signing-cert.sh
```

The script puts a self-signed "Lockin Dev" certificate in your keychain. `build.sh` finds it on later builds and your grants survive.

If System Settings shows the Accessibility toggle on while Lockin claims the permission is missing, an old signature owns that grant. Clear it and grant again:

```
tccutil reset Accessibility com.tejasdua.lockin
```

## Privacy

Everything runs on your machine. Lockin makes no network requests, ships no analytics, and writes one file: `~/Library/Application Support/Lockin/settings.json`. The Apple Events it sends to your browser read the active tab's id, index, URL, and title, and reselect a tab. It keeps none of that beyond the current lock. The source is 15 small files; read it.

## What gets blocked

Two layers enforce the lock.

An event tap swallows the escape routes before any app sees them: app switching (Cmd+Tab, Cmd+backtick), quit and close (Cmd+Q, Cmd+W), new windows, minimize, hide, Mission Control, Spaces, Launchpad, Show Desktop, Spotlight (a setting, on by default), and every click outside the locked window. When the locked app is a browser, the tap adds tab and navigation shortcuts (Cmd+T, Cmd+1 through 9, Ctrl+Tab, Cmd+L, Cmd+S, Cmd+O, Cmd+K and their variants) and kills clicks on browser chrome. The tab strip, the URL bar, and the sidebar go dead while the page itself stays interactive. On Arc and Dia, Lockin collapses an open sidebar at lock time.

A watchdog cleans up whatever the tap misses. You can still reach another window through a trackpad gesture, a notification banner, or a page that opens its own window. The watchdog snaps focus back within about 300 ms and reselects the locked tab.

Neither layer closes anything. Lockin swallows events and refocuses. Your windows and tabs stay where they were.

## Browsers

| Browser | Window lock | Tab lock |
|---|---|---|
| Safari | yes | yes |
| Chrome, Brave, Edge, Vivaldi, Opera, Chromium | yes | yes |
| Dia | yes | yes |
| Arc | yes | best effort |
| Firefox and anything unrecognized | yes | no |

Arc's AppleScript support is incomplete, so Lockin probes it at lock time. A failed probe means you get the window lock plus a note in the panel. Firefox exposes no AppleScript tab interface at all, so it gets the window lock without tab pinning.

## The timer

Pick 10, 20, 30, or 60 minutes before locking and the unlock control disappears for that long. A countdown takes its place and the menu bar shows the minutes left. A switch chooses what happens at zero: the lock releases itself, or it stays on until you unlock by hand.

## Failsafes

A tool that filters your input needs guaranteed exits. Lockin has four.

1. The menu bar stays clickable. That check runs before any other click logic, so the panel is always reachable.
2. Hold Esc for five seconds to force an unlock. The check lives inside the event tap callback itself, where no bug elsewhere in the app can starve it.
3. Kill the process (Activity Monitor, or `kill -9`) and macOS destroys the event tap with it. Input recovers the same instant.
4. A lock never survives a launch. Crash and relaunch, and you start unlocked.

The timer blocks the unlock button and only the unlock button. Esc and kill keep working while it runs; a commitment device should not outrank a safety valve. Ctrl+Cmd+Q (lock screen) and screenshot shortcuts pass through at all times.

## Claude Code + kitty (optional)

If you run [Claude Code](https://claude.com/claude-code) inside the [kitty](https://sw.kovidgoyal.net/kitty/) terminal, Lockin can make one scoped exception: when Claude needs your input mid-lock, kitty comes forward over the locked screen. Type your answer, press Return, and focus snaps back to the locked window. The exception applies to kitty and nothing else, ends after two minutes if you ignore it, and does nothing while unlocked.

Setup lives in [`examples/claude-code-kitty-hook.sh`](examples/claude-code-kitty-hook.sh): a Claude Code Notification hook that pings `lockin://kitty-input` from kitty sessions. The locked panel also has an **Answer kitty** button for triggering it by hand.

## Settings

`~/Library/Application Support/Lockin/settings.json`, created on first run:

| Key | Default | Meaning |
|---|---|---|
| `holdSeconds` | 3.0 | How long to hold the unlock ring |
| `emergencyEscEnabled` | true | The Esc-hold failsafe |
| `blockSpotlight` | true | Swallow Cmd+Space and Cmd+Option+Space while locked |
| `debounceMs` | 300 | Snap-back delay |

## Known limits

- Lockin pins one window of one app. Dialogs, sheets, and file pickers belonging to that app stay usable; its other windows do not.
- If the locked window closes itself, Lockin re-pins to the app's next window, or unlocks when none remains.
- The Esc-hold failsafe rides on macOS key repeat. If you turned key repeat off system-wide, use kill instead.
- A browser that draws a dialog inside the window's top strip (rather than as a separate sheet) can collide with the chrome click filter. File an issue with the browser and the dialog if you hit one.
- Launchers bound to keys other than Cmd+Space (Raycast, Alfred with custom hotkeys) are not blocked. The watchdog still yanks focus back from whatever they open.

## Uninstall

Quit Lockin, then:

```
rm -rf build/Lockin.app "~/Library/Application Support/Lockin"
tccutil reset Accessibility com.tejasdua.lockin
tccutil reset AppleEvents com.tejasdua.lockin
```

Delete the "Lockin Dev" certificate from Keychain Access if you created it.

## License

MIT. Icon artwork derives from [Phosphor Icons](https://phosphoricons.com), MIT licensed. See [LICENSE](LICENSE).
