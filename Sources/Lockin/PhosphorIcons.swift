import SwiftUI

/// Phosphor icons (phosphoricons.com, MIT), vendored as raw SVG path data and
/// rendered natively as SwiftUI shapes. The SPM package needs Xcode's actool
/// for its asset catalog, which this machine doesn't have — path data needs
/// nothing and stays crisp at any size.
enum Phos {
    static let lockFill = PhosIcon(d: "M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80Zm-80,84a12,12,0,1,1,12-12A12,12,0,0,1,128,164Zm32-84H96V56a32,32,0,0,1,64,0Z")
    static let lockOpenFill = PhosIcon(d: "M208,80H96V56a32,32,0,0,1,32-32c15.37,0,29.2,11,32.16,25.59a8,8,0,0,0,15.68-3.18C171.32,24.15,151.2,8,128,8A48.05,48.05,0,0,0,80,56V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80Zm-80,84a12,12,0,1,1,12-12A12,12,0,0,1,128,164Z")
    static let lockSimpleFill = PhosIcon(d: "M208,80H176V56a48,48,0,0,0-96,0V80H48A16,16,0,0,0,32,96V208a16,16,0,0,0,16,16H208a16,16,0,0,0,16-16V96A16,16,0,0,0,208,80ZM96,56a32,32,0,0,1,64,0V80H96Z")
    static let lockSimpleOpenBold = PhosIcon(d: "M208,76H100V56a28,28,0,0,1,28-28c13.51,0,25.65,9.62,28.24,22.39a12,12,0,1,0,23.52-4.78C174.87,21.5,153.1,4,128,4A52.06,52.06,0,0,0,76,56V76H48A20,20,0,0,0,28,96V208a20,20,0,0,0,20,20H208a20,20,0,0,0,20-20V96A20,20,0,0,0,208,76Zm-4,128H52V100H204Z")
    static let lockSimpleOpenFill = PhosIcon(d: "M224,96V208a16,16,0,0,1-16,16H48a16,16,0,0,1-16-16V96A16,16,0,0,1,48,80H80V56A48.05,48.05,0,0,1,128,8c23.2,0,43.32,16.15,47.84,38.41a8,8,0,0,1-15.68,3.18C157.2,35,143.37,24,128,24A32,32,0,0,0,96,56V80H208A16,16,0,0,1,224,96Z")
    static let hourglassMediumFill = PhosIcon(d: "M200,75.64V40a16,16,0,0,0-16-16H72A16,16,0,0,0,56,40V76a16.07,16.07,0,0,0,6.4,12.8L114.67,128,62.4,167.2A16.07,16.07,0,0,0,56,180v36a16,16,0,0,0,16,16H184a16,16,0,0,0,16-16V180.36a16.09,16.09,0,0,0-6.35-12.77L141.27,128l52.38-39.59A16.09,16.09,0,0,0,200,75.64ZM184,180.36V216H72V180l48-36v24a8,8,0,0,0,16,0V144.08Zm0-104.72L178.23,80H77.33L72,76V40H184Z")
    static let terminalWindow = PhosIcon(d: "M128,128a8,8,0,0,1-3,6.25l-40,32a8,8,0,1,1-10-12.5L107.19,128,75,102.25a8,8,0,1,1,10-12.5l40,32A8,8,0,0,1,128,128Zm48,24H136a8,8,0,0,0,0,16h40a8,8,0,0,0,0-16Zm56-96V200a16,16,0,0,1-16,16H40a16,16,0,0,1-16-16V56A16,16,0,0,1,40,40H216A16,16,0,0,1,232,56ZM216,200V56H40V200H216Z")
    static let warningFill = PhosIcon(d: "M236.8,188.09,149.35,36.22h0a24.76,24.76,0,0,0-42.7,0L19.2,188.09a23.51,23.51,0,0,0,0,23.72A24.35,24.35,0,0,0,40.55,224h174.9a24.35,24.35,0,0,0,21.33-12.19A23.51,23.51,0,0,0,236.8,188.09ZM120,104a8,8,0,0,1,16,0v40a8,8,0,0,1-16,0Zm8,88a12,12,0,1,1,12-12A12,12,0,0,1,128,192Z")
    static let warning = PhosIcon(d: "M236.8,188.09,149.35,36.22h0a24.76,24.76,0,0,0-42.7,0L19.2,188.09a23.51,23.51,0,0,0,0,23.72A24.35,24.35,0,0,0,40.55,224h174.9a24.35,24.35,0,0,0,21.33-12.19A23.51,23.51,0,0,0,236.8,188.09ZM222.93,203.8a8.5,8.5,0,0,1-7.48,4.2H40.55a8.5,8.5,0,0,1-7.48-4.2,7.59,7.59,0,0,1,0-7.72L120.52,44.21a8.75,8.75,0,0,1,15,0l87.45,151.87A7.59,7.59,0,0,1,222.93,203.8ZM120,144V104a8,8,0,0,1,16,0v40a8,8,0,0,1-16,0Zm20,36a12,12,0,1,1-12-12A12,12,0,0,1,140,180Z")
    static let info = PhosIcon(d: "M128,24A104,104,0,1,0,232,128,104.11,104.11,0,0,0,128,24Zm0,192a88,88,0,1,1,88-88A88.1,88.1,0,0,1,128,216Zm16-40a8,8,0,0,1-8,8,16,16,0,0,1-16-16V128a8,8,0,0,1,0-16,16,16,0,0,1,16,16v40A8,8,0,0,1,144,176ZM112,84a12,12,0,1,1,12,12A12,12,0,0,1,112,84Z")
    static let appWindow = PhosIcon(d: "M216,40H40A16,16,0,0,0,24,56V200a16,16,0,0,0,16,16H216a16,16,0,0,0,16-16V56A16,16,0,0,0,216,40Zm0,160H40V56H216V200ZM80,84A12,12,0,1,1,68,72,12,12,0,0,1,80,84Zm40,0a12,12,0,1,1-12-12A12,12,0,0,1,120,84Z")
}

struct PhosIcon: View {
    let d: String
    var tint: Color = .primary

    func color(_ c: Color) -> PhosIcon {
        var copy = self
        copy.tint = c
        return copy
    }

    var body: some View {
        PhosShape(d: d)
            .fill(tint, style: FillStyle(eoFill: false, antialiased: true))
            .aspectRatio(1, contentMode: .fit)
    }
}

struct PhosShape: Shape {
    let d: String

    func path(in rect: CGRect) -> Path {
        let base = PhosPathParser.path(for: d) // 256×256 icon space
        let scale = min(rect.width, rect.height) / 256
        let transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
        return base.applying(transform)
    }
}

/// Minimal SVG path-data parser: M L H V C S Q T A Z and their relative forms.
enum PhosPathParser {
    private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    static func path(for d: String) -> Path {
        lock.lock()
        defer { lock.unlock() }
        if let hit = cache[d] { return hit }
        let parsed = parse(d)
        cache[d] = parsed
        return parsed
    }

    private static func parse(_ d: String) -> Path {
        var p = Path()
        let chars = Array(d)
        let n = chars.count
        var i = 0
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var cmd: Character = " "
        var lastCubicCtrl: CGPoint?
        var lastQuadCtrl: CGPoint?

        func isSep(_ c: Character) -> Bool { c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" }
        func skipSep() { while i < n, isSep(chars[i]) { i += 1 } }

        func number() -> CGFloat? {
            skipSep()
            var s = ""
            if i < n, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            var seenDot = false
            while i < n {
                let c = chars[i]
                if c.isNumber { s.append(c); i += 1 }
                else if c == "." && !seenDot { seenDot = true; s.append(c); i += 1 }
                else if c == "e" || c == "E" {
                    s.append(c); i += 1
                    if i < n, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
                } else { break }
            }
            return s.isEmpty || s == "-" || s == "+" ? nil : Double(s).map { CGFloat($0) }
        }

        // Arc flags may be run together ("...0,0,196,0"): always one char.
        func flag() -> Bool? {
            skipSep()
            guard i < n, chars[i] == "0" || chars[i] == "1" else { return nil }
            let v = chars[i] == "1"
            i += 1
            return v
        }

        func pt(relative: Bool) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return relative ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
        }

        while true {
            skipSep()
            guard i < n else { break }
            if chars[i].isLetter {
                cmd = chars[i]
                i += 1
            }
            // else: implicit repetition of the previous command

            let rel = cmd.isLowercase
            switch Character(cmd.lowercased()) {
            case "m":
                guard let to = pt(relative: rel) else { return p }
                p.move(to: to); cur = to; start = to
                cmd = rel ? "l" : "L" // subsequent pairs are line-tos
                lastCubicCtrl = nil; lastQuadCtrl = nil
            case "l":
                guard let to = pt(relative: rel) else { return p }
                p.addLine(to: to); cur = to
                lastCubicCtrl = nil; lastQuadCtrl = nil
            case "h":
                guard let x = number() else { return p }
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                p.addLine(to: cur)
                lastCubicCtrl = nil; lastQuadCtrl = nil
            case "v":
                guard let y = number() else { return p }
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                p.addLine(to: cur)
                lastCubicCtrl = nil; lastQuadCtrl = nil
            case "c":
                guard let c1 = pt(relative: rel), let c2 = pt(relative: rel),
                      let to = pt(relative: rel) else { return p }
                p.addCurve(to: to, control1: c1, control2: c2)
                cur = to; lastCubicCtrl = c2; lastQuadCtrl = nil
            case "s":
                guard let c2 = pt(relative: rel), let to = pt(relative: rel) else { return p }
                let c1 = lastCubicCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                p.addCurve(to: to, control1: c1, control2: c2)
                cur = to; lastCubicCtrl = c2; lastQuadCtrl = nil
            case "q":
                guard let c1 = pt(relative: rel), let to = pt(relative: rel) else { return p }
                p.addQuadCurve(to: to, control: c1)
                cur = to; lastQuadCtrl = c1; lastCubicCtrl = nil
            case "t":
                guard let to = pt(relative: rel) else { return p }
                let c1 = lastQuadCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                p.addQuadCurve(to: to, control: c1)
                cur = to; lastQuadCtrl = c1; lastCubicCtrl = nil
            case "a":
                guard let rx = number(), let ry = number(), let rot = number(),
                      let large = flag(), let sweep = flag(),
                      let to = pt(relative: rel) else { return p }
                addArc(&p, from: cur, to: to, rx: rx, ry: ry,
                       rotationDegrees: rot, largeArc: large, sweep: sweep)
                cur = to; lastCubicCtrl = nil; lastQuadCtrl = nil
            case "z":
                p.closeSubpath()
                cur = start
                lastCubicCtrl = nil; lastQuadCtrl = nil
            default:
                return p
            }
        }
        return p
    }

    /// SVG endpoint arc → cubic segments (W3C implementation notes B.2.4).
    private static func addArc(_ p: inout Path, from: CGPoint, to: CGPoint,
                               rx rxIn: CGFloat, ry ryIn: CGFloat,
                               rotationDegrees: CGFloat, largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || from == to {
            p.addLine(to: to)
            return
        }
        let phi = rotationDegrees * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        let dx2 = (from.x - to.x) / 2, dy2 = (from.y - to.y) / 2
        let x1p = cosPhi * dx2 + sinPhi * dy2
        let y1p = -sinPhi * dx2 + cosPhi * dy2

        // Scale radii up if the endpoints can't be reached.
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s; ry *= s
        }

        let rx2 = rx * rx, ry2 = ry * ry
        let num = rx2 * ry2 - rx2 * y1p * y1p - ry2 * x1p * x1p
        let den = rx2 * y1p * y1p + ry2 * x1p * x1p
        var coef = sqrt(max(0, num / den))
        if largeArc == sweep { coef = -coef }
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * -(ry * x1p / rx)

        let cx = cosPhi * cxp - sinPhi * cyp + (from.x + to.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (from.y + to.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(min(1, max(-1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                           (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let delta = dTheta / CGFloat(segments)
        let alpha = 4.0 / 3.0 * tan(delta / 4)

        var t1 = theta1
        var p1 = from
        for _ in 0..<segments {
            let t2 = t1 + delta
            let cosT1 = cos(t1), sinT1 = sin(t1)
            let cosT2 = cos(t2), sinT2 = sin(t2)

            func onEllipse(_ cosT: CGFloat, _ sinT: CGFloat) -> CGPoint {
                CGPoint(x: cx + rx * cosPhi * cosT - ry * sinPhi * sinT,
                        y: cy + rx * sinPhi * cosT + ry * cosPhi * sinT)
            }
            func derivative(_ cosT: CGFloat, _ sinT: CGFloat) -> CGPoint {
                CGPoint(x: -rx * cosPhi * sinT - ry * sinPhi * cosT,
                        y: -rx * sinPhi * sinT + ry * cosPhi * cosT)
            }

            let p2 = onEllipse(cosT2, sinT2)
            let d1 = derivative(cosT1, sinT1)
            let d2 = derivative(cosT2, sinT2)
            let c1 = CGPoint(x: p1.x + alpha * d1.x, y: p1.y + alpha * d1.y)
            let c2 = CGPoint(x: p2.x - alpha * d2.x, y: p2.y - alpha * d2.y)
            p.addCurve(to: p2, control1: c1, control2: c2)

            t1 = t2
            p1 = p2
        }
    }
}
