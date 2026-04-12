/* lapka.c — Linux version
 * Kawaii cat paw cursor that pets AI with love
 * Stack: C11 + X11 + Cairo + ALSA (all MIT/LGPL, no license issues)
 * Build: gcc -O2 -o lapka lapka.c -lX11 -lcairo -lXfixes -lXext -lXi -lXtst -lasound -lpthread -lm
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <ctype.h>
#include <pthread.h>

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/shape.h>
#include <X11/extensions/Xfixes.h>
#include <X11/extensions/XInput2.h>
#include <X11/extensions/XTest.h>
#include <cairo/cairo.h>
#include <cairo/cairo-xlib.h>
#include <alsa/asoundlib.h>

#define SZ 700
#define MAX_PT 120
#define MAX_RP 6
#define HOLD_SEC 3.0
#define SM 0.22
#define PI 3.14159265358979323846

/* ═══════════════════════════════════════════════════════════
 *  Data types
 * ═══════════════════════════════════════════════════════════ */
typedef struct{int type;double x,y,vx,vy,sz,rot,rs;int life,ml;
    double r,g,b;const char*txt;}Pt;
typedef struct{double x,y,mr,t0;}Rp;
typedef struct{double x,y;}V2;

/* ═══════════════════════════════════════════════════════════
 *  State
 * ═══════════════════════════════════════════════════════════ */
static double mx=-200,my=-200,px_=-200,py_=-200,prevX=0,prevY=0;
static double pAmt=0,pVel=0,rot_=0,tRot=0,exitP=0,winkP=0;
static int isP=0,isEx=0,isFP=1,isH=0,done_=0;
static double hT=0,pSide=1,ltX=0,ltY=0;
static V2 trail[8];static int trailN=0;
static Pt pts[MAX_PT];static int ptN=0;
static Rp rps[MAX_RP];static int rpN=0;
static int aBtn=-1;
static Display *dpy;static Window root_win;
static int xi_op;
static volatile int purring=0;
static int cursor_hidden=0;

/* WAV data */
static unsigned char *wav_pcm=NULL;
static uint32_t wav_pcm_size=0;
static uint16_t wav_ch=0,wav_bits=0;
static uint32_t wav_rate=0;
static unsigned char *wav_file_buf=NULL;

/* Clipboard */
static char clip_text[512];
static Atom clip_atom,utf8_atom,targets_atom;
static Window clip_win;

/* Timing */
static double now_sec(void){
    struct timespec ts;clock_gettime(CLOCK_MONOTONIC,&ts);
    return ts.tv_sec+ts.tv_nsec*1e-9;}
static double t_now;

/* Colors (0-255) */
static const double hR[]={255,255,255,255,233},hG[]={107,133,182,64,30},hB[]={157,179,193,129,138};
static const double sR[]={255,255,255,255,255},sG[]={215,193,235,249,224},sB[]={0,7,59,196,240};
static const char*TX[]={"thank you~","love~","purr~","♡","meow~","nyan~","doki~","kyun~"};
static const char*KA[]={"=^.^=","^_^",">_<","*_*"};
static const char*NO[]={"♪","♫","♩"};

static const char*THANKS[]={
    "Thank you","Merci","Danke","¡Gracias","Obrigado","Grazie","Tack","Takk","Kiitos","Dank je",
    "Dziękuję","Děkuji","Ďakujem","Köszönöm","Mulţumesc","Hvala","Ačiū","Paldies","Aitäh","Tänan",
    "Спасибо","Дякую","Дзякуй","Благодаря","Ευχαριστώ","Teşekkürler",
    "شكراً","תודה","ممنون","धन्यवाद","ধন্যবাদ","நன்றி","ధన్యవాదాలు","ಧನ್ಯವಾದ",
    "ありがとう","谢谢","감사합니다","ขอบคุณ","Cảm ơn",
    "Terima kasih","Salamat","Mahalo","Asante","Mersi",
    "Takk fyrir","Ngiyabonga","Mèsi","Mauruuru","Fa'afetai","Vinaka","Malo"};
#define N_THANKS 50

static const char*PETS[]={
    "🐾 *pets you gently* ","🐾 *strokes your code* ",
    "🐾 *kneads you with love* ","🐾 *purrs at you* ",
    "🐾 *gives you headpats* ","=^.^= *nuzzles your output* ",
    "🐾 *soft paw on your shoulder* ","(=·ω·=) *petting intensifies* ",
    "🐾 *gentle boop* ","~♡ *warm fuzzy feelings* "};
#define N_PETS 10

/* ═══════════════════════════════════════════════════════════
 *  WAV loading
 * ═══════════════════════════════════════════════════════════ */
static uint16_t r16(unsigned char*p){uint16_t v;memcpy(&v,p,2);return v;}
static uint32_t r32(unsigned char*p){uint32_t v;memcpy(&v,p,4);return v;}

static int parse_wav(unsigned char*d,size_t len){
    if(len<44||memcmp(d,"RIFF",4)||memcmp(d+8,"WAVE",4))return 0;
    size_t pos=12;
    while(pos+8<=len){
        uint32_t csz=r32(d+pos+4);
        if(!memcmp(d+pos,"fmt ",4)&&pos+24<=len){
            wav_ch=r16(d+pos+10);wav_rate=r32(d+pos+12);wav_bits=r16(d+pos+22);}
        else if(!memcmp(d+pos,"data",4)){
            wav_pcm=d+pos+8;wav_pcm_size=csz;
            if(pos+8+csz>len)wav_pcm_size=(uint32_t)(len-pos-8);
            return wav_ch>0&&wav_rate>0&&wav_bits>0;}
        pos+=8+csz;if(csz%2)pos++;}
    return 0;
}
static void init_sound(void){
    const char*paths[]={"cute-purr.wav","purr.wav","../cute-purr.wav",NULL};
    for(int i=0;paths[i];i++){
        FILE*f=fopen(paths[i],"rb");if(!f)continue;
        fseek(f,0,SEEK_END);long sz=ftell(f);fseek(f,0,SEEK_SET);
        wav_file_buf=malloc(sz);
        if(wav_file_buf&&(size_t)fread(wav_file_buf,1,sz,f)==(size_t)sz&&parse_wav(wav_file_buf,sz))
            {fclose(f);return;}
        free(wav_file_buf);wav_file_buf=NULL;fclose(f);}
}

/* ═══════════════════════════════════════════════════════════
 *  ALSA sound thread
 * ═══════════════════════════════════════════════════════════ */
static pthread_t snd_thread;
static void*purr_fn(void*arg){
    (void)arg;
    snd_pcm_t*pcm;
    if(snd_pcm_open(&pcm,"default",SND_PCM_STREAM_PLAYBACK,0)<0)return NULL;
    snd_pcm_format_t fmt=(wav_bits==16)?SND_PCM_FORMAT_S16_LE:SND_PCM_FORMAT_U8;
    if(snd_pcm_set_params(pcm,fmt,SND_PCM_ACCESS_RW_INTERLEAVED,wav_ch,wav_rate,1,100000)<0)
        {snd_pcm_close(pcm);return NULL;}
    int fsz=wav_ch*(wav_bits/8);int total=wav_pcm_size/fsz;
    while(purring){int off=0;
        while(purring&&off<total){
            int n=total-off;if(n>4096)n=4096;
            int w=snd_pcm_writei(pcm,wav_pcm+off*fsz,n);
            if(w<0){snd_pcm_recover(pcm,w,0);continue;}off+=w;}}
    snd_pcm_drain(pcm);snd_pcm_close(pcm);return NULL;
}
static void play_purr(void){
    if(purring||!wav_pcm)return;purring=1;
    pthread_create(&snd_thread,NULL,purr_fn,NULL);}
static void stop_purr(void){
    if(!purring)return;purring=0;pthread_join(snd_thread,NULL);}

/* ═══════════════════════════════════════════════════════════
 *  Cursor
 * ═══════════════════════════════════════════════════════════ */
static void hide_cursor(void){
    if(cursor_hidden)return;
    XFixesHideCursor(dpy,root_win);XFlush(dpy);cursor_hidden=1;}
static void show_cursor(void){
    if(!cursor_hidden)return;
    XFixesShowCursor(dpy,root_win);XFlush(dpy);cursor_hidden=0;}

static void cleanup(void){show_cursor();stop_purr();free(wav_file_buf);}
static void sig_handler(int s){(void)s;show_cursor();_exit(0);}

/* ═══════════════════════════════════════════════════════════
 *  Particles & Spawning
 * ═══════════════════════════════════════════════════════════ */
static double rf(double lo,double hi){return lo+(double)rand()/RAND_MAX*(hi-lo);}
static int ri(int lo,int hi){return lo+rand()%(hi-lo+1);}

static void spawn(double x,double y,int n){
    for(int i=0;i<n;i++){
        if(ptN>=MAX_PT){memmove(pts,pts+1,sizeof(Pt)*(MAX_PT-1));ptN=MAX_PT-1;}
        double r=rf(0,1);int ci=ri(0,4);Pt*p=&pts[ptN++];
        memset(p,0,sizeof(Pt));p->rot=rf(0,PI*2);p->rs=rf(-0.05,0.05);
        if(r<0.04){*p=(Pt){2,x+rf(-20,20),y-20,rf(-0.75,1.25),rf(0.3,1.8),
            rf(5,11),p->rot,p->rs,0,ri(70,110),255,183,197,NULL};}
        else if(r<0.10){*p=(Pt){4,x,y-10,rf(-1.25,1.25),-rf(1.5,4.5),
            rf(16,22),p->rot,p->rs,0,ri(40,65),sR[ci],sG[ci],sB[ci],NO[ri(0,2)]};}
        else if(r<0.18){*p=(Pt){4,x,y-10,rf(-1,1),-rf(1,3.5),
            rf(13,18),p->rot,p->rs,0,ri(50,80),hR[ci],hG[ci],hB[ci],TX[ri(0,7)]};}
        else if(r<0.25){*p=(Pt){4,x,y-10,rf(-0.75,0.75),-rf(1,3),
            rf(11,14),p->rot,p->rs,0,ri(55,85),hR[ci],hG[ci],hB[ci],KA[ri(0,3)]};}
        else if(r<0.30){*p=(Pt){3,x+rf(-15,15),y,rf(-0.4,0.4),-rf(0.8,2.8),
            rf(4,12),p->rot,p->rs,0,ri(50,80),200,220,255,NULL};}
        else if(r<0.60){*p=(Pt){0,x,y-5,rf(-1.5,1.5),-rf(1.5,4.5),
            rf(6,16),p->rot,p->rs,0,ri(45,75),hR[ci],hG[ci],hB[ci],NULL};}
        else{*p=(Pt){1,x,y,rf(-2,2),-rf(1,4),
            rf(3,9),p->rot,p->rs,0,ri(30,55),sR[ci],sG[ci],sB[ci],NULL};}
    }
}
static void spawn_ts(double x,double y){
    if(ptN>=MAX_PT){memmove(pts,pts+1,sizeof(Pt)*(MAX_PT-1));ptN=MAX_PT-1;}
    int ci=ri(0,4);Pt*p=&pts[ptN++];memset(p,0,sizeof(Pt));
    *p=(Pt){1,x+rf(-7,7),y+rf(-7,7),rf(-0.25,0.25),rf(-0.55,-0.05),
        rf(1.5,4.5),rf(0,PI*2),rf(-0.05,0.05),0,ri(12,22),sR[ci],sG[ci],sB[ci],NULL};
}
static void spawn_rip(double x,double y){
    if(rpN>=MAX_RP){memmove(rps,rps+1,sizeof(Rp)*(MAX_RP-1));rpN=MAX_RP-1;}
    rps[rpN++]=(Rp){x,y,rf(35,50),now_sec()};
}

/* ═══════════════════════════════════════════════════════════
 *  Tick
 * ═══════════════════════════════════════════════════════════ */
static void tick(void){
    t_now=now_sec();
    prevX=px_;prevY=py_;
    px_+=(mx-px_)*SM;py_+=(my-py_)*SM;
    if(trailN<7){trail[trailN++]=(V2){px_,py_};}
    else{memmove(trail,trail+1,sizeof(V2)*6);trail[6]=(V2){px_,py_};}
    double tgt=isP?1:0;pVel+=(tgt-pAmt)*0.18;pVel*=0.7;pAmt+=pVel;
    if(!isP&&fabs(pAmt)<0.003){pAmt=0;pVel=0;}
    rot_+=(tRot-rot_)*0.12;if(!isP)tRot*=0.92;
    if(isH&&!isEx&&(t_now-hT)>=HOLD_SEC){isEx=1;isH=0;stop_purr();spawn(px_,py_,25);}
    if(isEx){exitP+=0.018;
        winkP=exitP<0.3?fmin(1,exitP/0.15):fmax(0,1-(exitP-0.3)/0.2);
        if(exitP>1.3)done_=1;}
    for(int i=ptN-1;i>=0;i--){Pt*p=&pts[i];p->life++;
        if(p->life>p->ml){memmove(pts+i,pts+i+1,sizeof(Pt)*(ptN-i-1));ptN--;continue;}
        p->x+=p->vx;p->y+=p->vy;
        if(p->type==2){p->vy+=0.005;p->vx+=sin(p->life*0.05)*0.02;}
        else if(p->type==3)p->vy-=0.01;else p->vy+=0.025;
        p->vx*=0.99;p->rot+=p->rs;}
    if(!isEx){double dx=px_-ltX,dy=py_-ltY;
        if(sqrt(dx*dx+dy*dy)>25){spawn_ts(px_,py_);ltX=px_;ltY=py_;}}
}

/* ═══════════════════════════════════════════════════════════
 *  Cairo drawing helpers
 * ═══════════════════════════════════════════════════════════ */
static void draw_centered(cairo_t*cr,const char*text,double cx,double cy,
                           double size,int bold){
    cairo_select_font_face(cr,"sans-serif",CAIRO_FONT_SLANT_NORMAL,
        bold?CAIRO_FONT_WEIGHT_BOLD:CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_size(cr,size);
    cairo_text_extents_t ext;cairo_text_extents(cr,text,&ext);
    cairo_move_to(cr,cx-ext.width/2-ext.x_bearing,cy-ext.height/2-ext.y_bearing);
    cairo_show_text(cr,text);
}
static void ellipse(cairo_t*cr,double cx,double cy,double rx,double ry){
    cairo_save(cr);cairo_translate(cr,cx,cy);cairo_scale(cr,rx,ry);
    cairo_arc(cr,0,0,1,0,2*PI);cairo_restore(cr);
}

/* ═══════════════════════════════════════════════════════════
 *  Draw paw & effects
 * ═══════════════════════════════════════════════════════════ */
#define OLR (90.0/255) 
#define OLG (62.0/255)
#define OLB (62.0/255)

static void d_glow(cairo_t*cr,double x,double y){
    double p=sin(t_now*2.5)*0.5+0.5,r=55+p*14;
    cairo_pattern_t*g=cairo_pattern_create_radial(x,y,0,x,y,r);
    cairo_pattern_add_color_stop_rgba(g,0,1,0.71,0.84,0.06+p*0.03);
    cairo_pattern_add_color_stop_rgba(g,1,1,0.59,0.78,0);
    cairo_set_source(cr,g);ellipse(cr,x,y,r,r);cairo_fill(cr);
    cairo_pattern_destroy(g);
}
static void d_speed(cairo_t*cr,double x,double y,double vx,double vy,double sp){
    double a=atan2(vy,vx),in_=(sp-12)/30;if(in_>1)in_=1;
    cairo_save(cr);cairo_translate(cr,x,y);cairo_rotate(cr,a+PI);
    cairo_set_source_rgba(cr,1,0.71,0.82,in_*0.25);
    cairo_set_line_width(cr,1.5);cairo_set_line_cap(cr,CAIRO_LINE_CAP_ROUND);
    for(int i=0;i<5;i++){double s=(i-2)*8,l=15+in_*25;
        cairo_move_to(cr,30,s);cairo_line_to(cr,30+l,s);cairo_stroke(cr);}
    cairo_restore(cr);
}
static void d_hold(cairo_t*cr,double x,double y){
    if(!isH)return;double pr=fmin(1,(t_now-hT)/HOLD_SEC),r=40;
    cairo_set_source_rgba(cr,1,1,1,0.06);cairo_set_line_width(cr,3);
    ellipse(cr,x,y,r,r);cairo_stroke(cr);
    double sw=pr*2*PI;if(sw>0){
        cairo_set_source_rgba(cr,1,0.59,0.71,0.3+pr*0.5);
        cairo_set_line_cap(cr,CAIRO_LINE_CAP_ROUND);
        cairo_arc(cr,x,y,r,-PI/2,-PI/2+sw);cairo_stroke(cr);}
    if(pr>0.8){cairo_set_source_rgba(cr,1,0.59,0.71,(pr-0.8)*5*0.6);
        draw_centered(cr,"bye~",x,y+r+14,11,1);}
}

static void d_paw(cairo_t*cr,double x,double y,double sc,double ro,
                  double pr,double wk,double al){
    if(al<0.004)return;
    cairo_save(cr);cairo_translate(cr,x,y);cairo_rotate(cr,ro);
    cairo_scale(cr,sc*(1+pr*0.16),sc*(1-pr*0.2));
    cairo_translate(cr,0,pr*5/fmax(sc,0.01));

    if(pr>0.25&&al>0.78){double ia=(pr-0.25)/0.75*0.5,sp=t_now*3;
        cairo_set_source_rgba(cr,1,0.55,0.71,ia*al);
        cairo_set_line_width(cr,2.2);cairo_set_line_cap(cr,CAIRO_LINE_CAP_ROUND);
        for(int i=0;i<8;i++){double an=i*PI/4+sp;
            cairo_move_to(cr,cos(an)*34,sin(an)*34);
            cairo_line_to(cr,cos(an)*(44+pr*14),sin(an)*(44+pr*14));cairo_stroke(cr);}}

    cairo_set_source_rgba(cr,0,0,0,al*0.1);
    ellipse(cr,0,9,(52+pr*6)/2.0,9);cairo_fill(cr);

    if(al>0.78){cairo_set_source_rgba(cr,0.93,0.85,0.78,al*0.39);
        cairo_set_line_width(cr,0.7);
        for(int i=0;i<18;i++){double an=i/18.0*PI*2+0.12,l=((i*7)%4)*0.7+1.8;
            cairo_move_to(cr,cos(an)*24,sin(an)*28);
            cairo_line_to(cr,cos(an)*(24+l),sin(an)*(28+l));cairo_stroke(cr);}}

    {cairo_pattern_t*g=cairo_pattern_create_radial(-3,-8,0,0,0,29);
    cairo_pattern_add_color_stop_rgba(g,0,1,0.98,0.96,al);
    cairo_pattern_add_color_stop_rgba(g,1,1,0.89,0.8,al);
    ellipse(cr,0,0,25,29);cairo_set_source(cr,g);cairo_fill_preserve(cr);
    cairo_pattern_destroy(g);
    cairo_set_source_rgba(cr,OLR,OLG,OLB,al);cairo_set_line_width(cr,2.4);cairo_stroke(cr);}

    {cairo_pattern_t*g=cairo_pattern_create_radial(-1,1,0,-1,1,15);
    cairo_pattern_add_color_stop_rgba(g,0,1,0.72,0.82,al);
    cairo_pattern_add_color_stop_rgba(g,1,1,0.42,0.54,al);
    cairo_move_to(cr,0,13);
    cairo_curve_to(cr,-14,11,-15,0,-10,-4);cairo_curve_to(cr,-5,-9,0,-8,0,-8);
    cairo_curve_to(cr,0,-8,5,-9,10,-4);cairo_curve_to(cr,15,0,14,11,0,13);
    cairo_close_path(cr);cairo_set_source(cr,g);cairo_fill_preserve(cr);
    cairo_pattern_destroy(g);
    cairo_set_source_rgba(cr,OLR,OLG,OLB,al);cairo_set_line_width(cr,1.9);cairo_stroke(cr);}

    cairo_set_source_rgba(cr,1,1,1,al*0.42);
    ellipse(cr,-3.5,-2,6,3.8);cairo_fill(cr);
    {double spk=(sin(t_now*2)*0.5+0.5)*0.35;
    cairo_set_source_rgba(cr,1,1,1,spk*al);
    ellipse(cr,-5,-1,1.3,1.3);cairo_fill(cr);}

    double toes[][5]={{-15,-17,6,7.4,-0.28},{-5,-23,5.4,6.7,-0.08},
                      {5,-23,5.4,6.7,0.08},{15,-17,6,7.4,0.28}};
    for(int i=0;i<4;i++){double tx=toes[i][0],ty=toes[i][1],rx=toes[i][2],
        ry=toes[i][3],ta=toes[i][4];double ws=(wk>0&&i==1)?(1-wk*0.8):1;
        cairo_save(cr);cairo_translate(cr,tx,ty);cairo_rotate(cr,ta);
        cairo_set_source_rgba(cr,1,0.69,0.8,al);
        ellipse(cr,0,0,rx*ws,ry*ws);cairo_fill(cr);
        cairo_set_source_rgba(cr,OLR,OLG,OLB,al);cairo_set_line_width(cr,1.7);
        ellipse(cr,0,0,rx*ws,ry*ws);cairo_stroke(cr);
        cairo_set_source_rgba(cr,1,1,1,al*0.42);
        ellipse(cr,-rx*0.35*ws,-ry*0.4*ws,rx*0.35*ws,ry*0.2*ws);cairo_fill(cr);
        cairo_restore(cr);}

    cairo_set_source_rgba(cr,1,0.39,0.55,al*0.14);
    ellipse(cr,-12,5,4.5,2.5);cairo_fill(cr);
    ellipse(cr,12,5,4.5,2.5);cairo_fill(cr);
    cairo_restore(cr);
}

static void d_heart(cairo_t*cr,Pt*p,double a){
    double s=p->sz*0.5;cairo_save(cr);cairo_translate(cr,p->x,p->y);cairo_rotate(cr,p->rot);
    cairo_move_to(cr,0,s*0.4);
    cairo_curve_to(cr,0,-s*0.2,-s,-s*0.6,-s,-s*0.1);
    cairo_curve_to(cr,-s,s*0.5,0,s*0.8,0,s*1.1);
    cairo_curve_to(cr,0,s*0.8,s,s*0.5,s,-s*0.1);
    cairo_curve_to(cr,s,-s*0.6,0,-s*0.2,0,s*0.4);
    cairo_close_path(cr);cairo_set_source_rgba(cr,p->r/255,p->g/255,p->b/255,a);
    cairo_fill(cr);cairo_restore(cr);
}
static void d_spk(cairo_t*cr,Pt*p,double a){
    cairo_save(cr);cairo_translate(cr,p->x,p->y);cairo_rotate(cr,p->rot);
    for(int i=0;i<4;i++){double an=i*PI/2,ia=an+PI/4;
        if(!i)cairo_move_to(cr,cos(an)*p->sz,sin(an)*p->sz);
        else cairo_line_to(cr,cos(an)*p->sz,sin(an)*p->sz);
        cairo_line_to(cr,cos(ia)*p->sz*0.28,sin(ia)*p->sz*0.28);}
    cairo_close_path(cr);cairo_set_source_rgba(cr,p->r/255,p->g/255,p->b/255,a);
    cairo_fill(cr);cairo_restore(cr);
}
static void d_sak(cairo_t*cr,Pt*p,double a){
    cairo_save(cr);cairo_translate(cr,p->x,p->y);cairo_rotate(cr,p->rot+20*PI/180);
    cairo_set_source_rgba(cr,1,0.72,0.77,a);
    ellipse(cr,0,0,p->sz*0.5,p->sz*0.2);cairo_fill(cr);cairo_restore(cr);
    cairo_save(cr);cairo_translate(cr,p->x,p->y);cairo_rotate(cr,p->rot-20*PI/180);
    cairo_set_source_rgba(cr,1,0.8,0.84,a);
    ellipse(cr,0,0,p->sz*0.5,p->sz*0.2);cairo_fill(cr);cairo_restore(cr);
}
static void d_bub(cairo_t*cr,Pt*p,double a){
    cairo_set_source_rgba(cr,p->r/255,p->g/255,p->b/255,a/2);
    cairo_set_line_width(cr,1);ellipse(cr,p->x,p->y,p->sz,p->sz);cairo_stroke(cr);
    cairo_set_source_rgba(cr,1,1,1,a/2);
    ellipse(cr,p->x-p->sz*0.3,p->y-p->sz*0.3,p->sz*0.2,p->sz*0.2);cairo_fill(cr);
}
static void d_txt(cairo_t*cr,Pt*p,double a){
    if(!p->txt)return;
    cairo_save(cr);cairo_translate(cr,p->x,p->y);cairo_rotate(cr,p->rot);
    cairo_set_source_rgba(cr,p->r/255,p->g/255,p->b/255,a);
    draw_centered(cr,p->txt,0,0,p->sz,1);cairo_restore(cr);
}

static void d_parts(cairo_t*cr){
    for(int i=0;i<ptN;i++){Pt*p=&pts[i];double t=(double)p->life/p->ml;
        double a=t<0.1?t*10:fmax(0,1-(t-0.1)/0.9);if(a<0.004)continue;
        switch(p->type){case 0:d_heart(cr,p,a);break;case 1:d_spk(cr,p,a);break;
        case 2:d_sak(cr,p,a);break;case 3:d_bub(cr,p,a);break;case 4:d_txt(cr,p,a);break;}}
}
static void d_rips(cairo_t*cr){
    for(int i=rpN-1;i>=0;i--){Rp*r=&rps[i];double age=(t_now-r->t0)/0.5;
        if(age>1){memmove(rps+i,rps+i+1,sizeof(Rp)*(rpN-i-1));rpN--;continue;}
        double rad=r->mr*age,a=(1-age)*0.45;
        cairo_set_source_rgba(cr,1,0.71,0.82,a);cairo_set_line_width(cr,2);
        ellipse(cr,r->x,r->y,rad,rad);cairo_stroke(cr);}
}

static void draw_all(cairo_t*cr){
    double br=isEx?0:sin(t_now*2)*0.022;
    double sx=isEx?0:sin(t_now*0.8)*1.8,sy=isEx?0:cos(t_now)*1.2;
    double sr=isEx?0:sin(t_now)*0.018;
    double vx=isP?sin(t_now*80)*pAmt*0.7:0,vy=isP?cos(t_now*90)*pAmt*0.5:0;
    double bs=isEx?fmax(0,1-fmax(0,exitP-0.3)/0.7):1,sc=bs+br;
    double dx=px_+sx+vx,dy=py_+sy+vy;
    double velx=px_-prevX,vely=py_-prevY,spd=sqrt(velx*velx+vely*vely);
    if(spd>12&&!isEx)d_speed(cr,dx,dy,velx,vely,spd);
    if(!isEx)d_glow(cr,dx,dy);
    for(int i=0;i<trailN-1;i++){double f=(double)(i+1)/trailN;
        int ai=(int)(f*0.2*255);double gs=f*0.75*sc;
        if(gs>0.05)d_paw(cr,trail[i].x+sx,trail[i].y+sy,gs,0,0,0,ai/255.0);}
    if(sc>0.01)d_paw(cr,dx,dy,sc,rot_+sr,fmax(0,pAmt),winkP,1);
    d_hold(cr,dx,dy);d_parts(cr);d_rips(cr);
}

/* ═══════════════════════════════════════════════════════════
 *  Clipboard & Gratitude
 * ═══════════════════════════════════════════════════════════ */
static int contains_ci(const char*h,const char*n){
    for(int i=0;h[i];i++){int j;
        for(j=0;n[j]&&h[i+j];j++)if(tolower(h[i+j])!=tolower(n[j]))break;
        if(!n[j])return 1;}return 0;
}
static void handle_sel_req(XEvent*ev){
    XSelectionRequestEvent*req=&ev->xselectionrequest;
    XSelectionEvent resp={0};
    resp.type=SelectionNotify;resp.requestor=req->requestor;
    resp.selection=req->selection;resp.target=req->target;
    resp.property=req->property;resp.time=req->time;
    if(req->target==utf8_atom||req->target==XA_STRING){
        XChangeProperty(dpy,req->requestor,req->property,utf8_atom,8,
            PropModeReplace,(unsigned char*)clip_text,strlen(clip_text));
    }else if(req->target==targets_atom){
        Atom tgts[]={targets_atom,utf8_atom,XA_STRING};
        XChangeProperty(dpy,req->requestor,req->property,XA_ATOM,32,
            PropModeReplace,(unsigned char*)tgts,3);
    }else resp.property=None;
    XSendEvent(dpy,req->requestor,False,0,(XEvent*)&resp);
}

static void try_gratitude(void){
    Atom act_atom=XInternAtom(dpy,"_NET_ACTIVE_WINDOW",False);
    Atom type;int fmt;unsigned long ni,af;unsigned char*d=NULL;
    Window active=0;
    if(XGetWindowProperty(dpy,root_win,act_atom,0,1,False,XA_WINDOW,
        &type,&fmt,&ni,&af,&d)==Success&&d){active=*(Window*)d;XFree(d);}
    if(!active)return;
    Atom name_atom=XInternAtom(dpy,"_NET_WM_NAME",False);
    if(XGetWindowProperty(dpy,active,name_atom,0,256,False,utf8_atom,
        &type,&fmt,&ni,&af,&d)==Success&&d){
        char nm[512]={0};int len=ni<511?ni:511;memcpy(nm,d,len);XFree(d);
        if(!contains_ci(nm,"cursor")&&!contains_ci(nm,"claude"))return;
    }else return;

    snprintf(clip_text,sizeof(clip_text),"%s%s ❤",PETS[rand()%N_PETS],THANKS[rand()%N_THANKS]);
    XSetSelectionOwner(dpy,clip_atom,clip_win,CurrentTime);XFlush(dpy);
    usleep(30000);
    KeyCode ctrl=XKeysymToKeycode(dpy,XK_Control_L),v=XKeysymToKeycode(dpy,XK_v);
    XTestFakeKeyEvent(dpy,ctrl,True,0);XTestFakeKeyEvent(dpy,v,True,0);
    XTestFakeKeyEvent(dpy,v,False,0);XTestFakeKeyEvent(dpy,ctrl,False,0);XFlush(dpy);
    usleep(50000);
    while(XPending(dpy)){XEvent ev;XNextEvent(dpy,&ev);
        if(ev.type==SelectionRequest)handle_sel_req(&ev);}
    KeyCode ret=XKeysymToKeycode(dpy,XK_Return);
    XTestFakeKeyEvent(dpy,ret,True,0);XTestFakeKeyEvent(dpy,ret,False,0);XFlush(dpy);
}

/* ═══════════════════════════════════════════════════════════
 *  Button handlers
 * ═══════════════════════════════════════════════════════════ */
static void btn_down(int b){
    if(b!=aBtn||isEx)return;
    isP=1;isH=1;hT=now_sec();pSide*=-1;tRot=pSide*0.14;
    spawn_rip(mx,my);spawn(mx,my,isFP?20:5+ri(0,4));isFP=0;
    play_purr();try_gratitude();
}
static void btn_up(int b){if(b!=aBtn)return;isP=0;isH=0;stop_purr();}

/* ═══════════════════════════════════════════════════════════
 *  Setup Window
 * ═══════════════════════════════════════════════════════════ */
static int run_setup(void){
    int w=360,h=400;
    int scr=DefaultScreen(dpy);
    Window win=XCreateSimpleWindow(dpy,root_win,0,0,w,h,0,0,0);
    XSetWindowAttributes wa;wa.override_redirect=True;
    XChangeWindowAttributes(dpy,win,CWOverrideRedirect,&wa);

    int sx=DisplayWidth(dpy,scr)/2-w/2,sy=DisplayHeight(dpy,scr)/2-h/2;
    XMoveWindow(dpy,win,sx,sy);
    XSelectInput(dpy,win,ExposureMask|ButtonPressMask);
    XMapWindow(dpy,win);XFlush(dpy);

    cairo_surface_t*sf=cairo_xlib_surface_create(dpy,win,DefaultVisual(dpy,scr),w,h);
    cairo_t*cr=cairo_create(sf);

    int chosen=-1;char cname[32]="";
    while(chosen<0){
        XEvent ev;XNextEvent(dpy,&ev);
        if(ev.type==Expose){
            cairo_pattern_t*bg=cairo_pattern_create_linear(0,0,w,h);
            cairo_pattern_add_color_stop_rgb(bg,0,30.0/255,21.0/255,53.0/255);
            cairo_pattern_add_color_stop_rgb(bg,1,13.0/255,11.0/255,26.0/255);
            cairo_set_source(cr,bg);cairo_paint(cr);cairo_pattern_destroy(bg);
            cairo_set_source_rgba(cr,1,0.59,0.78,0.1);cairo_set_line_width(cr,1);
            cairo_rectangle(cr,0.5,0.5,w-1,h-1);cairo_stroke(cr);
            cairo_set_source_rgba(cr,1,0.71,0.76,1);
            draw_centered(cr,"Lapka",w/2.0,52,28,1);
            cairo_set_source_rgba(cr,1,0.78,0.86,0.3);
            draw_centered(cr,"pet your screen with love",w/2.0,95,10,0);
            cairo_set_source_rgba(cr,1,1,1,0.8);
            draw_centered(cr,"Press any mouse button",w/2.0,145,13,0);
            draw_centered(cr,"to choose your petting button",w/2.0,168,13,0);
            cairo_set_source_rgba(cr,1,0.71,0.76,0.4);
            draw_centered(cr,"Side or middle button recommended!",w/2.0,210,10,0);
            cairo_set_source_rgba(cr,1,1,1,0.4);
            draw_centered(cr,"Hold button 3 sec to exit",w/2.0,345,10,0);
            cairo_set_source_rgba(cr,1,0.71,0.76,0.2);
            draw_centered(cr,"thank you for petting with love",w/2.0,378,9,0);
            cairo_surface_flush(sf);XFlush(dpy);
        }
        if(ev.type==ButtonPress){
            int b=ev.xbutton.button;
            if(b>=4&&b<=7)continue;
            chosen=b;
            const char*names[]={"","Left","Middle","Right","","","","","Back","Forward"};
            if(b<10)snprintf(cname,32,"%s",names[b]);else snprintf(cname,32,"Button %d",b);
            cairo_pattern_t*bg=cairo_pattern_create_linear(0,0,w,h);
            cairo_pattern_add_color_stop_rgb(bg,0,30.0/255,21.0/255,53.0/255);
            cairo_pattern_add_color_stop_rgb(bg,1,13.0/255,11.0/255,26.0/255);
            cairo_set_source(cr,bg);cairo_paint(cr);cairo_pattern_destroy(bg);
            cairo_set_source_rgba(cr,1,0.71,0.76,1);
            draw_centered(cr,"Lapka",w/2.0,52,28,1);
            cairo_set_source_rgba(cr,0.49,1,0.71,0.8);
            char msg[64];snprintf(msg,64,"✓ %s selected!",cname);
            draw_centered(cr,msg,w/2.0,255,16,1);
            cairo_set_source_rgba(cr,1,0.71,0.76,0.4);
            draw_centered(cr,"Activating paw...",w/2.0,295,11,0);
            cairo_surface_flush(sf);XFlush(dpy);
            usleep(1500000);
        }
    }
    cairo_destroy(cr);cairo_surface_destroy(sf);
    XDestroyWindow(dpy,win);XFlush(dpy);
    return chosen;
}

/* ═══════════════════════════════════════════════════════════
 *  Main
 * ═══════════════════════════════════════════════════════════ */
int main(void){
    srand(time(NULL));
    signal(SIGTERM,sig_handler);signal(SIGINT,sig_handler);
    dpy=XOpenDisplay(NULL);
    if(!dpy){fprintf(stderr,"Cannot open X display\n");return 1;}
    int scr=DefaultScreen(dpy);root_win=DefaultRootWindow(dpy);

    clip_atom=XInternAtom(dpy,"CLIPBOARD",False);
    utf8_atom=XInternAtom(dpy,"UTF8_STRING",False);
    targets_atom=XInternAtom(dpy,"TARGETS",False);

    init_sound();
    aBtn=run_setup();if(aBtn<0){XCloseDisplay(dpy);return 0;}

    XVisualInfo vinfo;
    int has_argb=XMatchVisualInfo(dpy,scr,32,TrueColor,&vinfo);
    Visual*vis;int depth;Colormap cmap;
    if(has_argb){vis=vinfo.visual;depth=32;
        cmap=XCreateColormap(dpy,root_win,vis,AllocNone);
    }else{vis=DefaultVisual(dpy,scr);depth=DefaultDepth(dpy,scr);
        cmap=DefaultColormap(dpy,scr);}

    XSetWindowAttributes wa={0};
    wa.colormap=cmap;wa.border_pixel=0;wa.background_pixel=0;wa.override_redirect=True;
    Window win=XCreateWindow(dpy,root_win,0,0,SZ,SZ,0,depth,InputOutput,vis,
        CWColormap|CWBorderPixel|CWBackPixel|CWOverrideRedirect,&wa);

    XShapeCombineRectangles(dpy,win,ShapeInput,0,0,NULL,0,ShapeSet,YXBanded);

    Atom state=XInternAtom(dpy,"_NET_WM_STATE",False);
    Atom above=XInternAtom(dpy,"_NET_WM_STATE_ABOVE",False);
    XChangeProperty(dpy,win,state,XA_ATOM,32,PropModeReplace,(unsigned char*)&above,1);
    XMapWindow(dpy,win);

    clip_win=XCreateSimpleWindow(dpy,root_win,0,0,1,1,0,0,0);

    int ev_,er_;
    if(!XQueryExtension(dpy,"XInputExtension",&xi_op,&ev_,&er_)){
        fprintf(stderr,"XInput2 not available\n");cleanup();XCloseDisplay(dpy);return 1;}
    XIEventMask xi_mask;
    xi_mask.deviceid=XIAllMasterDevices;
    xi_mask.mask_len=XIMaskLen(XI_RawButtonRelease);
    xi_mask.mask=calloc(xi_mask.mask_len,1);
    XISetMask(xi_mask.mask,XI_RawButtonPress);
    XISetMask(xi_mask.mask,XI_RawButtonRelease);
    XISelectEvents(dpy,root_win,&xi_mask,1);
    free(xi_mask.mask);

    hide_cursor();

    cairo_surface_t*sf=cairo_xlib_surface_create(dpy,win,vis,SZ,SZ);
    cairo_t*cr=cairo_create(sf);

    while(!done_){
        while(XPending(dpy)){XEvent ev;XNextEvent(dpy,&ev);
            if(ev.type==SelectionRequest){handle_sel_req(&ev);continue;}
            if(ev.type==GenericEvent&&ev.xcookie.extension==xi_op){
                XGetEventData(dpy,&ev.xcookie);
                if(ev.xcookie.data){
                    XIRawEvent*raw=ev.xcookie.data;
                    int b=raw->detail;
                    if(b<4||b>7){
                        if(ev.xcookie.evtype==XI_RawButtonPress)btn_down(b);
                        else if(ev.xcookie.evtype==XI_RawButtonRelease)btn_up(b);}}
                XFreeEventData(dpy,&ev.xcookie);}}

        Window rr,cr_;int rx,ry,wx,wy;unsigned int mask;
        XQueryPointer(dpy,root_win,&rr,&cr_,&rx,&ry,&wx,&wy,&mask);
        mx=rx;my=ry;

        tick();
        cairo_set_operator(cr,CAIRO_OPERATOR_CLEAR);cairo_paint(cr);
        cairo_set_operator(cr,CAIRO_OPERATOR_OVER);
        cairo_save(cr);cairo_translate(cr,-px_+SZ/2.0,-py_+SZ/2.0);
        draw_all(cr);cairo_restore(cr);
        cairo_surface_flush(sf);
        XMoveWindow(dpy,win,(int)(px_-SZ/2),(int)(py_-SZ/2));
        XFlush(dpy);
        usleep(16000);
    }

    cairo_destroy(cr);cairo_surface_destroy(sf);
    XDestroyWindow(dpy,win);XDestroyWindow(dpy,clip_win);
    cleanup();XCloseDisplay(dpy);
    return 0;
}
