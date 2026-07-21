import Foundation

enum BrowserKind {
    case safari, chromium, arc, dia

    static func from(bundleID: String) -> BrowserKind? {
        switch bundleID {
        case "com.apple.Safari", "com.apple.SafariTechnologyPreview":
            return .safari
        case "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
             "com.brave.Browser", "com.brave.Browser.beta", "com.microsoft.edgemac",
             "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
             "org.chromium.Chromium":
            return .chromium
        case "company.thebrowser.Browser":
            return .arc
        case "company.thebrowser.dia":
            return .dia
        default:
            return nil
        }
    }
}

/// Captured tab identity. Mutates in place for Safari (same-tab navigation is
/// legal, so we refresh the known URL every poll).
enum TabIdentity: Equatable {
    case chromium(tabID: String, windowID: String)
    case arc(tabID: String, windowID: String)
    case safari(index: Int, lastKnownURL: String)
    case dia(uuid: String)
}

struct ScriptResult {
    let value: String?
    let errorNumber: Int?
    var ok: Bool { errorNumber == nil }
    /// -1743: user has not granted Automation (Apple Events) permission.
    var automationDenied: Bool { errorNumber == -1743 }
}

enum BrowserScripts {
    /// Wrap so a hung browser can't stall us behind the 2-minute default timeout.
    private static func wrap(_ body: String) -> String {
        "with timeout of 3 seconds\n\(body)\nend timeout"
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: Capture (at lock time)

    static func capture(bundleID: String, kind: BrowserKind) -> String {
        let id = bundleID
        switch kind {
        case .chromium, .arc:
            return wrap(#"""
            tell application id "\#(id)"
              set w to front window
              return ((id of active tab of w) as string) & "|" & ((id of w) as string)
            end tell
            """#)
        case .safari:
            // URL is `missing value` on an empty tab — concatenating that errors.
            return wrap(#"""
            tell application id "\#(id)"
              set w to front window
              set u to URL of current tab of w
              if u is missing value then set u to ""
              return ((index of current tab of w) as string) & "|" & u
            end tell
            """#)
        case .dia:
            return wrap(#"tell application id "\#(id)" to return (id of active tab of front window) as string"#)
        }
    }

    // MARK: Check (poll — return current active-tab state to compare)

    static func check(bundleID: String, kind: BrowserKind) -> String {
        // Same shape as capture; caller diffs against the stored identity.
        return capture(bundleID: bundleID, kind: kind)
    }

    // MARK: Revert (snap the active tab back)

    static func revert(bundleID: String, kind: BrowserKind, identity: TabIdentity) -> String? {
        let id = bundleID
        switch (kind, identity) {
        case let (.chromium, .chromium(tabID, windowID)):
            return wrap(#"""
            tell application id "\#(id)"
              set theTabs to tabs of window id \#(windowID)
              repeat with i from 1 to count of theTabs
                if ((id of item i of theTabs) as string) is "\#(esc(tabID))" then
                  set active tab index of window id \#(windowID) to i
                  return
                end if
              end repeat
            end tell
            """#)
        case let (.arc, .arc(tabID, _)):
            // Arc ids are strings; `tab id X` specifiers are type-fragile, so
            // match by comparing ids and select the element reference instead.
            return wrap(#"""
            tell application id "\#(id)"
              set theTabs to tabs of front window
              repeat with t in theTabs
                if ((id of t) as string) is "\#(esc(tabID))" then
                  select t
                  return
                end if
              end repeat
            end tell
            """#)
        case let (.safari, .safari(index, url)):
            return wrap(#"""
            tell application id "\#(id)"
              set w to front window
              set theTabs to tabs of w
              set n to count of theTabs
              set target to 0
              repeat with i from 1 to n
                if (URL of item i of theTabs) is "\#(esc(url))" then
                  set target to i
                  exit repeat
                end if
              end repeat
              if target is 0 then
                set target to \#(index)
                if target > n then set target to n
                if target < 1 then set target to 1
              end if
              set current tab of w to item target of theTabs
            end tell
            """#)
        case let (.dia, .dia(uuid)):
            return wrap(#"""
            tell application id "\#(id)"
              set theTabs to tabs of front window
              repeat with t in theTabs
                if ((id of t) as string) is "\#(esc(uuid))" then
                  focus t
                  return
                end if
              end repeat
            end tell
            """#)
        default:
            return nil
        }
    }

    // MARK: Runner

    /// Runs NSAppleScript and surfaces the error number. MUST be called off the
    /// event-tap thread (AppleScript can block).
    static func run(_ source: String) -> ScriptResult {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error = error {
            let num = error[NSAppleScript.errorNumber] as? Int
            return ScriptResult(value: nil, errorNumber: num ?? -1)
        }
        return ScriptResult(value: result?.stringValue, errorNumber: nil)
    }
}
