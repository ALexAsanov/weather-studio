import AppKit
import SwiftUI

extension WeatherEffect {
    var title: String { switch self { case .snow: return "Снег"; case .rain: return "Дождь"; case .sakura: return "Сакура"; case .leaves: return "Листья"; case .fireflies: return "Светлячки"; case .starfall: return "Звездопад" } }
    var symbol: String { switch self { case .snow: return "snowflake"; case .rain: return "cloud.rain.fill"; case .sakura: return "leaf.circle.fill"; case .leaves: return "leaf.fill"; case .fireflies: return "sparkles"; case .starfall: return "star.fill" } }
    var note: String { switch self { case .snow: return "Снежинки оседают на окнах и разлетаются от курсора."; case .rain: return "Капли разбиваются о края окон. Иногда сверкает молния."; case .sakura: return "Розовые лепестки кружатся и остаются на краях окон."; case .leaves: return "Осенние листья падают, копятся и реагируют на курсор."; case .fireflies: return "Мягкие огоньки собираются возле неподвижного курсора."; case .starfall: return "Метеоры оставляют след и рассыпаются на искры." } }
    var tint: Color { switch self { case .snow: return Color(red:0.7,green:0.86,blue:1); case .rain: return .cyan; case .sakura: return .pink; case .leaves: return .orange; case .fireflies: return .mint; case .starfall: return .purple } }
}

final class StudioModel: ObservableObject {
    @Published var effect = WeatherEffect(rawValue: UserDefaults.standard.string(forKey:"effect") ?? "snow") ?? .snow { didSet { UserDefaults.standard.set(effect.rawValue,forKey:"effect"); changed?() } }
    @Published var intensity = UserDefaults.standard.object(forKey:"intensity") as? Double ?? 0.55 { didSet { UserDefaults.standard.set(intensity,forKey:"intensity") } }
    @Published var wind = UserDefaults.standard.object(forKey:"wind") as? Double ?? 0.1 { didSet { UserDefaults.standard.set(wind,forKey:"wind") } }
    @Published var speed = UserDefaults.standard.object(forKey:"speed") as? Double ?? 1.0 { didSet { UserDefaults.standard.set(speed,forKey:"speed") } }
    @Published var enabled = false { didSet { changed?() } }
    @Published var economy = UserDefaults.standard.bool(forKey:"economy") { didSet { UserDefaults.standard.set(economy,forKey:"economy") } }
    @Published var pauseFullscreen = UserDefaults.standard.object(forKey:"pauseFullscreen") as? Bool ?? true { didSet { UserDefaults.standard.set(pauseFullscreen,forKey:"pauseFullscreen") } }
    @Published var status = "Эффекты выключены"
    @Published var windowCount = 0
    @Published var sleeping = false
    @Published var windowAccess = CGPreflightScreenCaptureAccess()
    @Published var message = ""
    var changed: (() -> Void)?
    var wallpaperAction: ((Bool) -> Void)?
    var restoreAction: (() -> Void)?
    var accessAction: (() -> Void)?
}

struct StudioPanel: View {
    @ObservedObject var model: StudioModel
    @State private var page = 0
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:25) {
                HStack(spacing:10) { Image(systemName:"cloud.snow.fill").font(.system(size:28)).foregroundStyle(.mint); VStack(alignment:.leading,spacing:2) { Text("Weather").font(.system(size:22,weight:.bold)); Text("STUDIO").font(.system(size:10,weight:.semibold,design:.monospaced)).tracking(3).foregroundStyle(.secondary) } }.padding(.top,12)
                VStack(spacing:7) {
                    nav("Эффекты",icon:"sparkles",id:0)
                    nav("Обои",icon:"photo.on.rectangle.angled",id:1)
                    nav("Настройки",icon:"slider.horizontal.3",id:2)
                }
                Spacer()
                VStack(alignment:.leading,spacing:9) {
                    HStack { Circle().fill(model.enabled ? Color.mint : Color.gray).frame(width:7,height:7); Text(model.enabled ? "На рабочем столе" : "Только предпросмотр").font(.system(size:11,weight:.medium)) }
                    Text("Работает локально\nБез аккаунта и подписки").font(.system(size:11)).foregroundStyle(.secondary).lineSpacing(4)
                    Text("Версия 0.1 · Apple Silicon").font(.system(size:9)).foregroundStyle(.tertiary).padding(.top,8)
                }
            }.padding(22).frame(width:195).frame(maxHeight:.infinity).background(Color(red:0.075,green:0.09,blue:0.115))
            VStack(alignment:.leading,spacing:18) {
                HStack(alignment:.top) {
                    VStack(alignment:.leading,spacing:6) { Text(page == 0 ? "Немного погоды. Прямо на Mac." : page == 1 ? "Фон под настроение." : "Ваш ритм. Ваша погода.").font(.system(size:23,weight:.semibold)); Text(page == 0 ? "Выберите эффект и включите его поверх ваших окон." : page == 1 ? "Шесть оригинальных пейзажей, созданных для этой версии." : "Все изменения сохраняются на этом Mac.").font(.system(size:12)).foregroundStyle(.secondary) }
                    Spacer()
                    Button { model.enabled.toggle() } label: { Label(model.enabled ? "Выключить" : "Включить",systemImage:model.enabled ? "pause.fill" : "play.fill").font(.system(size:12,weight:.semibold)).padding(.horizontal,16).padding(.vertical,11).background(Color.mint).foregroundStyle(.black).cornerRadius(9) }.buttonStyle(.plain)
                }
                if page == 0 { effectsPage } else if page == 1 { wallpaperPage } else { settingsPage }
                Spacer(minLength:0)
                HStack { Text(model.status).font(.system(size:10)); Spacer(); Text("Меню приложения остается в строке меню Mac").font(.system(size:10)) }.foregroundStyle(.secondary)
            }.padding(26).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(red:0.105,green:0.12,blue:0.15))
        }.frame(minWidth:940,minHeight:650).preferredColorScheme(.dark)
    }
    func nav(_ text:String,icon:String,id:Int) -> some View { Button { page=id } label: { HStack(spacing:11) { Image(systemName:icon).frame(width:20); Text(text); Spacer() }.font(.system(size:13,weight:.medium)).padding(12).background(page == id ? Color.white.opacity(0.09) : .clear).cornerRadius(9) }.buttonStyle(.plain).foregroundStyle(page == id ? .white : .gray) }
    var effectsPage: some View {
        VStack(alignment:.leading,spacing:15) {
            PreviewRepresentable(model:model).frame(height:260).clipShape(RoundedRectangle(cornerRadius:14)).overlay(alignment:.topLeading) { Text("ПРЕДПРОСМОТР · ПЕРЕТАЩИТЕ ОКНО").font(.system(size:9,weight:.semibold,design:.monospaced)).tracking(1.2).foregroundStyle(.white.opacity(0.6)).padding(15).allowsHitTesting(false) }
            HStack(spacing:8) { ForEach(WeatherEffect.allCases,id:\.self) { effect in Button { model.effect=effect } label: { VStack(spacing:9) { Image(systemName:effect.symbol).font(.system(size:21)).foregroundStyle(effect.tint); Text(effect.title).font(.system(size:10,weight:.medium)) }.frame(maxWidth:.infinity).padding(.vertical,14).background(model.effect == effect ? effect.tint.opacity(0.13) : Color.white.opacity(0.035)).cornerRadius(10).overlay(RoundedRectangle(cornerRadius:10).stroke(model.effect == effect ? effect.tint.opacity(0.6) : Color.white.opacity(0.08),lineWidth:1)) }.buttonStyle(.plain) } }
            Text(model.effect.note).font(.system(size:12)).foregroundStyle(.secondary)
            HStack(spacing:22) { slider("Интенсивность",value:$model.intensity,range:0.2...1,caption:"\(Int(model.intensity*100))%"); slider("Ветер",value:$model.wind,range: -1...1,caption:abs(model.wind)<0.08 ? "Штиль" : model.wind > 0 ? "Вправо" : "Влево"); slider("Скорость",value:$model.speed,range:0.3...2,caption:String(format:"%.1f×",model.speed)) }
        }
    }
    func slider(_ name:String,value:Binding<Double>,range:ClosedRange<Double>,caption:String) -> some View { VStack(spacing:7) { HStack { Text(name); Spacer(); Text(caption).foregroundStyle(.secondary) }.font(.system(size:10)); Slider(value:value,in:range).tint(.mint) }.frame(maxWidth:.infinity) }
    var wallpaperPage: some View { VStack(alignment:.leading,spacing:16) {
        Image(nsImage:WallpaperRenderer.image(effect:model.effect,size:CGSize(width:1200,height:650))).resizable().aspectRatio(contentMode:.fill).frame(height:300).clipped().cornerRadius(14)
        HStack { ForEach(WeatherEffect.allCases,id:\.self) { effect in Button(effect.title) { model.effect=effect }.buttonStyle(.bordered).tint(model.effect == effect ? .mint : .gray) } }
        HStack { Button { model.wallpaperAction?(true) } label: { Text("Установить на все экраны").padding(.horizontal,12).padding(.vertical,8).background(Color.mint).foregroundStyle(.black).cornerRadius(7) }.buttonStyle(.plain); Button("Сохранить PNG…") { model.wallpaperAction?(false) }; Button("Вернуть прежние обои") { model.restoreAction?() } }
        Text("Обои изменятся только после нажатия кнопки. Прежний фон можно вернуть.").font(.system(size:11)).foregroundStyle(.secondary)
        if !model.message.isEmpty { Text(model.message).font(.system(size:11)).foregroundStyle(.mint) }
    } }
    var settingsPage: some View { VStack(alignment:.leading,spacing:22) {
        GroupBox { VStack(alignment:.leading,spacing:18) { Toggle("Экономный режим: 15 кадров в секунду",isOn:$model.economy); Toggle("Пауза поверх полноэкранных приложений",isOn:$model.pauseFullscreen); Text("При сне экрана анимация останавливается. В режиме энергосбережения macOS частота автоматически снижается.").font(.system(size:11)).foregroundStyle(.secondary) }.padding(12) }.padding(.top,12)
        GroupBox { VStack(alignment:.leading,spacing:10) { Label("Взаимодействие с окнами",systemImage:"macwindow").font(.headline); Text("Приложение использует доступные координаты окон. Содержимое экрана не записывается и никуда не отправляется.").font(.system(size:12)); Text("Последняя проверка: \(model.windowCount) видимых окон. Если macOS скрывает их границы, эффекты продолжают работать без оседания на этих окнах.").font(.system(size:11)).foregroundStyle(.secondary); if !model.windowAccess { Text("Для доступа к окнам других приложений может потребоваться разрешение macOS «Запись экрана». После его изменения перезапустите Weather Studio.").font(.system(size:11)).foregroundStyle(.secondary); Button("Настроить доступ к окнам…") { model.accessAction?() } } }.padding(12) }
        GroupBox { VStack(alignment:.leading,spacing:10) { Text("Первая рабочая версия").font(.headline); Text("Шесть эффектов, несколько мониторов, свои обои и управление из строки меню. Автозапуск, автообновление и обработка пользовательских фотографий в эту версию не входят.").font(.system(size:12)); Text("Закрытие этой панели оставляет приложение в строке меню. Для полного выхода выберите «Завершить Weather Studio».").font(.system(size:11)).foregroundStyle(.secondary) }.padding(12) }
    } }
}

final class PreviewContainer: NSView {
    let weather = WeatherView(frame:.zero)
    var model:StudioModel
    var box = CGRect(x:170,y:25,width:300,height:145)
    var lastBox = CGRect.zero
    var dragOffset:CGPoint?
    var timer:Timer?
    var lastTick=ProcessInfo.processInfo.systemUptime
    init(model:StudioModel) { self.model=model; super.init(frame:.zero); addSubview(weather); weather.autoresizingMask=[.width,.height]; timer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true) { [weak self] _ in self?.tick() } }
    required init?(coder:NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    override func layout() { super.layout(); weather.frame=bounds }
    override func hitTest(_ point:NSPoint) -> NSView? { bounds.contains(convert(point,from:superview)) ? self : nil }
    override func mouseDown(with event:NSEvent) { let p=convert(event.locationInWindow,from:nil); if box.contains(p) { dragOffset=CGPoint(x:p.x-box.minX,y:p.y-box.minY) } }
    override func mouseDragged(with event:NSEvent) { guard let d=dragOffset else{return}; let p=convert(event.locationInWindow,from:nil); box.origin=CGPoint(x:min(max(0,p.x-d.x),max(0,bounds.width-box.width)),y:min(max(0,p.y-d.y),max(0,bounds.height-box.height-30))); needsDisplay=true }
    override func mouseUp(with event:NSEvent) { dragOffset=nil }
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime
        guard window?.isVisible == true, !model.sleeping else { lastTick=now; return }
        let low=model.economy || ProcessInfo.processInfo.isLowPowerModeEnabled
        guard now-lastTick >= (low ? 1.0/16 : 1.0/34) else { return }
        let elapsed=min(now-lastTick,0.1); lastTick=now
        weather.effect=model.effect; weather.intensity=model.intensity; weather.wind=model.wind; weather.speed=model.speed; weather.running=true
        if let window { let local=convert(window.convertPoint(fromScreen:NSEvent.mouseLocation),from:nil); weather.pointer=bounds.contains(local) ? local : nil }
        let velocity = lastBox == .zero ? CGVector.zero : CGVector(dx:(box.minX-lastBox.minX)/elapsed,dy:(box.minY-lastBox.minY)/elapsed)
        weather.surfaces=[WeatherSurface(id:1,rect:box,velocity:velocity)]; lastBox=box
        weather.step(elapsed); needsDisplay=true
    }
    override func draw(_ dirtyRect:NSRect) {
        WallpaperRenderer.draw(effect:model.effect,in:bounds)
        let path=NSBezierPath(roundedRect:box,xRadius:9,yRadius:9); NSColor(calibratedRed:0.12,green:0.15,blue:0.19,alpha:0.92).setFill(); path.fill(); NSColor.white.withAlphaComponent(0.18).setStroke(); path.stroke()
        for (i,color) in [NSColor.systemRed,.systemYellow,.systemGreen].enumerated() { color.setFill(); NSBezierPath(ovalIn:CGRect(x:box.minX+14+CGFloat(i)*15,y:box.maxY-23,width:8,height:8)).fill() }
        let attrs:[NSAttributedString.Key:Any] = [.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.white.withAlphaComponent(0.75)]
        ("Ваше окно" as NSString).draw(at:CGPoint(x:box.minX+100,y:box.maxY-25),withAttributes:attrs)
        for i in 0..<3 { NSColor.white.withAlphaComponent(0.10).setFill(); NSBezierPath(roundedRect:CGRect(x:box.minX+18,y:box.minY+25+CGFloat(i)*23,width:CGFloat(150+i*25),height:7),xRadius:3,yRadius:3).fill() }
    }
}
struct PreviewRepresentable:NSViewRepresentable {
    @ObservedObject var model:StudioModel
    func makeNSView(context:Context)->PreviewContainer { PreviewContainer(model:model) }
    func updateNSView(_ view:PreviewContainer,context:Context) { view.model=model; view.weather.effect=model.effect; view.needsDisplay=true }
}

final class OverlayWindow:NSWindow { override var canBecomeKey:Bool { false }; override var canBecomeMain:Bool { false } }
final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    let model=StudioModel()
    let tracker=WindowTracker()
    var panel:NSWindow!
    var item:NSStatusItem!
    var overlays:[(NSScreen,OverlayWindow,WeatherView)]=[]
    var timer:Timer?
    var lastTime=ProcessInfo.processInfo.systemUptime
    var lastScan=0.0
    var sleeping=false
    var tickIndex=0
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        let appMenu=NSMenu(); let top=NSMenuItem(); top.submenu=NSMenu(); top.submenu?.addItem(withTitle:"Завершить Weather Studio",action:#selector(quit),keyEquivalent:"q"); appMenu.addItem(top); NSApp.mainMenu=appMenu
        panel=NSWindow(contentRect:NSRect(x:0,y:0,width:960,height:670),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        panel.title="Weather Studio"; panel.titlebarAppearsTransparent=true; panel.backgroundColor=NSColor(calibratedRed:0.105,green:0.12,blue:0.15,alpha:1); panel.contentView=NSHostingView(rootView:StudioPanel(model:model)); panel.center(); panel.isReleasedWhenClosed=false; panel.delegate=self
        item=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength); item.button?.image=NSImage(systemSymbolName:"cloud.snow",accessibilityDescription:"Weather Studio"); item.button?.image?.isTemplate=true
        model.changed = { [weak self] in self?.sync(); self?.updateMenu() }
        model.wallpaperAction = { [weak self] install in self?.wallpaper(install:install) }
        model.restoreAction = { [weak self] in self?.restoreWallpaper() }
        model.accessAction = { [weak self] in
            let granted=CGRequestScreenCaptureAccess()
            self?.model.windowAccess=granted
            if !granted, let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") { NSWorkspace.shared.open(url) }
        }
        NotificationCenter.default.addObserver(self,selector:#selector(rebuild),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(sleepDisplay),name:NSWorkspace.screensDidSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(wakeDisplay),name:NSWorkspace.screensDidWakeNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(sleepDisplay),name:NSWorkspace.willSleepNotification,object:nil)
        NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(wakeDisplay),name:NSWorkspace.didWakeNotification,object:nil)
        rebuild(); updateMenu(); showPanel()
        timer=Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.tick() }; RunLoop.main.add(timer!,forMode:.common)
    }
    @objc func showPanel() { panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    @objc func toggle() { model.enabled.toggle() }
    @objc func choose(_ sender:NSMenuItem) { if let effect=WeatherEffect(rawValue:sender.representedObject as? String ?? "") { model.effect=effect } }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func sleepDisplay() { sleeping=true; model.sleeping=true; sync() }
    @objc func wakeDisplay() { sleeping=false; model.sleeping=false; lastTime=ProcessInfo.processInfo.systemUptime; sync() }
    @objc func rebuild() {
        for (_,w,_) in overlays { w.orderOut(nil); w.close() }; overlays=[]
        for screen in NSScreen.screens {
            let w=OverlayWindow(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false,screen:screen)
            w.setFrame(screen.frame,display:false); w.isOpaque=false; w.backgroundColor = .clear; w.hasShadow=false; w.ignoresMouseEvents=true; w.level = .floating; w.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]; w.isReleasedWhenClosed=false; w.isExcludedFromWindowsMenu=true; w.sharingType = .none
            let view=WeatherView(frame:CGRect(origin:.zero,size:screen.frame.size)); w.contentView=view; overlays.append((screen,w,view))
        }; lastScan=0; sync()
    }
    func sync() { for (_,w,v) in overlays { v.effect=model.effect; v.running=model.enabled && !sleeping; if model.enabled && !sleeping { w.orderFrontRegardless() } else { w.orderOut(nil) } }; model.status=model.enabled ? (sleeping ? "Пауза: экран спит" : "Эффекты включены") : "Эффекты выключены" }
    func updateMenu() { let menu=NSMenu(); menu.addItem(withTitle:"Открыть Weather Studio",action:#selector(showPanel),keyEquivalent:""); menu.addItem(.separator()); menu.addItem(withTitle:model.enabled ? "Выключить эффекты" : "Включить эффекты",action:#selector(toggle),keyEquivalent:""); for effect in WeatherEffect.allCases { let row=NSMenuItem(title:effect.title,action:#selector(choose),keyEquivalent:""); row.representedObject=effect.rawValue; row.state=model.effect == effect ? .on : .off; menu.addItem(row) }; menu.addItem(.separator()); menu.addItem(withTitle:"Завершить Weather Studio",action:#selector(quit),keyEquivalent:"q"); for row in menu.items { row.target=self }; item.menu=menu }
    func tick() {
        let now=ProcessInfo.processInfo.systemUptime; let dt=min(now-lastTime,0.1); lastTime=now
        guard model.enabled && !sleeping else{return}
        tickIndex += 1; let low=model.economy || ProcessInfo.processInfo.isLowPowerModeEnabled
        if low && tickIndex%2 != 0 { return }
        let ids=Set(overlays.map { CGWindowID($0.1.windowNumber) }); let scan=now-lastScan>0.14; var paused=0
        for (screen,w,v) in overlays {
            if scan { v.surfaces=tracker.sample(for:screen,excluding:ids); let full=model.pauseFullscreen && tracker.isFullscreen(on:screen,excluding:ids); v.running = !full; if full { w.orderOut(nil) } else { w.orderFrontRegardless() } }
            if !v.running { paused += 1; continue }
            v.effect=model.effect; v.intensity=model.intensity; v.wind=model.wind; v.speed=model.speed; v.fps=low ? 15 : 30
            let p=NSEvent.mouseLocation; v.pointer=screen.frame.contains(p) ? CGPoint(x:p.x-screen.frame.minX,y:p.y-screen.frame.minY) : nil
            v.step(dt*(low ? 2 : 1))
        }
        if scan { lastScan=now; model.windowCount=tracker.visibleWindowCount; model.status=paused == overlays.count ? "Пауза: полноэкранное приложение" : "\(model.effect.title) · \(low ? 15 : 30) кадров/с · \(overlays.count) экран(а)" }
    }
    func wallpaper(install:Bool) {
        let image=WallpaperRenderer.image(effect:model.effect,size:CGSize(width:3840,height:2160))
        guard let tiff=image.tiffRepresentation, let bitmap=NSBitmapImageRep(data:tiff), let data=bitmap.representation(using:.png,properties:[:]) else { model.message="Не удалось создать изображение"; return }
        if !install { let save=NSSavePanel(); save.nameFieldStringValue="Weather Studio \(model.effect.title).png"; save.allowedContentTypes=[.png]; if save.runModal() == .OK, let url=save.url { do { try data.write(to:url); model.message="Обои сохранены" } catch { model.message=error.localizedDescription } }; return }
        do {
            let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Weather Studio/Wallpapers"); try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let url=directory.appendingPathComponent(model.effect.rawValue+".png"); try data.write(to:url)
            var originals=UserDefaults.standard.dictionary(forKey:"originalWallpapers") as? [String:String] ?? [:]
            for screen in NSScreen.screens { let key=String(describing:screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "main"); if originals[key] == nil, let old=NSWorkspace.shared.desktopImageURL(for:screen) { originals[key]=old.absoluteString } }
            UserDefaults.standard.set(originals,forKey:"originalWallpapers")
            for screen in NSScreen.screens { try NSWorkspace.shared.setDesktopImageURL(url,for:screen,options:[:]) }; model.message="Обои установлены. Прежний фон сохранен."
        } catch { model.message="Не удалось установить обои: \(error.localizedDescription)" }
    }
    func restoreWallpaper() {
        guard let originals=UserDefaults.standard.dictionary(forKey:"originalWallpapers") as? [String:String], !originals.isEmpty else { model.message="Сохраненных прежних обоев пока нет"; return }
        do { for screen in NSScreen.screens { let key=String(describing:screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "main"); if let value=originals[key],let url=URL(string:value) { try NSWorkspace.shared.setDesktopImageURL(url,for:screen,options:[:]) } }; model.message="Прежние обои восстановлены" } catch { model.message=error.localizedDescription }
    }
    func applicationWillTerminate(_ notification:Notification) { timer?.invalidate(); for (_,w,_) in overlays { w.orderOut(nil) } }
}

if CommandLine.arguments.contains("--self-test") {
    let app=NSApplication.shared
    var checked=0
    for effect in WeatherEffect.allCases {
        let view=WeatherView(frame:CGRect(x:0,y:0,width:800,height:500)); view.effect=effect; view.running=true; view.intensity=1
        view.surfaces=[WeatherSurface(id:1,rect:CGRect(x:200,y:100,width:350,height:180),velocity:.zero)]
        for i in 0..<360 { view.pointer=CGPoint(x:CGFloat(i%800),y:250); view.step(1.0/30); precondition(view.particleCount <= 1400, "Particle cap exceeded") }
        precondition(view.particleCount > 0,"No particles for \(effect.rawValue)")
        if [.snow,.sakura,.leaves].contains(effect) { precondition(view.settledParticleCount > 0,"Nothing settled for \(effect.rawValue)") }
        let count=view.particleCount; view.running=false; view.step(1); precondition(count == view.particleCount,"Pause changed particles")
        guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { fatalError("No bitmap") }; view.cacheDisplay(in:view.bounds,to:bitmap)
        let wallpaper=WallpaperRenderer.image(effect:effect,size:CGSize(width:800,height:500)); guard wallpaper.tiffRepresentation != nil else { fatalError("No wallpaper") }; checked += 1
    }
    let tracker=WindowTracker(); let screen=NSScreen.screens.first!; let surfaces=tracker.sample(for:screen,excluding:[])
    print("PASS: \(checked) effects, 2160 simulation frames, 6 wallpaper renders. Screens: \(NSScreen.screens.count). Visible windows: \(tracker.visibleWindowCount). Surfaces: \(surfaces.count).")
    _=app
} else {
    let app=NSApplication.shared
    let delegate=AppDelegate(); app.delegate=delegate; app.run()
}
