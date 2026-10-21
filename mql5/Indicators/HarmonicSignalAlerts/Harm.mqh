//+------------------------------------------------------------------+
//|                                                         Harm.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Harmonic pattern engine of Harmonic Signal Alerts, one CLOSED    |
//| bar per step (no repaint). Rules: README; tested against         |
//| tests/reference.py.                                              |
//|                                                                  |
//| Swings: a pivot high at bar p has a high above each of the `left`|
//| bars before it and not below any of the `right` bars after it,   |
//| so it is known `right` bars later. Swings alternate high/low; a  |
//| pivot of the same type replaces the last swing only when it is   |
//| more extreme; one on the wrong side of the last swing is ignored.|
//| Patterns (Carney ratios, widened by `tol`): when the last swing  |
//| (C) changes, XABC (ABCD: ABC) is checked; each match projects a  |
//| key level for D and a PRZ = key +/- prz x XA (ABCD: x AB).       |
//| Completion: the first closed bar on which the extreme since C    |
//| reaches the PRZ near edge, unless a close since C went beyond    |
//| the far edge (void). A bar beyond C ends the pattern. The event  |
//| is dated on the bar it became known, never earlier.              |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef HARM_MQH
#define HARM_MQH

#define HM_N      128                 // ring of recent bars (left + right + 2 must stay below it)
#define HM_PAT    3
#define HM_SW     8                   // swings kept
#define HM_EV     (2*HM_PAT)          // events one bar can give (live + just-built candidates)

#define HM_ABCD      0
#define HM_GARTLEY   1
#define HM_BAT       2

string HMName(const int pat)
  {
   switch(pat)
     {
      case HM_ABCD:      return("ABCD");
      case HM_GARTLEY:   return("Gartley");
      case HM_BAT:       return("Bat");
     }
   return("?");
  }

//--- b_lo, b_hi (AB/XA), c_lo, c_hi (BC/AB), d (key ratio), p_lo, p_hi (CD/BC at the key, 0 = no check)
void HMRatios(const int pat,double &r[])
  {
   ArrayResize(r,7);
   double t[HM_PAT][7]=
     {
        {0,0,0.382,0.886,1.0,0,0},
        {0.618,0.618,0.382,0.886,0.786,1.13,1.618},
        {0.382,0.50,0.382,0.886,0.886,1.618,2.618}
     };
   for(int i=0; i<7; i++)
      r[i]=t[pat][i];
  }

struct HMParams
  {
   int    left,right;
   double tol;                        // relative widening of every ratio (0.05 = 5%)
   double prz;                        // PRZ half-width, share of XA (ABCD: AB)
   bool   use[HM_PAT];
  };

struct HMSwing
  {
   int    type;                       // 1 high, -1 low
   double px;
   int    bar;
  };

struct HMCand
  {
   int    pat,dir;
   double near_,far_;
   int    xb,ab,bb,cb;
   double xp,ap,bp,cp;
   double ext;                        // extreme since C (EMPTY_VALUE none yet)
   int    ext_bar;
   double worst;                      // worst close since C
  };

struct HMEvent
  {
   int    bar,dir,pat;
   int    xb,ab,bb,cb,db;              // xb = -1 for ABCD
   double xp,ap,bp,cp,dp;
   double near_,far_;
  };

struct HMState
  {
   int     cnt;                       // bars fed; bar k = the k-th fed bar (0-based)
   double  h[HM_N],l[HM_N],c[HM_N];
   HMSwing sw[HM_SW];
   int     nsw;
   HMCand  cand[HM_PAT];
   int     ncand;
   HMEvent ev[HM_EV];
   int     nev;                       // events of the last bar
  };

void HMInit(HMState &s)
  {
   s.cnt=0; s.nsw=0; s.ncand=0; s.nev=0;
  }

double HMH(const HMState &s,const int k) { return(s.h[k%HM_N]); }
double HML(const HMState &s,const int k) { return(s.l[k%HM_N]); }
double HMC(const HMState &s,const int k) { return(s.c[k%HM_N]); }

bool HMInside(const double v,const double lo,const double hi,const double tol)
  {
   return(v>=lo*(1.0-tol) && v<=hi*(1.0+tol));
  }

//--- candidates completed by the last swing (C)
void HMMatch(HMState &s,const HMParams &p)
  {
   s.ncand=0;
   if(s.nsw<3)
      return;
   HMSwing C=s.sw[s.nsw-1],B=s.sw[s.nsw-2],A=s.sw[s.nsw-3];
   bool bull=(C.type==1);
   double sg=bull ? 1.0 : -1.0;
   double AB=MathAbs(A.px-B.px),BC=MathAbs(C.px-B.px);
   if(AB<=0 || BC<=0)
      return;
   double r[];
   for(int pat=0; pat<HM_PAT; pat++)
     {
      if(!p.use[pat])
         continue;
      HMRatios(pat,r);
      double key,scale,xp=0;
      int xb=-1;
      if(pat==HM_ABCD)
        {
         if(!HMInside(BC/AB,r[2],r[3],p.tol))
            continue;
         key=C.px-sg*AB;
         scale=AB;
        }
      else
        {
         if(s.nsw<4)
            continue;
         HMSwing X=s.sw[s.nsw-4];
         double XA=MathAbs(A.px-X.px);
         if(XA<=0 || !HMInside(AB/XA,r[0],r[1],p.tol))
            continue;
         if(!HMInside(BC/AB,r[2],r[3],p.tol))
            continue;
         key=A.px-sg*r[4]*XA;
         if(r[5]>0 && !HMInside(MathAbs(C.px-key)/BC,r[5],r[6],p.tol))
            continue;
         scale=XA;
         xb=X.bar; xp=X.px;
        }
      if(sg*(C.px-key)<=0)
         continue;
      int k=s.ncand++;
      s.cand[k].pat=pat; s.cand[k].dir=(bull ? 1 : -1);
      s.cand[k].near_=key+sg*p.prz*scale; s.cand[k].far_=key-sg*p.prz*scale;
      s.cand[k].xb=xb; s.cand[k].xp=xp;
      s.cand[k].ab=A.bar; s.cand[k].ap=A.px; s.cand[k].bb=B.bar; s.cand[k].bp=B.px; s.cand[k].cb=C.bar; s.cand[k].cp=C.px;
      s.cand[k].ext=EMPTY_VALUE; s.cand[k].ext_bar=-1; s.cand[k].worst=EMPTY_VALUE;
     }
  }

//--- bar j into candidate k; false when it is finished (dead, void or fired). fire_at = the bar an event is dated on
bool HMStep(HMState &s,const HMParams &p,HMCand &cd,const int j,const int fire_at)
  {
   double h=HMH(s,j),l=HML(s,j),c=HMC(s,j);
   int sg=cd.dir;
   if(sg>0 ? h>cd.cp : l<cd.cp)
      return(false);                                    // beyond C: C moves, the pattern ends
   double x=(sg>0 ? l : h);
   if(cd.ext==EMPTY_VALUE || (sg>0 ? x<cd.ext : x>cd.ext))
     { cd.ext=x; cd.ext_bar=j; }
   if(cd.worst==EMPTY_VALUE || (sg>0 ? c<cd.worst : c>cd.worst))
      cd.worst=c;
   if(!(sg>0 ? cd.ext<=cd.near_ : cd.ext>=cd.near_))
      return(true);
   if(sg>0 ? cd.worst<cd.far_ : cd.worst>cd.far_)
      return(false);                                    // closed beyond the zone: void
   if(s.nev>=HM_EV)
      return(false);
   int e=s.nev++;
   s.ev[e].bar=fire_at; s.ev[e].dir=sg; s.ev[e].pat=cd.pat;
   s.ev[e].xb=cd.xb; s.ev[e].ab=cd.ab; s.ev[e].bb=cd.bb; s.ev[e].cb=cd.cb; s.ev[e].db=cd.ext_bar;
   s.ev[e].xp=cd.xp; s.ev[e].ap=cd.ap; s.ev[e].bp=cd.bp; s.ev[e].cp=cd.cp; s.ev[e].dp=cd.ext;
   s.ev[e].near_=cd.near_; s.ev[e].far_=cd.far_;
   return(false);
  }

//--- feed one CLOSED bar; true when it completed at least one pattern (s.ev[0..nev-1])
bool HMFeed(HMState &s,const HMParams &p,const double high,const double low,const double close)
  {
   int k=s.cnt;
   s.h[k%HM_N]=high; s.l[k%HM_N]=low; s.c[k%HM_N]=close;
   s.cnt++;
   s.nev=0;
//--- live candidates take this bar
   int w=0;
   for(int i=0; i<s.ncand; i++)
      if(HMStep(s,p,s.cand[i],k,k))
         s.cand[w++]=s.cand[i];
   s.ncand=w;
//--- pivot confirmed at q = k - right
   int q=k-p.right;
   if(q-p.left<0)
      return(s.nev>0);
   bool is_h=true,is_l=true;
   for(int j=1; j<=p.left && (is_h || is_l); j++)
     {
      if(!(HMH(s,q)>HMH(s,q-j))) is_h=false;
      if(!(HML(s,q)<HML(s,q-j))) is_l=false;
     }
   for(int j=1; j<=p.right && (is_h || is_l); j++)
     {
      if(!(HMH(s,q)>=HMH(s,q+j))) is_h=false;
      if(!(HML(s,q)<=HML(s,q+j))) is_l=false;
     }
   if(is_h && is_l)
     {
      if(s.nsw==0)
         return(s.nev>0);
      is_h=(s.sw[s.nsw-1].type==-1);
      is_l=(s.sw[s.nsw-1].type==1);
     }
   bool changed=false;
   for(int pass=0; pass<2; pass++)
     {
      int typ=(pass==0 ? 1 : -1);
      if(typ==1 ? !is_h : !is_l)
         continue;
      double px=(typ==1 ? HMH(s,q) : HML(s,q));
      if(s.nsw>0 && s.sw[s.nsw-1].type==typ)
        {
         if(typ==1 ? px>s.sw[s.nsw-1].px : px<s.sw[s.nsw-1].px)
           {
            s.sw[s.nsw-1].px=px; s.sw[s.nsw-1].bar=q;
            changed=true;
           }
        }
      else
         if(s.nsw>0 && (typ==-1 ? px>=s.sw[s.nsw-1].px : px<=s.sw[s.nsw-1].px))
           { }                                           // on the wrong side of the last swing
         else
           {
            if(s.nsw==HM_SW)
              {
               for(int i=1; i<HM_SW; i++)
                  s.sw[i-1]=s.sw[i];
               s.nsw--;
              }
            s.sw[s.nsw].type=typ; s.sw[s.nsw].px=px; s.sw[s.nsw].bar=q;
            s.nsw++;
            changed=true;
           }
     }
   if(!changed)
      return(s.nev>0);
   HMMatch(s,p);
//--- new candidates catch up on the bars after C (C's pivot rule: none of them is beyond C)
   w=0;
   for(int i=0; i<s.ncand; i++)
     {
      bool ok=true;
      for(int j=s.cand[i].cb+1; j<=k && ok; j++)
         ok=HMStep(s,p,s.cand[i],j,k);
      if(ok)
         s.cand[w++]=s.cand[i];
     }
   s.ncand=w;
   return(s.nev>0);
  }

//--- a short list of pattern names fired on the last bar, e.g. "Gartley, ABCD"
string HMEventNames(const HMState &s,const int dir)
  {
   string r="";
   for(int i=0; i<s.nev; i++)
      if(s.ev[i].dir==dir)
         r+=(r=="" ? "" : ", ")+HMName(s.ev[i].pat);
   return(r);
  }

#endif
//+------------------------------------------------------------------+
