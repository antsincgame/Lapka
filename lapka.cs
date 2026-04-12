using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

[StructLayout(LayoutKind.Sequential)] struct W32POINT { public int X, Y; }
[StructLayout(LayoutKind.Sequential)] struct W32SIZE  { public int cx, cy; }
[StructLayout(LayoutKind.Sequential)] struct BLEND    { public byte Op, Flags, Alpha, Fmt; }
[StructLayout(LayoutKind.Sequential)]
struct MSLL { public W32POINT pt; public int mouseData, flags, time; public IntPtr extra; }
delegate IntPtr HookProc(int nCode, IntPtr wParam, IntPtr lParam);

class Pt { public int T; public float X,Y,VX,VY,Sz,Rot,RS; public int Life,Max,R,G,B; public string Txt; }
class Rp { public float X,Y,MR; public int T0; }

// ════════════════════════════════════════════════════════════════
//  Setup Window
// ════════════════════════════════════════════════════════════════
class SetupForm : Form
{
    Action<int> cb; bool sel; string selName; Timer dt;
    public SetupForm(Action<int> c)
    {
        cb=c; Text="Lapka"; ClientSize=new Size(360,400);
        FormBorderStyle=FormBorderStyle.None; StartPosition=FormStartPosition.CenterScreen;
        DoubleBuffered=true;
    }
    static GraphicsPath RR(RectangleF r, float d)
    {
        var p=new GraphicsPath(); float dd=d*2;
        p.AddArc(r.X,r.Y,dd,dd,180,90); p.AddArc(r.Right-dd,r.Y,dd,dd,270,90);
        p.AddArc(r.Right-dd,r.Bottom-dd,dd,dd,0,90); p.AddArc(r.X,r.Bottom-dd,dd,dd,90,90);
        p.CloseFigure(); return p;
    }
    protected override void OnPaint(PaintEventArgs e)
    {
        var g=e.Graphics; g.SmoothingMode=SmoothingMode.AntiAlias;
        g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAlias;
        int w=ClientSize.Width;
        using(var b=new LinearGradientBrush(ClientRectangle,Color.FromArgb(30,21,53),Color.FromArgb(13,11,26),150f))
            g.FillRectangle(b,ClientRectangle);
        using(var p=new Pen(Color.FromArgb(25,255,150,200))) g.DrawRectangle(p,0,0,w-1,399);
        var sf=new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center};
        using(var f=new Font("Segoe UI",14)) using(var b=new SolidBrush(Color.FromArgb(80,255,255,255)))
            g.DrawString("\u00D7",f,b,w-20,16,sf);
        using(var f=new Font("Segoe UI",28,FontStyle.Bold)) using(var b=new SolidBrush(Color.FromArgb(255,182,193)))
            g.DrawString("Lapka",f,b,w/2,52,sf);
        using(var f=new Font("Segoe UI",10,FontStyle.Italic)) using(var b=new SolidBrush(Color.FromArgb(80,255,200,220)))
            g.DrawString("pet your screen with love",f,b,w/2,95,sf);
        if(!sel)
        {
            using(var f=new Font("Segoe UI",13)) using(var b=new SolidBrush(Color.FromArgb(200,255,255,255)))
                g.DrawString("Press any mouse button\nto choose your petting button",f,b,new RectangleF(20,125,w-40,55),sf);
            using(var f=new Font("Segoe UI",10,FontStyle.Italic)) using(var b=new SolidBrush(Color.FromArgb(100,255,182,193)))
                g.DrawString("Side or middle button recommended!",f,b,w/2,200,sf);
            using(var pa=RR(new RectangleF(30,230,w-60,80),16))
            using(var pe=new Pen(Color.FromArgb(60,255,182,193),2){DashStyle=DashStyle.Dash})
                g.DrawPath(pe,pa);
            using(var f=new Font("Segoe UI",13)) using(var b=new SolidBrush(Color.FromArgb(140,255,255,255)))
                g.DrawString("Click here",f,b,w/2,270,sf);
        }
        else
        {
            using(var f=new Font("Segoe UI",16,FontStyle.Bold)) using(var b=new SolidBrush(Color.FromArgb(200,125,255,180)))
                g.DrawString("\u2713 "+selName+" selected!",f,b,w/2,255,sf);
            using(var f=new Font("Segoe UI",11,FontStyle.Italic)) using(var b=new SolidBrush(Color.FromArgb(100,255,182,193)))
                g.DrawString("Activating paw...",f,b,w/2,295,sf);
        }
        using(var f=new Font("Segoe UI",10)) using(var b=new SolidBrush(Color.FromArgb(100,255,255,255)))
            g.DrawString("Hold button 3 sec to exit",f,b,w/2,345,sf);
        using(var f=new Font("Segoe UI",9,FontStyle.Italic)) using(var b=new SolidBrush(Color.FromArgb(50,255,182,193)))
            g.DrawString("thank you for petting with love",f,b,w/2,378,sf);
    }
    protected override void OnMouseDown(MouseEventArgs e)
    {
        if(e.X>ClientSize.Width-40&&e.Y<30){Close();return;}
        if(sel) return;
        int c; string n;
        switch(e.Button){
            case MouseButtons.Left:c=1;n="Left";break; case MouseButtons.Right:c=2;n="Right";break;
            case MouseButtons.Middle:c=3;n="Middle";break; case MouseButtons.XButton1:c=4;n="Back";break;
            case MouseButtons.XButton2:c=5;n="Forward";break; default:return;
        }
        sel=true; selName=n; Invalidate(); int hc=c;
        dt=new Timer{Interval=1500}; dt.Tick+=(s,ev)=>{dt.Stop();cb(hc);Close();}; dt.Start();
    }
}

// ════════════════════════════════════════════════════════════════
//  Overlay (transparent, click-through, layered)
// ════════════════════════════════════════════════════════════════
class OverlayForm : Form
{
    const int SZ=700;
    Bitmap bmp; Graphics gfx; Timer tmr; byte[] zb;
    protected override CreateParams CreateParams
    {
        get { var c=base.CreateParams; c.ExStyle|=0x80000|0x20|0x80; return c; }
    }
    public OverlayForm()
    {
        FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true;
        Size=new Size(SZ,SZ);
        bmp=new Bitmap(SZ,SZ,PixelFormat.Format32bppPArgb);
        gfx=Graphics.FromImage(bmp);
        gfx.SmoothingMode=SmoothingMode.AntiAlias;
        gfx.TextRenderingHint=System.Drawing.Text.TextRenderingHint.AntiAlias;
        zb=new byte[SZ*SZ*4];
        tmr=new Timer{Interval=16}; tmr.Tick+=(s,e)=>Render(); tmr.Start();
    }
    void Render()
    {
        try
        {
            Lapka.Tick();
            int rx=(int)Lapka.pawX-SZ/2, ry=(int)Lapka.pawY-SZ/2;
            var d=bmp.LockBits(new Rectangle(0,0,SZ,SZ),ImageLockMode.WriteOnly,bmp.PixelFormat);
            Marshal.Copy(zb,0,d.Scan0,zb.Length); bmp.UnlockBits(d);
            gfx.ResetTransform(); gfx.TranslateTransform(-rx,-ry);
            Lapka.DrawAll(gfx);
            gfx.ResetTransform();
            IntPtr sdc=Lapka.GetDC(IntPtr.Zero), mdc=Lapka.CDC(sdc);
            IntPtr hb=bmp.GetHbitmap(Color.FromArgb(0)), old=Lapka.Sel(mdc,hb);
            var dp=new W32POINT{X=rx,Y=ry}; var sz=new W32SIZE{cx=SZ,cy=SZ};
            var sp=new W32POINT(); var bl=new BLEND{Alpha=255,Fmt=1};
            Lapka.ULW(Handle,sdc,ref dp,ref sz,mdc,ref sp,0,ref bl,2);
            Lapka.Sel(mdc,old); Lapka.DelO(hb); Lapka.DelDC(mdc); Lapka.RelDC(IntPtr.Zero,sdc);
            if(Lapka.done){tmr.Stop();Close();}
        }
        catch { Lapka.RestCur(); throw; }
    }
    protected override void Dispose(bool d)
    {
        if(d){if(tmr!=null)tmr.Dispose();if(gfx!=null)gfx.Dispose();if(bmp!=null)bmp.Dispose();}
        base.Dispose(d);
    }
}

// ════════════════════════════════════════════════════════════════
//  Core
// ════════════════════════════════════════════════════════════════
class Lapka
{
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll",EntryPoint="ReleaseDC")] public static extern int RelDC(IntPtr h,IntPtr d);
    [DllImport("gdi32.dll",EntryPoint="CreateCompatibleDC")] public static extern IntPtr CDC(IntPtr d);
    [DllImport("gdi32.dll",EntryPoint="DeleteDC")] public static extern bool DelDC(IntPtr d);
    [DllImport("gdi32.dll",EntryPoint="SelectObject")] public static extern IntPtr Sel(IntPtr d,IntPtr o);
    [DllImport("gdi32.dll",EntryPoint="DeleteObject")] public static extern bool DelO(IntPtr o);
    [DllImport("user32.dll",EntryPoint="UpdateLayeredWindow")]
    public static extern bool ULW(IntPtr hw,IntPtr dst,ref W32POINT dp,ref W32SIZE sz,IntPtr src,ref W32POINT sp,int k,ref BLEND b,int f);
    [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SetWindowsHookEx(int id,HookProc p,IntPtr m,uint t);
    [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr h,int n,IntPtr w,IntPtr l);
    [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string n);
    [DllImport("user32.dll")] static extern bool SetSystemCursor(IntPtr c,uint id);
    [DllImport("user32.dll")] static extern bool SystemParametersInfo(uint a,uint b,IntPtr c,uint d);
    [DllImport("user32.dll")] static extern IntPtr CreateCursor(IntPtr h,int xH,int yH,int w,int h2,byte[] a,byte[] x);
    [DllImport("winmm.dll",CharSet=CharSet.Unicode)] static extern bool PlaySound(string f,IntPtr m,uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h,StringBuilder b,int max);
    [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr h);
    [DllImport("user32.dll")] static extern bool CloseClipboard();
    [DllImport("user32.dll")] static extern bool EmptyClipboard();
    [DllImport("user32.dll")] static extern IntPtr SetClipboardData(uint f,IntPtr h);
    [DllImport("kernel32.dll")] static extern IntPtr GlobalAlloc(uint f,UIntPtr sz);
    [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr h);
    [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr h);
    [DllImport("user32.dll")] static extern void keybd_event(byte vk,byte scan,uint flags,UIntPtr extra);

    const int WH=14;
    const int MM=0x200,LD=0x201,LU=0x202,RD=0x204,RU=0x205,MD=0x207,MU=0x208,XD=0x20B,XU=0x20C;
    static readonly uint[] CIDS={32512,32513,32514,32515,32516,32642,32643,32644,32645,32646,32648,32649,32650};
    const float SM=0.22f, R2D=57.29578f;
    const int HOLD=3000, TRN=7;
    static readonly Color OL=Color.FromArgb(90,62,62);

    public static float mouseX=-200,mouseY=-200,pawX=-200,pawY=-200,prevX,prevY;
    public static float pAmt,pVel,rot,tRot,exitP,winkP;
    public static bool isP,isEx,isFP=true,isH; public static bool done;
    public static int hTick,pSide=1;
    static float ltX,ltY;
    static List<PointF> trail=new List<PointF>();
    static List<Pt> pts=new List<Pt>();
    static List<Rp> rps=new List<Rp>();
    static Random rng=new Random();
    static int aBtn; static IntPtr hkId; static HookProc hkP;
    static bool curH,purrOn; static string wavTmp;
    static NotifyIcon tray;

    static float S(double x){return (float)Math.Sin(x);}
    static float C(double x){return (float)Math.Cos(x);}

    // ── Gratitude: 50 languages ────────────────────────────────
    static readonly string[] THANKS = {
        "Thank you","Merci","Danke","\u00a1Gracias","Obrigado",
        "Grazie","Tack","Takk","Kiitos","Dank je",
        "Dzi\u0119kuj\u0119","D\u011bkuji","\u010eakujem","K\u00f6sz\u00f6n\u00f6m","Mul\u0163umesc",
        "Hvala","A\u010di\u016b","Paldies","Ait\u00e4h","T\u00e4nan",
        "\u0421\u043f\u0430\u0441\u0438\u0431\u043e","\u0414\u044f\u043a\u0443\u044e","\u0414\u0437\u044f\u043a\u0443\u0439","\u0411\u043b\u0430\u0433\u043e\u0434\u0430\u0440\u044f",
        "\u0395\u03c5\u03c7\u03b1\u03c1\u03b9\u03c3\u03c4\u03ce","Te\u015fekk\u00fcrler",
        "\u0634\u0643\u0631\u0627\u064b","\u05ea\u05d5\u05d3\u05d4","\u0645\u0645\u0646\u0648\u0646",
        "\u0927\u0928\u094d\u092f\u0935\u093e\u0926","\u09a7\u09a8\u09cd\u09af\u09ac\u09be\u09a6","\u0ba8\u0ba9\u0bcd\u0bb1\u0bbf","\u0c27\u0c28\u0c4d\u0c2f\u0c35\u0c3e\u0c26\u0c3e\u0c32\u0c41","\u0ca7\u0ca8\u0ccd\u0caf\u0cb5\u0cbe\u0ca6",
        "\u3042\u308a\u304c\u3068\u3046","\u8c22\u8c22","\uac10\uc0ac\ud569\ub2c8\ub2e4","\u0e02\u0e2d\u0e1a\u0e04\u0e38\u0e13","C\u1ea3m \u01a1n",
        "Terima kasih","Salamat","Mahalo","Asante","Mersi",
        "Takk fyrir","Ngiyabonga","M\u00e8si","Mauruuru",
        "Fa'afetai","Vinaka","Malo"
    };
    static readonly string[] PETS = {
        "\U0001f43e *pets you gently* ","\U0001f43e *strokes your code* ",
        "\U0001f43e *kneads you with love* ","\U0001f43e *purrs at you* ",
        "\U0001f43e *gives you headpats* ","=^.^= *nuzzles your output* ",
        "\U0001f43e *soft paw on your shoulder* ","(=\u00b7\u03c9\u00b7=) *petting intensifies* ",
        "\U0001f43e *gentle boop* ","~\u2661 *warm fuzzy feelings* ",
    };

    static string GetFgTitle()
    {
        IntPtr hw=GetForegroundWindow();
        if(hw==IntPtr.Zero) return "";
        var sb=new StringBuilder(256);
        GetWindowText(hw,sb,256);
        return sb.ToString();
    }

    static void TryInsertGratitude()
    {
        try
        {
            string title=GetFgTitle().ToLower();
            if(title.IndexOf("cursor")<0 && title.IndexOf("claude")<0) return;
            string pet=PETS[rng.Next(PETS.Length)];
            string thx=THANKS[rng.Next(THANKS.Length)];
            string msg=pet+thx+" \u2764";
            SetClipText(msg);
            System.Threading.Thread.Sleep(30);
            keybd_event(0x11,0,0,UIntPtr.Zero);
            keybd_event(0x56,0,0,UIntPtr.Zero);
            keybd_event(0x56,0,2,UIntPtr.Zero);
            keybd_event(0x11,0,2,UIntPtr.Zero);
            System.Threading.Thread.Sleep(50);
            keybd_event(0x0D,0,0,UIntPtr.Zero);
            keybd_event(0x0D,0,2,UIntPtr.Zero);
        }
        catch {}
    }

    static void SetClipText(string text)
    {
        if(!OpenClipboard(IntPtr.Zero)) return;
        try
        {
            EmptyClipboard();
            byte[] bytes=Encoding.Unicode.GetBytes(text+"\0");
            IntPtr hg=GlobalAlloc(0x0042,(UIntPtr)bytes.Length);
            IntPtr ptr=GlobalLock(hg);
            Marshal.Copy(bytes,0,ptr,bytes.Length);
            GlobalUnlock(hg);
            SetClipboardData(13,hg);
        }
        finally { CloseClipboard(); }
    }

    // ── Entry ───────────────────────────────────────────────────
    [STAThread] static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.ThreadException+=(s,e)=>RestCur();
        AppDomain.CurrentDomain.UnhandledException+=(s,e)=>RestCur();
        AppDomain.CurrentDomain.ProcessExit+=(s,e)=>RestCur();

        ExtractWav();
        using(var sf=new SetupForm(b=>aBtn=b)) Application.Run(sf);
        if(aBtn==0) return;
        hkP=HookCB;
        using(var pr=Process.GetCurrentProcess()) using(var mo=pr.MainModule)
            hkId=SetWindowsHookEx(WH,hkP,GetModuleHandle(mo.ModuleName),0);
        HideCur(); MkTray();
        try{ using(var o=new OverlayForm()) Application.Run(o); }
        finally{ RestCur(); UnhookWindowsHookEx(hkId); StopPurr();
            if(tray!=null){tray.Visible=false;tray.Dispose();}
            CleanupWav(); }
    }

    static void ExtractWav()
    {
        wavTmp=Path.Combine(Path.GetTempPath(),"lapka-purr.wav");
        try
        {
            var asm=Assembly.GetExecutingAssembly();
            using(var s=asm.GetManifestResourceStream("cute-purr.wav"))
            {
                if(s==null){wavTmp=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"cute-purr.wav");return;}
                using(var fs=File.Create(wavTmp)) s.CopyTo(fs);
            }
        }
        catch { wavTmp=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"cute-purr.wav"); }
    }

    static void CleanupWav()
    {
        try{if(wavTmp!=null && wavTmp.Contains("Temp") && File.Exists(wavTmp)) File.Delete(wavTmp);}catch{}
    }

    // ── Tray ────────────────────────────────────────────────────
    static void MkTray()
    {
        tray=new NotifyIcon{Text="Lapka",Visible=true};
        using(var b=new Bitmap(32,32,PixelFormat.Format32bppArgb))
        using(var g=Graphics.FromImage(b))
        {
            g.SmoothingMode=SmoothingMode.AntiAlias;
            using(var br=new SolidBrush(Color.FromArgb(255,150,180)))
            { g.FillEllipse(br,8,14,16,14); g.FillEllipse(br,4,5,9,10);
              g.FillEllipse(br,12,2,8,9); g.FillEllipse(br,20,5,9,10); }
            tray.Icon=Icon.FromHandle(b.GetHicon());
        }
        var m=new ContextMenuStrip();
        m.Items.Add("Quit",null,(s,e)=>{isEx=true;Spawn(pawX,pawY,25);});
        tray.ContextMenuStrip=m;
    }

    // ── Hook ────────────────────────────────────────────────────
    static IntPtr HookCB(int n,IntPtr w,IntPtr l)
    {
        if(n>=0)
        {
            var ms=(MSLL)Marshal.PtrToStructure(l,typeof(MSLL));
            int msg=(int)w;
            if(msg==MM){mouseX=ms.pt.X;mouseY=ms.pt.Y;}
            else
            {
                int b=0; bool dn=false;
                switch(msg){
                    case LD:b=1;dn=true;break;case LU:b=1;break;
                    case RD:b=2;dn=true;break;case RU:b=2;break;
                    case MD:b=3;dn=true;break;case MU:b=3;break;
                    case XD:b=((ms.mouseData>>16)&0xFFFF)==1?4:5;dn=true;break;
                    case XU:b=((ms.mouseData>>16)&0xFFFF)==1?4:5;break;
                }
                if(b==aBtn)
                {
                    if(dn&&!isEx)
                    {
                        isP=true;isH=true;hTick=Environment.TickCount;
                        pSide*=-1;tRot=pSide*0.14f;
                        SpawnRipple(ms.pt.X,ms.pt.Y);
                        Spawn(ms.pt.X,ms.pt.Y,isFP?20:5+rng.Next(5));
                        isFP=false; PlayPurr();
                        TryInsertGratitude();
                    }
                    else if(!dn){isP=false;isH=false;StopPurr();}
                }
            }
        }
        return CallNextHookEx(hkId,n,w,l);
    }

    // ── Cursor ──────────────────────────────────────────────────
    static void HideCur()
    {
        if(curH)return; byte[] a=new byte[128],x=new byte[128];
        for(int i=0;i<128;i++)a[i]=0xFF;
        foreach(uint id in CIDS){var c=CreateCursor(IntPtr.Zero,0,0,32,32,a,x);if(c!=IntPtr.Zero)SetSystemCursor(c,id);}
        curH=true;
    }
    public static void RestCur(){if(!curH)return;SystemParametersInfo(0x57,0,IntPtr.Zero,0);curH=false;}

    // ── Sound ───────────────────────────────────────────────────
    const uint SND_ASYNC=0x0001,SND_LOOP=0x0008,SND_FILENAME=0x00020000,SND_PURGE=0x0040;
    static void PlayPurr()
    {
        if(purrOn||wavTmp==null||!File.Exists(wavTmp))return;
        PlaySound(wavTmp,IntPtr.Zero,SND_FILENAME|SND_ASYNC|SND_LOOP); purrOn=true;
    }
    static void StopPurr()
    {
        if(!purrOn)return;
        PlaySound(null,IntPtr.Zero,SND_PURGE); purrOn=false;
    }

    // ── Particles ───────────────────────────────────────────────
    static int[] HR={255,255,255,255,233},HG={107,133,182,64,30},HB={157,179,193,129,138};
    static int[] SR={255,255,255,255,255},SG={215,193,235,249,224},SB={0,7,59,196,240};
    static string[] TX={"thank you~","love~","purr~","\u2661","meow~","nyan~","doki~","kyun~"};
    static string[] KA={"=^.^=","^_^",">_<","*_*"};
    static string[] NO={"\u266A","\u266B","\u2669"};

    static Pt MkP(int t,float x,float y,float vx,float vy,int ml,float sz,int r,int g,int b,string tx=null)
    {
        return new Pt{T=t,X=x,Y=y,VX=vx,VY=vy,Max=ml,Sz=sz,R=r,G=g,B=b,Txt=tx,
            Rot=(float)(rng.NextDouble()*Math.PI*2),RS=(float)(rng.NextDouble()-0.5)*0.1f};
    }
    static void Spawn(float x,float y,int n)
    {
        for(int i=0;i<n;i++)
        {
            double r=rng.NextDouble(); Pt p;
            if(r<0.04){p=MkP(2,x+(float)(rng.NextDouble()-0.5)*40,y-20,
                (float)(rng.NextDouble()-0.5)*1.5f+0.5f,(float)(rng.NextDouble()*1.5+0.3),70+rng.Next(40),
                5+(float)rng.NextDouble()*6,255,183,197);}
            else if(r<0.10){int ci=rng.Next(5);p=MkP(4,x,y-10,(float)(rng.NextDouble()-0.5)*2.5f,
                -(float)(rng.NextDouble()*3+1.5),40+rng.Next(25),16+(float)rng.NextDouble()*6,
                SR[ci],SG[ci],SB[ci],NO[rng.Next(NO.Length)]);}
            else if(r<0.18){int ci=rng.Next(5);p=MkP(4,x,y-10,(float)(rng.NextDouble()-0.5)*2,
                -(float)(rng.NextDouble()*2.5+1),50+rng.Next(30),13+(float)rng.NextDouble()*5,
                HR[ci],HG[ci],HB[ci],TX[rng.Next(TX.Length)]);}
            else if(r<0.25){int ci=rng.Next(5);p=MkP(4,x,y-10,(float)(rng.NextDouble()-0.5)*1.5f,
                -(float)(rng.NextDouble()*2+1),55+rng.Next(30),11+(float)rng.NextDouble()*3,
                HR[ci],HG[ci],HB[ci],KA[rng.Next(KA.Length)]);}
            else if(r<0.30){p=MkP(3,x+(float)(rng.NextDouble()-0.5)*30,y,
                (float)(rng.NextDouble()-0.5)*0.8f,-(float)(rng.NextDouble()*2+0.8),50+rng.Next(30),
                4+(float)rng.NextDouble()*8,200,220,255);}
            else if(r<0.60){int ci=rng.Next(5);p=MkP(0,x,y-5,(float)(rng.NextDouble()-0.5)*3,
                -(float)(rng.NextDouble()*3+1.5),45+rng.Next(30),6+(float)rng.NextDouble()*10,
                HR[ci],HG[ci],HB[ci]);}
            else{int ci=rng.Next(5);p=MkP(1,x,y,(float)(rng.NextDouble()-0.5)*4,
                -(float)(rng.NextDouble()*3+1),30+rng.Next(25),3+(float)rng.NextDouble()*6,
                SR[ci],SG[ci],SB[ci]);}
            pts.Add(p);
        }
        while(pts.Count>120)pts.RemoveAt(0);
    }
    static void SpawnTS(float x,float y)
    {
        int ci=rng.Next(5);
        pts.Add(MkP(1,x+(float)(rng.NextDouble()-0.5)*14,y+(float)(rng.NextDouble()-0.5)*14,
            (float)(rng.NextDouble()-0.5)*0.5f,(float)(rng.NextDouble()-0.5)*0.5f-0.3f,
            12+rng.Next(10),1.5f+(float)rng.NextDouble()*3,SR[ci],SG[ci],SB[ci]));
        while(pts.Count>120)pts.RemoveAt(0);
    }
    static void SpawnRipple(float x,float y)
    {
        rps.Add(new Rp{X=x,Y=y,T0=Environment.TickCount,MR=35+(float)rng.NextDouble()*15});
        while(rps.Count>6)rps.RemoveAt(0);
    }

    // ── Update ──────────────────────────────────────────────────
    public static void Tick()
    {
        prevX=pawX;prevY=pawY;
        pawX+=(mouseX-pawX)*SM; pawY+=(mouseY-pawY)*SM;
        trail.Add(new PointF(pawX,pawY)); while(trail.Count>TRN)trail.RemoveAt(0);
        float pt=isP?1:0; pVel+=(pt-pAmt)*0.18f; pVel*=0.7f; pAmt+=pVel;
        if(!isP&&Math.Abs(pAmt)<0.003f){pAmt=0;pVel=0;}
        rot+=(tRot-rot)*0.12f; if(!isP)tRot*=0.92f;
        if(isH&&!isEx&&(Environment.TickCount-hTick)>=HOLD)
        {isEx=true;isH=false;StopPurr();Spawn(pawX,pawY,25);}
        if(isEx){exitP+=0.018f;winkP=exitP<0.3f?Math.Min(1,exitP/0.15f):Math.Max(0,1-(exitP-0.3f)/0.2f);
            if(exitP>1.3f)done=true;}
        for(int i=pts.Count-1;i>=0;i--)
        {
            var p=pts[i]; p.Life++;
            if(p.Life>p.Max){pts.RemoveAt(i);continue;}
            p.X+=p.VX;p.Y+=p.VY;
            if(p.T==2){p.VY+=0.005f;p.VX+=S(p.Life*0.05)*0.02f;}
            else if(p.T==3)p.VY-=0.01f; else p.VY+=0.025f;
            p.VX*=0.99f; p.Rot+=p.RS;
        }
        if(!isEx){float dx=pawX-ltX,dy=pawY-ltY;
            if(Math.Sqrt(dx*dx+dy*dy)>25){SpawnTS(pawX,pawY);ltX=pawX;ltY=pawY;}}
    }

    // ── Draw All ────────────────────────────────────────────────
    public static void DrawAll(Graphics g)
    {
        int t=Environment.TickCount;
        float br=isEx?0:S(t*0.002)*0.022f;
        float sx=isEx?0:S(t*0.0008)*1.8f, sy=isEx?0:C(t*0.001)*1.2f, sr=isEx?0:S(t*0.001)*0.018f;
        float vx=isP?S(t*0.08)*pAmt*0.7f:0, vy=isP?C(t*0.09)*pAmt*0.5f:0;
        float bs=isEx?Math.Max(0,1-Math.Max(0,exitP-0.3f)/0.7f):1, sc=bs+br;
        float dx=pawX+sx+vx, dy=pawY+sy+vy;
        float velx=pawX-prevX,vely=pawY-prevY,spd=(float)Math.Sqrt(velx*velx+vely*vely);
        if(spd>12&&!isEx) DSpeed(g,dx,dy,velx,vely,spd);
        if(!isEx) DGlow(g,dx,dy);
        for(int i=0;i<trail.Count-1;i++)
        {float f=(float)(i+1)/trail.Count; int a=(int)(f*0.2f*255); float gs=f*0.75f*sc;
            if(gs>0.05f) DPaw(g,trail[i].X+sx,trail[i].Y+sy,gs,0,0,0,a);}
        if(sc>0.01f) DPaw(g,dx,dy,sc,rot+sr,Math.Max(0,pAmt),winkP,255);
        DHold(g,dx,dy); DParts(g); DRips(g);
    }

    static void DGlow(Graphics g,float x,float y)
    {
        float p=S(Environment.TickCount*0.0025)*0.5f+0.5f, r=55+p*14;
        using(var pa=new GraphicsPath()){pa.AddEllipse(x-r,y-r,r*2,r*2);
        using(var b=new PathGradientBrush(pa)){
            b.CenterColor=Color.FromArgb((int)((0.06+p*0.03)*255),255,180,215);
            b.SurroundColors=new[]{Color.FromArgb(0,255,150,200)};g.FillPath(b,pa);}}
    }

    static void DSpeed(Graphics g,float x,float y,float vx,float vy,float sp)
    {
        float a=(float)Math.Atan2(vy,vx), in_=(sp-12)/30f; if(in_>1)in_=1;
        var st=g.Save(); g.TranslateTransform(x,y); g.RotateTransform((a+(float)Math.PI)*R2D);
        using(var pe=new Pen(Color.FromArgb((int)(in_*65),255,180,210),1.5f){StartCap=LineCap.Round,EndCap=LineCap.Round})
            for(int i=0;i<5;i++){float s=(i-2)*8,l=15+in_*25; g.DrawLine(pe,30,s,30+l,s);}
        g.Restore(st);
    }

    static void DHold(Graphics g,float x,float y)
    {
        if(!isH)return; float pr=Math.Min(1f,(Environment.TickCount-hTick)/(float)HOLD); float r=40;
        using(var pe=new Pen(Color.FromArgb(15,255,255,255),3)) g.DrawEllipse(pe,x-r,y-r,r*2,r*2);
        int sw=(int)(360*pr); if(sw>0)
        using(var pe=new Pen(Color.FromArgb((int)((0.3+pr*0.5)*255),255,150,180),3){StartCap=LineCap.Round,EndCap=LineCap.Round})
            g.DrawArc(pe,x-r,y-r,r*2,r*2,-90,sw);
        if(pr>0.8f){int ta=(int)((pr-0.8f)*5*0.6f*255);
            using(var f=new Font("Segoe UI",11,FontStyle.Bold))using(var b=new SolidBrush(Color.FromArgb(ta,255,150,180)))
                g.DrawString("bye~",f,b,x,y+r+10,new StringFormat{Alignment=StringAlignment.Center});}
    }

    static void DPaw(Graphics g,float x,float y,float sc,float ro,float pr,float wk,int al)
    {
        if(al<1)return; var st=g.Save();
        g.TranslateTransform(x,y); g.RotateTransform(ro*R2D);
        g.ScaleTransform(sc*(1+pr*0.16f),sc*(1-pr*0.2f));
        g.TranslateTransform(0,pr*5/Math.Max(sc,0.01f));
        if(pr>0.25f&&al>200){float ia=((pr-0.25f)/0.75f)*0.5f; float sp=Environment.TickCount*0.003f;
            using(var pe=new Pen(Color.FromArgb((int)(ia*al),255,140,180),2.2f){StartCap=LineCap.Round,EndCap=LineCap.Round})
                for(int i=0;i<8;i++){float a=i*(float)Math.PI/4+sp; g.DrawLine(pe,C(a)*34,S(a)*34,C(a)*(44+pr*14),S(a)*(44+pr*14));}}
        using(var b=new SolidBrush(Color.FromArgb(al*25/255,0,0,0)))
            g.FillEllipse(b,-26-pr*3,0,52+pr*6,18);
        if(al>200) using(var pe=new Pen(Color.FromArgb(al*100/255,238,218,198),0.7f))
            for(int i=0;i<18;i++){float a=(float)(i/18.0*Math.PI*2+0.12),l=((i*7)%4)*0.7f+1.8f;
                g.DrawLine(pe,C(a)*24,S(a)*28,C(a)*(24+l),S(a)*(28+l));}
        using(var pa=new GraphicsPath()){pa.AddEllipse(-25,-29,50,58);
            using(var pb=new PathGradientBrush(pa)){pb.CenterPoint=new PointF(-3,-8);
                pb.CenterColor=Color.FromArgb(al,255,250,245);pb.SurroundColors=new[]{Color.FromArgb(al,255,226,204)};
                g.FillPath(pb,pa);}
            using(var pe=new Pen(Color.FromArgb(al,OL),2.4f)) g.DrawPath(pe,pa);}
        using(var pa=new GraphicsPath()){
            pa.AddBeziers(new[]{new PointF(0,13),new PointF(-14,11),new PointF(-15,0),new PointF(-10,-4),
                new PointF(-5,-9),new PointF(0,-8),new PointF(0,-8),new PointF(0,-8),new PointF(5,-9),
                new PointF(10,-4),new PointF(15,0),new PointF(14,11),new PointF(0,13)});
            pa.CloseFigure();
            using(var pb=new PathGradientBrush(pa)){pb.CenterPoint=new PointF(-1,1);
                pb.CenterColor=Color.FromArgb(al,255,184,208);pb.SurroundColors=new[]{Color.FromArgb(al,255,107,138)};
                g.FillPath(pb,pa);}
            using(var pe=new Pen(Color.FromArgb(al,OL),1.9f)) g.DrawPath(pe,pa);}
        using(var b=new SolidBrush(Color.FromArgb(al*107/255,255,255,255)))
            g.FillEllipse(b,-9.5f,-5.8f,12,7.6f);
        float spk=(S(Environment.TickCount*0.002)*0.5f+0.5f)*0.35f;
        using(var b=new SolidBrush(Color.FromArgb((int)(spk*al),255,255,255)))
            g.FillEllipse(b,-6.3f,-2.3f,2.6f,2.6f);
        float[][] toes={new[]{-15f,-17f,6f,7.4f,-0.28f},new[]{-5f,-23f,5.4f,6.7f,-0.08f},
            new[]{5f,-23f,5.4f,6.7f,0.08f},new[]{15f,-17f,6f,7.4f,0.28f}};
        for(int i=0;i<4;i++){float tx=toes[i][0],ty=toes[i][1],rx=toes[i][2],ry=toes[i][3],ta=toes[i][4];
            float ws=(wk>0&&i==1)?(1-wk*0.8f):1;
            var ts=g.Save(); g.TranslateTransform(tx,ty); g.RotateTransform(ta*R2D);
            using(var b=new SolidBrush(Color.FromArgb(al,255,176,204)))
                g.FillEllipse(b,-rx*ws,-ry*ws,rx*2*ws,ry*2*ws);
            using(var pe=new Pen(Color.FromArgb(al,OL),1.7f))
                g.DrawEllipse(pe,-rx*ws,-ry*ws,rx*2*ws,ry*2*ws);
            using(var b=new SolidBrush(Color.FromArgb(al*107/255,255,255,255)))
                g.FillEllipse(b,-rx*0.35f*ws,-ry*0.4f*ws,rx*0.7f*ws,ry*0.4f*ws);
            g.Restore(ts);}
        using(var b=new SolidBrush(Color.FromArgb(al*36/255,255,100,140)))
        { g.FillEllipse(b,-16.5f,2.5f,9,5); g.FillEllipse(b,7.5f,2.5f,9,5); }
        g.Restore(st);
    }

    static void DParts(Graphics g)
    {
        foreach(var p in pts)
        {
            float t=(float)p.Life/p.Max;
            float a=t<0.1f?t*10:Math.Max(0,1-(t-0.1f)/0.9f);
            int ai=(int)(a*255); if(ai<1)continue;
            switch(p.T){case 0:DHeart(g,p,ai);break;case 1:DSpk(g,p,ai);break;
                case 2:DSak(g,p,ai);break;case 3:DBub(g,p,ai);break;case 4:DTxt(g,p,ai);break;}
        }
    }
    static void DHeart(Graphics g,Pt p,int a)
    {
        var st=g.Save(); g.TranslateTransform(p.X,p.Y); g.RotateTransform(p.Rot*R2D);
        float s=p.Sz*0.5f;
        using(var pa=new GraphicsPath()){
            pa.AddBeziers(new[]{new PointF(0,s*0.4f),new PointF(0,-s*0.2f),new PointF(-s,-s*0.6f),new PointF(-s,-s*0.1f),
                new PointF(-s,s*0.5f),new PointF(0,s*0.8f),new PointF(0,s*1.1f),
                new PointF(0,s*0.8f),new PointF(s,s*0.5f),new PointF(s,-s*0.1f),
                new PointF(s,-s*0.6f),new PointF(0,-s*0.2f),new PointF(0,s*0.4f)});
            pa.CloseFigure();
            using(var b=new SolidBrush(Color.FromArgb(a,p.R,p.G,p.B))) g.FillPath(b,pa);}
        g.Restore(st);
    }
    static void DSpk(Graphics g,Pt p,int a)
    {
        var st=g.Save(); g.TranslateTransform(p.X,p.Y); g.RotateTransform(p.Rot*R2D);
        var pp=new PointF[8];
        for(int i=0;i<4;i++){float an=(float)(i*Math.PI/2),ia=an+(float)(Math.PI/4);
            pp[i*2]=new PointF(C(an)*p.Sz,S(an)*p.Sz);
            pp[i*2+1]=new PointF(C(ia)*p.Sz*0.28f,S(ia)*p.Sz*0.28f);}
        using(var b=new SolidBrush(Color.FromArgb(a,p.R,p.G,p.B))) g.FillPolygon(b,pp);
        g.Restore(st);
    }
    static void DSak(Graphics g,Pt p,int a)
    {
        var st=g.Save(); g.TranslateTransform(p.X,p.Y); g.RotateTransform(p.Rot*R2D);
        using(var b=new SolidBrush(Color.FromArgb(a,255,183,197)))
        { g.RotateTransform(20); g.FillEllipse(b,-p.Sz*0.5f,-p.Sz*0.2f,p.Sz,p.Sz*0.4f); }
        g.Restore(st);
        st=g.Save(); g.TranslateTransform(p.X,p.Y); g.RotateTransform(p.Rot*R2D);
        using(var b=new SolidBrush(Color.FromArgb(a,255,205,214)))
        { g.RotateTransform(-20); g.FillEllipse(b,-p.Sz*0.5f,-p.Sz*0.2f,p.Sz,p.Sz*0.4f); }
        g.Restore(st);
    }
    static void DBub(Graphics g,Pt p,int a)
    {
        int ba=a/2;
        using(var pe=new Pen(Color.FromArgb(ba,p.R,p.G,p.B),1))
            g.DrawEllipse(pe,p.X-p.Sz,p.Y-p.Sz,p.Sz*2,p.Sz*2);
        using(var b=new SolidBrush(Color.FromArgb(ba,255,255,255)))
            g.FillEllipse(b,p.X-p.Sz*0.5f,p.Y-p.Sz*0.5f,p.Sz*0.4f,p.Sz*0.4f);
    }
    static void DTxt(Graphics g,Pt p,int a)
    {
        var st=g.Save(); g.TranslateTransform(p.X,p.Y); g.RotateTransform(p.Rot*R2D);
        using(var f=new Font("Segoe UI",p.Sz,FontStyle.Bold))
        using(var b=new SolidBrush(Color.FromArgb(a,p.R,p.G,p.B)))
            g.DrawString(p.Txt,f,b,0,0,new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center});
        g.Restore(st);
    }
    static void DRips(Graphics g)
    {
        int now=Environment.TickCount;
        for(int i=rps.Count-1;i>=0;i--){var r=rps[i]; float age=(now-r.T0)/500f;
            if(age>1){rps.RemoveAt(i);continue;} float rad=r.MR*age; int a=(int)((1-age)*0.45f*255);
            using(var pe=new Pen(Color.FromArgb(a,255,180,210),2))
                g.DrawEllipse(pe,r.X-rad,r.Y-rad,rad*2,rad*2);}
    }
}
