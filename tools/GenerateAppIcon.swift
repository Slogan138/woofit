// 앱 아이콘 생성기. 결과물은 Assets.xcassets 에 커밋돼 있으므로 평소에는 실행할 일이 없다.
// 아이콘을 고칠 때만 `swift tools/GenerateAppIcon.swift` 로 다시 뽑는다.
//
// 팔레트는 IWF 올림픽 20kg 원판의 파랑(#1256C4)에서 가져왔다. PRD 문서 디자인과 같은 계열이다.
// iOS 아이콘은 알파 채널이 있으면 안 되므로 noneSkipLast 로 그린다.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024

func makeContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
}

func rgb(_ r: Int, _ g: Int, _ b: Int) -> CGColor {
    CGColor(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
}

// 올림픽 원판 색에서 가져온 팔레트 (PRD 디자인과 동일 계열)
let plateBlue      = rgb(0x12, 0x56, 0xC4)
let plateBlueDeep  = rgb(0x0B, 0x3A, 0x8C)
let white          = rgb(0xFF, 0xFF, 0xFF)

func fillGradient(_ c: CGContext, _ top: CGColor, _ bottom: CGColor) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [top, bottom] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])
}

func roundRect(_ c: CGContext, _ r: CGRect, _ radius: CGFloat, _ color: CGColor) {
    c.setFillColor(color)
    c.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    c.fillPath()
}

/// 가운데 정렬 덤벨. 바를 먼저 깔고 원판을 위에 얹는다.
func dumbbell(_ c: CGContext, color: CGColor, scale: CGFloat = 1, dy: CGFloat = 0) {
    let cx = S/2, cy = S/2 + dy
    func r(_ w: CGFloat, _ h: CGFloat, _ offX: CGFloat) -> CGRect {
        CGRect(x: cx + offX*scale - w*scale/2, y: cy - h*scale/2, width: w*scale, height: h*scale)
    }
    roundRect(c, r(430, 74, 0), 30*scale, color)              // 바
    roundRect(c, r(112, 300, -170), 40*scale, color)          // 안쪽 원판
    roundRect(c, r(112, 300,  170), 40*scale, color)
    roundRect(c, r(84, 196, -272), 30*scale, color)           // 바깥 원판
    roundRect(c, r(84, 196,  272), 30*scale, color)
}

func write(_ c: CGContext, _ name: String) {
    let img = c.makeImage()!
    let url = URL(fileURLWithPath: "\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name).png")
}

// ── iOS 앱 아이콘 ────────────────────────────────────────────────────────
do {
    let c = makeContext()
    fillGradient(c, plateBlue, plateBlueDeep)
    dumbbell(c, color: white, scale: 1.0)
    write(c, "AppIcon-ios")
}

// ── 워치 앱 아이콘 ──────────────────────────────────────────────────────
// 워치 아이콘은 원형으로 잘리므로 덤벨을 줄여 원 안에 안전하게 넣는다.
do {
    let c = makeContext()
    fillGradient(c, plateBlue, plateBlueDeep)
    dumbbell(c, color: white, scale: 0.82)
    write(c, "AppIcon-watch")
}
