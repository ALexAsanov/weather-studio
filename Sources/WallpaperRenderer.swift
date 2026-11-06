import AppKit

enum WallpaperRenderer {
    static func palette(_ effect:WeatherEffect)->[NSColor] {
        switch effect {
        case .snow: return [color(0x101e35),color(0x426278),color(0xb9d8dd)]
        case .rain: return [color(0x0c152d),color(0x29465e),color(0x789baf)]
        case .sakura: return [color(0x35294a),color(0xa0748e),color(0xf1c2bc)]
        case .leaves: return [color(0x282c33),color(0x845b50),color(0xe6ad73)]
        case .fireflies: return [color(0x071e28),color(0x1d5555),color(0x72aa9a)]
        case .starfall: return [color(0x101329),color(0x34355c),color(0x8a79a1)]
        }
    }
    static func color(_ hex:Int)->NSColor { NSColor(calibratedRed:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1) }
    static func image(effect:WeatherEffect,size:CGSize)->NSImage { let image=NSImage(size:size); image.lockFocus(); draw(effect:effect,in:CGRect(origin:.zero,size:size)); image.unlockFocus(); return image }
    static func draw(effect:WeatherEffect,in rect:CGRect) {
        let colors=palette(effect); NSGradient(starting:colors[1],ending:colors[0])?.draw(in:rect,angle:90)
        let w=rect.width,h=rect.height
        colors[2].withAlphaComponent(0.65).setFill(); NSBezierPath(ovalIn:CGRect(x:rect.minX+w*0.75,y:rect.minY+h*0.64,width:h*0.13,height:h*0.13)).fill()
        for layer in 0..<4 {
            let path=NSBezierPath(); path.move(to:CGPoint(x:rect.minX,y:rect.minY))
            for step in 0...60 { let x=Double(step)/60; let base=0.20+Double(3-layer)*0.095; let y=base + sin(x*7+Double(layer)*1.8)*0.075 + cos(x*14+Double(layer))*0.035; path.line(to:CGPoint(x:rect.minX+CGFloat(x)*w,y:rect.minY+CGFloat(y)*h)) }
            path.line(to:CGPoint(x:rect.maxX,y:rect.minY)); path.close(); colors[0].blended(withFraction:CGFloat(3-layer)*0.12,of:colors[2])!.setFill(); path.fill()
        }
        if effect == .starfall || effect == .fireflies {
            for i in 0..<40 { let x=CGFloat((i*137+43)%997)/997; let y=CGFloat((i*83+71)%503)/503; colors[2].withAlphaComponent(CGFloat(i%5+2)/9).setFill(); let radius=effect == .starfall ? max(1,w/1700) : max(1.5,w/1000); NSBezierPath(ovalIn:CGRect(x:rect.minX+x*w,y:rect.minY+(0.40+y*0.58)*h,width:radius*2,height:radius*2)).fill() }
        }
    }
}
