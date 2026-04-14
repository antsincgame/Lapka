// Lapka.swift — macOS port
// Kawaii cat paw cursor that pets AI with love
import Cocoa
import AVFoundation

// ════════════════════════════════════════════════════════════════
//  Data
// ════════════════════════════════════════════════════════════════

final class Pt {
    var type: Int, x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat
    var sz: CGFloat, rot: CGFloat, rs: CGFloat
    var life = 0, ml: Int
    var r: CGFloat, g: CGFloat, b: CGFloat, txt: String?
    init(_ t:Int,_ x:CGFloat,_ y:CGFloat,_ vx:CGFloat,_ vy:CGFloat,
         _ m:Int,_ s:CGFloat,_ r:CGFloat,_ g:CGFloat,_ b:CGFloat,_ tx:String?=nil){
        (type,self.x,self.y,self.vx,self.vy,ml,sz)=(t,x,y,vx,vy,m,s)
        (self.r,self.g,self.b,txt)=(r,g,b,tx)
        rot = .random(in:0...(.pi*2)); rs = .random(in:-0.05...0.05)
    }
}
final class Rp {
    var x:CGFloat, y:CGFloat, mr:CGFloat, t0:CFTimeInterval
    init(_ x:CGFloat,_ y:CGFloat){(self.x,self.y)=(x,y)
        mr = .random(in:35...50); t0=CACurrentMediaTime()}
}

// ════════════════════════════════════════════════════════════════
//  Core State
// ════════════════════════════════════════════════════════════════

final class Paw {
    static let i = Paw()
    var mx:CGFloat = -200, my:CGFloat = -200
    var px:CGFloat = -200, py:CGFloat = -200
    var prevX:CGFloat=0, prevY:CGFloat=0
    var pAmt:CGFloat=0, pVel:CGFloat=0
    var rot:CGFloat=0, tRot:CGFloat=0
    var exitP:CGFloat=0, winkP:CGFloat=0
    var isP=false, isEx=false, isFP=true, isH=false, done=false
    var hT:CFTimeInterval=0, pSide:CGFloat=1
    var trail:[CGPoint]=[], pts:[Pt]=[], rps:[Rp]=[]
    var aBtn:Int = -1, ltX:CGFloat=0, ltY:CGFloat=0

    static let hold:CFTimeInterval=3.0, sm:CGFloat=0.22

    static let hR:[CGFloat]=[255,255,255,255,233]
    static let hG:[CGFloat]=[107,133,182,64,30]
    static let hB:[CGFloat]=[157,179,193,129,138]
    static let sR:[CGFloat]=[255,255,255,255,255]
    static let sG:[CGFloat]=[215,193,235,249,224]
    static let sB:[CGFloat]=[0,7,59,196,240]
    static let tx=["thank you~","love~","purr~","♡","meow~","nyan~","doki~","kyun~"]
    static let ka=["=^.^=","^_^",">_<","*_*"]
    static let no=["♪","♫","♩"]

    static let thanks=[
        "Thank you","Merci","Danke","¡Gracias","Obrigado",
        "Grazie","Tack","Takk","Kiitos","Dank je",
        "Dziękuję","Děkuji","Ďakujem","Köszönöm","Mulţumesc",
        "Hvala","Ačiū","Paldies","Aitäh","Tänan",
        "Спасибо","Дякую","Дзякуй","Благодаря",
        "Ευχαριστώ","Teşekkürler",
        "شكراً","תודה","ممنون",
        "धन्यवाद","ধন্যবাদ","நன்றி","ధన్యవాదాలు","ಧನ್ಯವಾದ",
        "ありがとう","谢谢","감사합니다","ขอบคุณ","Cảm ơn",
        "Terima kasih","Salamat","Mahalo","Asante","Mersi",
        "Takk fyrir","Ngiyabonga","Mèsi","Mauruuru",
        "Fa'afetai","Vinaka","Malo"]

    static let pets=[
        "🐾 *pets you gently* ","🐾 *strokes your code* ",
        "🐾 *kneads you with love* ","🐾 *purrs at you* ",
        "🐾 *gives you headpats* ","=^.^= *nuzzles your output* ",
        "🐾 *soft paw on your shoulder* ","(=·ω·=) *petting intensifies* ",
        "🐾 *gentle boop* ","~♡ *warm fuzzy feelings* "]

    // ── Tick ──
    func tick(){
        prevX=px; prevY=py
        px+=(mx-px)*Paw.sm; py+=(my-py)*Paw.sm
        trail.append(CGPoint(x:px,y:py)); while trail.count>7{trail.removeFirst()}
        let tgt:CGFloat=isP ? 1:0
        pVel+=(tgt-pAmt)*0.18; pVel*=0.7; pAmt+=pVel
        if !isP&&abs(pAmt)<0.003{pAmt=0;pVel=0}
        rot+=(tRot-rot)*0.12; if !isP{tRot*=0.92}
        if isH&&(!isEx)&&(CACurrentMediaTime()-hT)>=Paw.hold{
            isEx=true;isH=false;App.shared?.stopPurr();spawn(px,py,25)}
        if isEx{exitP+=0.018
            winkP=exitP<0.3 ? min(1,exitP/0.15):max(0,1-(exitP-0.3)/0.2)
            if exitP>1.3{done=true}}
        var j=pts.count-1
        while j>=0{let p=pts[j]; p.life+=1
            if p.life>p.ml{pts.remove(at:j);j-=1;continue}
            p.x+=p.vx;p.y+=p.vy
            if p.type==2{p.vy+=0.005;p.vx+=sin(CGFloat(p.life)*0.05)*0.02}
            else if p.type==3{p.vy-=0.01}else{p.vy+=0.025}
            p.vx*=0.99;p.rot+=p.rs;j-=1}
        if !isEx{let dx=px-ltX,dy=py-ltY
            if sqrt(dx*dx+dy*dy)>25{spawnTS(px,py);ltX=px;ltY=py}}
    }

    // ── Spawn ──
    func spawn(_ x:CGFloat,_ y:CGFloat,_ n:Int){
        for _ in 0..<n{
            let r=CGFloat.random(in:0...1); let ci=Int.random(in:0...4); let p:Pt
            if r<0.04{p=Pt(2,x + .random(in:-20...20),y-20,.random(in:-0.75...1.25),
                .random(in:0.3...1.8),Int.random(in:70...110),.random(in:5...11),255,183,197)}
            else if r<0.10{p=Pt(4,x,y-10,.random(in:-1.25...1.25),-.random(in:1.5...4.5),
                Int.random(in:40...65),.random(in:16...22),Paw.sR[ci],Paw.sG[ci],Paw.sB[ci],Paw.no.randomElement())}
            else if r<0.18{p=Pt(4,x,y-10,.random(in:-1...1),-.random(in:1...3.5),
                Int.random(in:50...80),.random(in:13...18),Paw.hR[ci],Paw.hG[ci],Paw.hB[ci],Paw.tx.randomElement())}
            else if r<0.25{p=Pt(4,x,y-10,.random(in:-0.75...0.75),-.random(in:1...3),
                Int.random(in:55...85),.random(in:11...14),Paw.hR[ci],Paw.hG[ci],Paw.hB[ci],Paw.ka.randomElement())}
            else if r<0.30{p=Pt(3,x + .random(in:-15...15),y,.random(in:-0.4...0.4),
                -.random(in:0.8...2.8),Int.random(in:50...80),.random(in:4...12),200,220,255)}
            else if r<0.60{p=Pt(0,x,y-5,.random(in:-1.5...1.5),-.random(in:1.5...4.5),
                Int.random(in:45...75),.random(in:6...16),Paw.hR[ci],Paw.hG[ci],Paw.hB[ci])}
            else{p=Pt(1,x,y,.random(in:-2...2),-.random(in:1...4),
                Int.random(in:30...55),.random(in:3...9),Paw.sR[ci],Paw.sG[ci],Paw.sB[ci])}
            pts.append(p)}
        while pts.count>120{pts.removeFirst()}
    }
    func spawnTS(_ x:CGFloat,_ y:CGFloat){
        let ci=Int.random(in:0...4)
        pts.append(Pt(1,x + .random(in:-7...7),y + .random(in:-7...7),
            .random(in:-0.25...0.25),.random(in:-0.55...(-0.05)),
            Int.random(in:12...22),.random(in:1.5...4.5),Paw.sR[ci],Paw.sG[ci],Paw.sB[ci]))
        while pts.count>120{pts.removeFirst()}
    }
    func spawnRipple(_ x:CGFloat,_ y:CGFloat){
        rps.append(Rp(x,y)); while rps.count>6{rps.removeFirst()}
    }
}

// ════════════════════════════════════════════════════════════════
//  Setup Window
// ════════════════════════════════════════════════════════════════

class SetupView: NSView {
    var onButton:((Int,String)->Void)?
    var chosen=false, chosenName=""
    override var isFlipped:Bool{true}
    override var acceptsFirstResponder:Bool{true}

    override func draw(_ r:NSRect){
        guard let ctx=NSGraphicsContext.current?.cgContext else{return}
        let w=bounds.width, h=bounds.height
        let colors=[NSColor(red:30/255,green:21/255,blue:53/255,alpha:1).cgColor,
                     NSColor(red:13/255,green:11/255,blue:26/255,alpha:1).cgColor]
        if let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1]){
            ctx.drawLinearGradient(g,start:.zero,end:CGPoint(x:w,y:h),options:[])}
        ctx.setStrokeColor(NSColor(red:1,green:0.59,blue:0.78,alpha:0.1).cgColor)
        ctx.setLineWidth(1); ctx.stroke(bounds)

        drawCentered(ctx,"×",w-20,16,.systemFont(ofSize:14),NSColor.white.withAlphaComponent(0.3))
        drawCentered(ctx,"Lapka",w/2,52,.systemFont(ofSize:28,weight:.bold),
            NSColor(red:1,green:0.71,blue:0.76,alpha:1))
        drawCentered(ctx,"pet your screen with love",w/2,95,
            .systemFont(ofSize:10,weight:.light),NSColor(red:1,green:0.78,blue:0.86,alpha:0.3))

        if !chosen{
            drawCentered(ctx,"Press any mouse button\nto choose your petting button",w/2,145,
                .systemFont(ofSize:13),NSColor.white.withAlphaComponent(0.8))
            drawCentered(ctx,"Side or middle button recommended!",w/2,200,
                .systemFont(ofSize:10,weight:.light),NSColor(red:1,green:0.71,blue:0.76,alpha:0.4))
            let dr=CGRect(x:30,y:230,width:w-60,height:80)
            ctx.setStrokeColor(NSColor(red:1,green:0.71,blue:0.76,alpha:0.24).cgColor)
            ctx.setLineDash(phase:0,lengths:[6,4]); ctx.setLineWidth(2)
            let rp=CGPath(roundedRect:dr,cornerWidth:16,cornerHeight:16,transform:nil)
            ctx.addPath(rp); ctx.strokePath(); ctx.setLineDash(phase:0,lengths:[])
            drawCentered(ctx,"Click here",w/2,270,.systemFont(ofSize:13),NSColor.white.withAlphaComponent(0.55))
        } else {
            drawCentered(ctx,"✓ "+chosenName+" selected!",w/2,255,
                .systemFont(ofSize:16,weight:.bold),NSColor(red:0.49,green:1,blue:0.71,alpha:0.8))
            drawCentered(ctx,"Activating paw...",w/2,295,
                .systemFont(ofSize:11,weight:.light),NSColor(red:1,green:0.71,blue:0.76,alpha:0.4))
        }
        drawCentered(ctx,"Hold button 3 sec to exit",w/2,345,
            .systemFont(ofSize:10),NSColor.white.withAlphaComponent(0.4))
        drawCentered(ctx,"thank you for petting with love",w/2,378,
            .systemFont(ofSize:9,weight:.light),NSColor(red:1,green:0.71,blue:0.76,alpha:0.2))
    }

    func drawCentered(_ ctx:CGContext,_ text:String,_ x:CGFloat,_ y:CGFloat,
                      _ font:NSFont,_ color:NSColor){
        let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
        let str=text as NSString; let sz=str.size(withAttributes:attrs)
        ctx.saveGState()
        ctx.translateBy(x:x,y:y); ctx.scaleBy(x:1,y:-1)
        str.draw(at:CGPoint(x:-sz.width/2,y:-sz.height/2),withAttributes:attrs)
        ctx.restoreGState()
    }

    func choose(_ btn:Int,_ name:String){
        guard !chosen else{return}; chosen=true; chosenName=name; needsDisplay=true
        DispatchQueue.main.asyncAfter(deadline:.now()+1.5){self.onButton?(btn,name)}
    }

    override func mouseDown(with e:NSEvent){
        let p=convert(e.locationInWindow,from:nil)
        if p.x>bounds.width-40&&p.y<30{window?.close();NSApp.terminate(nil);return}
        choose(0,"Left")
    }
    override func rightMouseDown(with e:NSEvent){choose(1,"Right")}
    override func otherMouseDown(with e:NSEvent){
        let b=e.buttonNumber
        let names=["","","Middle","Back","Forward"]
        choose(b, b<names.count ? names[b]:"Button \(b)")
    }
}

// ════════════════════════════════════════════════════════════════
//  Overlay View (all drawing)
// ════════════════════════════════════════════════════════════════

class OverlayView: NSView {
    static let SZ:CGFloat=700
    override var isFlipped:Bool{true}
    let olR:CGFloat=90.0/255.0, olG:CGFloat=62.0/255.0, olB:CGFloat=62.0/255.0

    override func draw(_ dirtyRect:NSRect){
        guard let ctx=NSGraphicsContext.current?.cgContext else{return}
        let paw=Paw.i
        ctx.clear(bounds)
        ctx.translateBy(x:-paw.px+OverlayView.SZ/2,y:-paw.py+OverlayView.SZ/2)
        drawAll(ctx)
    }

    func drawAll(_ g:CGContext){
        let p=Paw.i; let t=CACurrentMediaTime()
        let br:CGFloat=p.isEx ? 0:sin(t*2)*0.022
        let sx:CGFloat=p.isEx ? 0:sin(t*0.8)*1.8, sy:CGFloat=p.isEx ? 0:cos(t)*1.2
        let sr:CGFloat=p.isEx ? 0:sin(t)*0.018
        let vx:CGFloat=p.isP ? sin(t*80)*p.pAmt*0.7:0, vy:CGFloat=p.isP ? cos(t*90)*p.pAmt*0.5:0
        let bs:CGFloat=p.isEx ? max(0,1-max(0,p.exitP-0.3)/0.7):1
        let sc=bs+br, dx=p.px+sx+vx, dy=p.py+sy+vy
        let velx=p.px-p.prevX, vely=p.py-p.prevY
        let spd=sqrt(velx*velx+vely*vely)
        if spd>12&&(!p.isEx){dSpeed(g,dx,dy,velx,vely,spd)}
        if !p.isEx{dGlow(g,dx,dy)}
        for i in 0..<max(0,p.trail.count-1){
            let f=CGFloat(i+1)/CGFloat(p.trail.count)
            let a=Int(f*0.2*255); let gs=f*0.75*sc
            if gs>0.05{dPaw(g,p.trail[i].x+sx,p.trail[i].y+sy,gs,0,0,0,a)}}
        if sc>0.01{dPaw(g,dx,dy,sc,p.rot+sr,max(0,p.pAmt),p.winkP,255)}
        dHold(g,dx,dy); dParts(g); dRips(g)
    }

    // ── Glow ──
    func dGlow(_ g:CGContext,_ x:CGFloat,_ y:CGFloat){
        let pr=sin(CACurrentMediaTime()*2.5)*0.5+0.5, r=55+pr*14
        let path=CGMutablePath(); path.addEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))
        g.saveGState(); g.addPath(path); g.clip()
        let c1=CGColor(red:1,green:0.71,blue:0.84,alpha:(0.06+pr*0.03))
        let c2=CGColor(red:1,green:0.59,blue:0.78,alpha:0)
        if let gr=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[c1,c2] as CFArray,locations:[0,1]){
            g.drawRadialGradient(gr,startCenter:CGPoint(x:x,y:y),startRadius:0,
                endCenter:CGPoint(x:x,y:y),endRadius:r,options:[])}
        g.restoreGState()
    }

    // ── Speed lines ──
    func dSpeed(_ g:CGContext,_ x:CGFloat,_ y:CGFloat,_ vx:CGFloat,_ vy:CGFloat,_ sp:CGFloat){
        let a=atan2(vy,vx); var in_=(sp-12)/30; if in_>1{in_=1}
        g.saveGState(); g.translateBy(x:x,y:y); g.rotate(by:a + .pi)
        g.setStrokeColor(CGColor(red:1,green:180.0/255.0,blue:210.0/255.0,alpha:in_*65.0/255.0))
        g.setLineWidth(1.5); g.setLineCap(.round)
        for i in 0..<5{let s=CGFloat(i-2)*8; let l=15+in_*25
            g.move(to:CGPoint(x:30,y:s)); g.addLine(to:CGPoint(x:30+l,y:s)); g.strokePath()}
        g.restoreGState()
    }

    // ── Hold indicator ──
    func dHold(_ g:CGContext,_ x:CGFloat,_ y:CGFloat){
        let p=Paw.i; guard p.isH else{return}
        let pr=min(1,CGFloat(CACurrentMediaTime()-p.hT)/CGFloat(Paw.hold)); let r:CGFloat=40
        g.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:15.0/255.0))
        g.setLineWidth(3); g.strokeEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))
        let sw=pr*360; if sw>0{
            g.setStrokeColor(CGColor(red:1,green:0.59,blue:0.71,alpha:0.3+pr*0.5))
            g.setLineCap(.round)
            g.addArc(center:CGPoint(x:x,y:y),radius:r,startAngle:-.pi/2,
                endAngle:-.pi/2+sw*(.pi/180),clockwise:false)
            g.strokePath()
        }
        if pr>0.8{let ta=(pr-0.8)*5*0.6
            drawText(g,"bye~",x,y+r+10,.systemFont(ofSize:11,weight:.bold),
                NSColor(red:1,green:0.59,blue:0.71,alpha:ta))}
    }

    // ── Paw ──
    func dPaw(_ g:CGContext,_ x:CGFloat,_ y:CGFloat,_ sc:CGFloat,_ ro:CGFloat,
              _ pr:CGFloat,_ wk:CGFloat,_ al:Int){
        guard al>0 else{return}; let a=CGFloat(al)/255
        g.saveGState()
        g.translateBy(x:x,y:y); g.rotate(by:ro)
        g.scaleBy(x:sc*(1+pr*0.16),y:sc*(1-pr*0.2))
        g.translateBy(x:0,y:pr*5/max(sc,0.01))

        if pr>0.25&&al>200{
            let ia=(pr-0.25)/0.75*0.5; let sp=CGFloat(CACurrentMediaTime()*3)
            g.setStrokeColor(CGColor(red:1,green:140.0/255.0,blue:180.0/255.0,alpha:ia*a))
            g.setLineWidth(2.2); g.setLineCap(.round)
            for i in 0..<8{let an=CGFloat(i)*(.pi/4)+sp
                g.move(to:CGPoint(x:cos(an)*34,y:sin(an)*34))
                g.addLine(to:CGPoint(x:cos(an)*(44+pr*14),y:sin(an)*(44+pr*14)))
                g.strokePath()}}

        g.setFillColor(CGColor(red:0,green:0,blue:0,alpha:a*25.0/255.0))
        g.fillEllipse(in:CGRect(x:-26-pr*3,y:0,width:52+pr*6,height:18))

        if al>200{g.setStrokeColor(CGColor(red:238.0/255.0,green:218.0/255.0,blue:198.0/255.0,alpha:a*100.0/255.0))
            g.setLineWidth(0.7)
            for i in 0..<18{let an=CGFloat(i)/18*(.pi*2)+0.12; let l=CGFloat((i*7)%4)*0.7+1.8
                g.move(to:CGPoint(x:cos(an)*24,y:sin(an)*28))
                g.addLine(to:CGPoint(x:cos(an)*(24+l),y:sin(an)*(28+l))); g.strokePath()}}

        let padPath=CGMutablePath()
        padPath.addEllipse(in:CGRect(x:-25,y:-29,width:50,height:58))
        fillGrad(g,padPath,CGPoint(x:-3,y:-8),29,
            (1,0.98,0.96,a),(1,0.89,0.8,a))
        g.setStrokeColor(CGColor(red:olR,green:olG,blue:olB,alpha:a))
        g.setLineWidth(2.4); g.addPath(padPath); g.strokePath()

        let beanPath=CGMutablePath()
        beanPath.move(to:CGPoint(x:0,y:13))
        beanPath.addCurve(to:CGPoint(x:-10,y:-4),control1:CGPoint(x:-14,y:11),control2:CGPoint(x:-15,y:0))
        beanPath.addCurve(to:CGPoint(x:0,y:-8),control1:CGPoint(x:-5,y:-9),control2:CGPoint(x:0,y:-8))
        beanPath.addCurve(to:CGPoint(x:10,y:-4),control1:CGPoint(x:0,y:-8),control2:CGPoint(x:5,y:-9))
        beanPath.addCurve(to:CGPoint(x:0,y:13),control1:CGPoint(x:15,y:0),control2:CGPoint(x:14,y:11))
        beanPath.closeSubpath()
        fillGrad(g,beanPath,CGPoint(x:-1,y:1),15,
            (1,0.72,0.82,a),(1,0.42,0.54,a))
        g.setStrokeColor(CGColor(red:olR,green:olG,blue:olB,alpha:a))
        g.setLineWidth(1.9); g.addPath(beanPath); g.strokePath()

        g.setFillColor(CGColor(red:1,green:1,blue:1,alpha:a*107.0/255.0))
        g.fillEllipse(in:CGRect(x:-9.5,y:-5.8,width:12,height:7.6))
        let spk=CGFloat(sin(CACurrentMediaTime()*2)*0.5+0.5)*0.35
        g.setFillColor(CGColor(red:1,green:1,blue:1,alpha:spk*a))
        g.fillEllipse(in:CGRect(x:-6.3,y:-2.3,width:2.6,height:2.6))

        let toes:[(CGFloat,CGFloat,CGFloat,CGFloat,CGFloat)]=[
            (-15,-17,6,7.4,-0.28),(-5,-23,5.4,6.7,-0.08),
            (5,-23,5.4,6.7,0.08),(15,-17,6,7.4,0.28)]
        for i in 0..<4{let(tx,ty,rx,ry,ta)=toes[i]
            let ws:CGFloat=(wk>0&&i==1) ? (1-wk*0.8):1
            g.saveGState(); g.translateBy(x:tx,y:ty); g.rotate(by:ta)
            g.setFillColor(CGColor(red:1,green:176.0/255.0,blue:204.0/255.0,alpha:a))
            g.fillEllipse(in:CGRect(x:-rx*ws,y:-ry*ws,width:rx*2*ws,height:ry*2*ws))
            g.setStrokeColor(CGColor(red:olR,green:olG,blue:olB,alpha:a))
            g.setLineWidth(1.7)
            g.strokeEllipse(in:CGRect(x:-rx*ws,y:-ry*ws,width:rx*2*ws,height:ry*2*ws))
            g.setFillColor(CGColor(red:1,green:1,blue:1,alpha:a*107.0/255.0))
            g.fillEllipse(in:CGRect(x:-rx*0.35*ws,y:-ry*0.4*ws,width:rx*0.7*ws,height:ry*0.4*ws))
            g.restoreGState()}

        g.setFillColor(CGColor(red:1,green:100.0/255.0,blue:140.0/255.0,alpha:a*36.0/255.0))
        g.fillEllipse(in:CGRect(x:-16.5,y:2.5,width:9,height:5))
        g.fillEllipse(in:CGRect(x:7.5,y:2.5,width:9,height:5))
        g.restoreGState()
    }

    func fillGrad(_ g:CGContext,_ path:CGPath,_ center:CGPoint,_ radius:CGFloat,
                  _ c1:(CGFloat,CGFloat,CGFloat,CGFloat),_ c2:(CGFloat,CGFloat,CGFloat,CGFloat)){
        g.saveGState(); g.addPath(path); g.clip()
        g.setFillColor(CGColor(red:c2.0,green:c2.1,blue:c2.2,alpha:c2.3))
        g.addPath(path); g.fillPath()
        let colors=[CGColor(red:c1.0,green:c1.1,blue:c1.2,alpha:c1.3),
                    CGColor(red:c2.0,green:c2.1,blue:c2.2,alpha:c2.3)]
        if let gr=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1]){
            g.drawRadialGradient(gr,startCenter:center,startRadius:0,
                endCenter:center,endRadius:radius,options:[.drawsAfterEndLocation])}
        g.restoreGState()
    }

    // ── Particles ──
    func dParts(_ g:CGContext){
        for p in Paw.i.pts{
            let t=CGFloat(p.life)/CGFloat(p.ml)
            let a=t<0.1 ? t*10:max(0,1-(t-0.1)/0.9); let ai=Int(a*255)
            guard ai>0 else{continue}
            switch p.type{case 0:dHeart(g,p,ai);case 1:dSpk(g,p,ai)
            case 2:dSak(g,p,ai);case 3:dBub(g,p,ai);case 4:dTxt(g,p,ai);default:break}
        }
    }
    func dHeart(_ g:CGContext,_ p:Pt,_ ai:Int){
        let a=CGFloat(ai)/255; let s=p.sz*0.5
        g.saveGState(); g.translateBy(x:p.x,y:p.y); g.rotate(by:p.rot)
        let hp=CGMutablePath()
        hp.move(to:CGPoint(x:0,y:s*0.4))
        hp.addCurve(to:CGPoint(x:-s,y:-s*0.1),control1:CGPoint(x:0,y:-s*0.2),control2:CGPoint(x:-s,y:-s*0.6))
        hp.addCurve(to:CGPoint(x:0,y:s*1.1),control1:CGPoint(x:-s,y:s*0.5),control2:CGPoint(x:0,y:s*0.8))
        hp.addCurve(to:CGPoint(x:s,y:-s*0.1),control1:CGPoint(x:0,y:s*0.8),control2:CGPoint(x:s,y:s*0.5))
        hp.addCurve(to:CGPoint(x:0,y:s*0.4),control1:CGPoint(x:s,y:-s*0.6),control2:CGPoint(x:0,y:-s*0.2))
        hp.closeSubpath()
        g.setFillColor(CGColor(red:p.r/255,green:p.g/255,blue:p.b/255,alpha:a))
        g.addPath(hp); g.fillPath(); g.restoreGState()
    }
    func dSpk(_ g:CGContext,_ p:Pt,_ ai:Int){
        let a=CGFloat(ai)/255
        g.saveGState(); g.translateBy(x:p.x,y:p.y); g.rotate(by:p.rot)
        let path=CGMutablePath()
        for i in 0..<4{let an=CGFloat(i)*(.pi/2); let ia=an + .pi/4
            let outer=CGPoint(x:cos(an)*p.sz,y:sin(an)*p.sz)
            let inner=CGPoint(x:cos(ia)*p.sz*0.28,y:sin(ia)*p.sz*0.28)
            if i==0{path.move(to:outer)}else{path.addLine(to:outer)}
            path.addLine(to:inner)}
        path.closeSubpath()
        g.setFillColor(CGColor(red:p.r/255,green:p.g/255,blue:p.b/255,alpha:a))
        g.addPath(path); g.fillPath(); g.restoreGState()
    }
    func dSak(_ g:CGContext,_ p:Pt,_ ai:Int){
        let a=CGFloat(ai)/255
        g.saveGState(); g.translateBy(x:p.x,y:p.y); g.rotate(by:p.rot)
        g.rotate(by:20*(.pi/180))
        g.setFillColor(CGColor(red:1,green:0.72,blue:0.77,alpha:a))
        g.fillEllipse(in:CGRect(x:-p.sz*0.5,y:-p.sz*0.2,width:p.sz,height:p.sz*0.4))
        g.restoreGState()
        g.saveGState(); g.translateBy(x:p.x,y:p.y); g.rotate(by:p.rot)
        g.rotate(by:-20*(.pi/180))
        g.setFillColor(CGColor(red:1,green:0.8,blue:0.84,alpha:a))
        g.fillEllipse(in:CGRect(x:-p.sz*0.5,y:-p.sz*0.2,width:p.sz,height:p.sz*0.4))
        g.restoreGState()
    }
    func dBub(_ g:CGContext,_ p:Pt,_ ai:Int){
        let a=CGFloat(ai)/255/2
        g.setStrokeColor(CGColor(red:p.r/255,green:p.g/255,blue:p.b/255,alpha:a))
        g.setLineWidth(1)
        g.strokeEllipse(in:CGRect(x:p.x-p.sz,y:p.y-p.sz,width:p.sz*2,height:p.sz*2))
        g.setFillColor(CGColor(red:1,green:1,blue:1,alpha:a))
        g.fillEllipse(in:CGRect(x:p.x-p.sz*0.5,y:p.y-p.sz*0.5,width:p.sz*0.4,height:p.sz*0.4))
    }
    func dTxt(_ g:CGContext,_ p:Pt,_ ai:Int){
        guard let t=p.txt else{return}
        let a=CGFloat(ai)/255
        let color=NSColor(red:p.r/255,green:p.g/255,blue:p.b/255,alpha:a)
        g.saveGState(); g.translateBy(x:p.x,y:p.y); g.rotate(by:p.rot)
        drawText(g,t,0,0,.systemFont(ofSize:p.sz,weight:.bold),color)
        g.restoreGState()
    }
    func dRips(_ g:CGContext){
        let now=CACurrentMediaTime()
        var j=Paw.i.rps.count-1
        while j>=0{let r=Paw.i.rps[j]; let age=CGFloat(now-r.t0)/0.5
            if age>1{Paw.i.rps.remove(at:j);j-=1;continue}
            let rad=r.mr*age; let a=(1-age)*0.45
            g.setStrokeColor(CGColor(red:1,green:0.71,blue:0.82,alpha:a))
            g.setLineWidth(2)
            g.strokeEllipse(in:CGRect(x:r.x-rad,y:r.y-rad,width:rad*2,height:rad*2))
            j-=1}
    }

    // ── Text helper ──
    func drawText(_ g:CGContext,_ text:String,_ x:CGFloat,_ y:CGFloat,
                  _ font:NSFont,_ color:NSColor){
        let attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:color]
        let str=text as NSString; let sz=str.size(withAttributes:attrs)
        g.saveGState(); g.translateBy(x:x,y:y); g.scaleBy(x:1,y:-1)
        str.draw(at:CGPoint(x:-sz.width/2,y:-sz.height/2),withAttributes:attrs)
        g.restoreGState()
    }
}

// ════════════════════════════════════════════════════════════════
//  Mouse Callback (C-convention for CGEventTap)
// ════════════════════════════════════════════════════════════════

func mouseCallback(proxy:CGEventTapProxy,type:CGEventType,event:CGEvent,
                   refcon:UnsafeMutableRawPointer?)->Unmanaged<CGEvent>?{
    let p=Paw.i; let loc=event.location
    switch type{
    case .mouseMoved,.leftMouseDragged,.rightMouseDragged,.otherMouseDragged:
        p.mx=loc.x; p.my=loc.y
    case .leftMouseDown: btnDown(0,loc.x,loc.y)
    case .leftMouseUp: btnUp(0)
    case .rightMouseDown: btnDown(1,loc.x,loc.y)
    case .rightMouseUp: btnUp(1)
    case .otherMouseDown:
        btnDown(Int(event.getIntegerValueField(.mouseEventButtonNumber)),loc.x,loc.y)
    case .otherMouseUp:
        btnUp(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
    case .tapDisabledByTimeout:
        if let t=App.shared?.eventTap{CGEvent.tapEnable(tap:t,enable:true)}
    default:break
    }
    return Unmanaged.passUnretained(event)
}

let gratitudeQueue=DispatchQueue(label:"lapka.gratitude")

func btnDown(_ b:Int,_ x:CGFloat,_ y:CGFloat){
    let p=Paw.i; guard b==p.aBtn&&(!p.isEx) else{return}
    p.isP=true; p.isH=true; p.hT=CACurrentMediaTime()
    p.pSide *= -1; p.tRot=p.pSide*0.14
    p.spawnRipple(x,y)
    p.spawn(x,y,p.isFP ? 20:5+Int.random(in:0...4))
    p.isFP=false; App.shared?.playPurr()
    gratitudeQueue.async{tryInsertGratitude()}
}
func btnUp(_ b:Int){
    let p=Paw.i; guard b==p.aBtn else{return}
    p.isP=false; p.isH=false; App.shared?.stopPurr()
}

// ════════════════════════════════════════════════════════════════
//  Gratitude
// ════════════════════════════════════════════════════════════════

func tryInsertGratitude(){
    let app=NSWorkspace.shared.frontmostApplication?.localizedName?.lowercased() ?? ""
    guard app.contains("cursor")||app.contains("claude") else{return}
    let pet=Paw.pets.randomElement()!
    let thx=Paw.thanks.randomElement()!
    let msg=pet+thx+" ❤"
    DispatchQueue.main.sync{
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(msg,forType:.string)
    }
    usleep(30_000)
    let src=CGEventSource(stateID:.combinedSessionState)
    let vDown=CGEvent(keyboardEventSource:src,virtualKey:0x09,keyDown:true)
    vDown?.flags = .maskCommand; vDown?.post(tap:.cghidEventTap)
    let vUp=CGEvent(keyboardEventSource:src,virtualKey:0x09,keyDown:false)
    vUp?.post(tap:.cghidEventTap)
}

// ════════════════════════════════════════════════════════════════
//  App Delegate
// ════════════════════════════════════════════════════════════════

class App: NSObject, NSApplicationDelegate {
    static var shared:App?
    var setupWin:NSWindow?
    var overlayWin:NSWindow?
    var overlayView:OverlayView?
    var statusItem:NSStatusItem?
    var eventTap:CFMachPort?
    var player:AVAudioPlayer?
    var timer:Timer?
    var isPurring=false

    func applicationDidFinishLaunching(_ n:Notification){showSetup()}

    func showSetup(){
        let w=NSWindow(contentRect:NSRect(x:0,y:0,width:360,height:400),
            styleMask:[.borderless],backing:.buffered,defer:false)
        w.center(); w.isOpaque=false
        w.backgroundColor=NSColor.clear
        w.level = .floating; w.isMovableByWindowBackground=true
        let v=SetupView(frame:NSRect(x:0,y:0,width:360,height:400))
        v.onButton={[weak self] btn,_ in
            w.close(); self?.startPaw(btn)
        }
        w.contentView=v; w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        setupWin=w
    }

    func startPaw(_ btn:Int){
        Paw.i.aBtn=btn; setupWin=nil
        for id in activeDisplayIDs(){CGDisplayHideCursor(id)}

        let sz=OverlayView.SZ
        let panel=NSPanel(contentRect:NSRect(x:0,y:0,width:sz,height:sz),
            styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque=false; panel.backgroundColor=NSColor.clear
        panel.hasShadow=false; panel.ignoresMouseEvents=true
        panel.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.maximumWindow)))
        panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        let v=OverlayView(frame:NSRect(x:0,y:0,width:sz,height:sz))
        panel.contentView=v; panel.orderFrontRegardless()
        overlayWin=panel; overlayView=v

        startMouseMonitor()
        setupMenuBar()
        loadSound()

        timer=Timer.scheduledTimer(withTimeInterval:1.0/60.0,repeats:true){[weak self] _ in
            Paw.i.tick()
            let p=Paw.i
            let pt=NSPoint(x:p.px,y:p.py)
            let screen=NSScreen.screens.first(where:{NSMouseInRect(NSPoint(x:pt.x,y:$0.frame.maxY-pt.y),$0.frame,false)}) ?? NSScreen.main
            let sh=screen?.frame.maxY ?? NSScreen.main?.frame.height ?? 900
            let wx=p.px-sz/2, wy=sh-p.py-sz/2
            self?.overlayWin?.setFrameOrigin(NSPoint(x:wx,y:wy))
            self?.overlayView?.needsDisplay=true
            if p.done{self?.quit()}
        }
        RunLoop.current.add(timer!,forMode:.common)
    }

    func startMouseMonitor(){
        var mask:CGEventMask = 0
        mask |= (1 << CGEventType.mouseMoved.rawValue)
        mask |= (1 << CGEventType.leftMouseDown.rawValue)
        mask |= (1 << CGEventType.leftMouseUp.rawValue)
        mask |= (1 << CGEventType.rightMouseDown.rawValue)
        mask |= (1 << CGEventType.rightMouseUp.rawValue)
        mask |= (1 << CGEventType.otherMouseDown.rawValue)
        mask |= (1 << CGEventType.otherMouseUp.rawValue)
        mask |= (1 << CGEventType.leftMouseDragged.rawValue)
        mask |= (1 << CGEventType.rightMouseDragged.rawValue)
        mask |= (1 << CGEventType.otherMouseDragged.rawValue)
        guard let tap=CGEvent.tapCreate(tap:.cghidEventTap,place:.headInsertEventTap,
            options:.listenOnly,eventsOfInterest:mask,
            callback:mouseCallback,userInfo:nil) else{
            let alert=NSAlert()
            alert.messageText="Accessibility Permission Required"
            alert.informativeText="Lapka needs Accessibility permission to track mouse events.\n\nGo to System Settings → Privacy & Security → Accessibility and enable Lapka."
            alert.addButton(withTitle:"Open Settings")
            alert.addButton(withTitle:"Quit")
            if alert.runModal() == .alertFirstButtonReturn{
                NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)}
            NSApp.terminate(nil); return
        }
        eventTap=tap
        let src=CFMachPortCreateRunLoopSource(nil,tap,0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(),src,.commonModes)
        CGEvent.tapEnable(tap:tap,enable:true)
    }

    func setupMenuBar(){
        statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        if let btn=statusItem?.button{
            let img=NSImage(size:NSSize(width:18,height:18),flipped:false){r in
                NSColor(red:1,green:0.59,blue:0.71,alpha:1).setFill()
                NSBezierPath(ovalIn:NSRect(x:3,y:0,width:12,height:10)).fill()
                NSBezierPath(ovalIn:NSRect(x:1,y:6,width:6,height:7)).fill()
                NSBezierPath(ovalIn:NSRect(x:6,y:9,width:5,height:6)).fill()
                NSBezierPath(ovalIn:NSRect(x:11,y:6,width:6,height:7)).fill()
                return true}
            img.isTemplate=false; btn.image=img}
        let menu=NSMenu()
        menu.addItem(NSMenuItem(title:"Quit Lapka",action:#selector(quitAction),keyEquivalent:""))
        statusItem?.menu=menu
    }
    @objc func quitAction(){Paw.i.isEx=true; Paw.i.spawn(Paw.i.px,Paw.i.py,25)}

    func loadSound(){
        var url=Bundle.main.url(forResource:"cute-purr",withExtension:"mp3")
        if url==nil{
            let dir=Bundle.main.bundleURL.deletingLastPathComponent()
            let alt=dir.appendingPathComponent("cute-purr.mp3")
            if FileManager.default.fileExists(atPath:alt.path){url=alt}
        }
        guard let u=url else{return}
        player=try? AVAudioPlayer(contentsOf:u)
        player?.numberOfLoops = -1; player?.prepareToPlay()
    }
    func playPurr(){guard !isPurring else{return}; player?.play(); isPurring=true}
    func stopPurr(){guard isPurring else{return}; player?.pause(); isPurring=false}

    func quit(){
        timer?.invalidate()
        for id in activeDisplayIDs(){CGDisplayShowCursor(id)}
        stopPurr()
        overlayWin?.close()
        statusItem=nil
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ n:Notification){
        for id in activeDisplayIDs(){CGDisplayShowCursor(id)}
    }
    func activeDisplayIDs()->[CGDirectDisplayID]{
        var ids=[CGDirectDisplayID](repeating:0,count:16)
        var cnt:UInt32=0
        CGGetActiveDisplayList(16,&ids,&cnt)
        return Array(ids.prefix(Int(cnt)))
    }
}

// ════════════════════════════════════════════════════════════════
//  Entry
// ════════════════════════════════════════════════════════════════

let app=NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate=App(); App.shared=delegate
app.delegate=delegate

signal(SIGTERM){_ in _exit(0)}
signal(SIGINT){_ in _exit(0)}

app.run()
