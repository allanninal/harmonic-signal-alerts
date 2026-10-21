//+------------------------------------------------------------------+
//|                                         HarmonicSignalAlerts.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of Harmonic Signal Alerts: the same engine (Harm.mqh,|
//| an exact copy of the MT5 edition's Harm.mqh). ABCD,              |
//| Gartley and Bat patterns: XABCD lines, PRZ box and an arrow on   |
//| the closed bar where price reached its potential reversal zone,  |
//| only from swings already confirmed, so nothing is ever drawn     |
//| into the past or removed.                                        |
//| MT4 difference: the arrows sit a fraction of ATR(14) away from   |
//| the candle (MT4 has no pixel shift). Buffers for iCustom match   |
//| MT5: 0 bullish, 1 bearish, 2/3 pattern masks.                    |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property strict
#property description "ABCD, Gartley and Bat harmonic patterns: XABCD lines and the reversal zone, drawn when price reaches the zone."
#property description "Confirmed swings and closed bars only: a pattern never moves or disappears. Alerts: pop-up, sound, push, e-mail."
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1  C'38,166,98'
#property indicator_width1  2
#property indicator_color2  C'226,74,70'
#property indicator_width2  2

#include "Harm.mqh"

input bool   InpABCD      = true;    // ABCD
input bool   InpGartley   = true;    // Gartley
input bool   InpBat       = true;    // Bat
input int    InpLeft      = 10;      // Swing: bars on the left
input int    InpRight     = 5;       // Swing: bars on the right (the confirmation delay)
input double InpTol       = 5.0;     // Ratio tolerance, %
input double InpPRZ       = 3.0;     // Reversal zone half-width, % of XA (ABCD: of AB)
input int    InpHistory   = 3000;    // Closed bars to scan on the chart (100-20000)
input bool   InpLines     = true;    // Draw the XABCD lines
input bool   InpZone      = true;    // Draw the reversal zone
input bool   InpLabels    = true;    // Point and pattern labels
input color  InpColBull   = C'38,166,98';   // Bullish colour
input color  InpColBear   = C'226,74,70';   // Bearish colour
input double InpArrowGap  = 0.3;     // Arrow distance from the candle (x ATR)

#include "SignalAlerts.mqh"

const string PRODUCT="Harmonic Signal Alerts";
const string PREFIX ="HMP_";

//--- series-indexed (0 = live bar), as every MT4 buffer
double   g_bull[],g_bear[],g_mbull[],g_mbear[];
HMParams g_p;
HMState  g_s;
int      g_start=0;                        // oldest-based chart bar of engine bar 0
int      g_fed=0;                          // chart bars fed so far
datetime g_alert_bar=0;

void Clear()
  {
   ObjectsDeleteAll(0,PREFIX);
   HMInit(g_s);
   g_fed=0;
  }

void Seg(const string name,const datetime t1,const double p1,const datetime t2,const double p2,const color clr,
         const ENUM_LINE_STYLE st,const int w)
  {
   if(ObjectFind(0,name)>=0)
      return;
   ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,w);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
  }

void Label(const string name,const datetime t,const double p,const string txt,const color clr,const bool above)
  {
   if(ObjectFind(0,name)>=0)
      return;
   ObjectCreate(0,name,OBJ_TEXT,0,t,p);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,above ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//--- series index of engine bar k (time[] is series-indexed)
int Ser(const int k,const int rates_total) { return(rates_total-1-(g_start+k)); }

//--- one completed pattern; oldest-based chart bars of the points are g_start + engine bar
void DrawPattern(const HMEvent &e,const datetime &time[],const int rates_total)
  {
   string id=PREFIX+IntegerToString((long)time[Ser(e.bar,rates_total)])+(e.dir>0 ? "b" : "s")+IntegerToString(e.pat)+"_";
   color clr=(e.dir>0 ? InpColBull : InpColBear);
   datetime tx=(e.xb>=0 ? time[Ser(e.xb,rates_total)] : 0),ta=time[Ser(e.ab,rates_total)],tb=time[Ser(e.bb,rates_total)];
   datetime tc=time[Ser(e.cb,rates_total)],td=time[Ser(e.db,rates_total)],te=time[Ser(e.bar,rates_total)];
   bool bull=(e.dir>0);
   if(InpLines)
     {
      if(e.xb>=0)
        {
         Seg(id+"xa",tx,e.xp,ta,e.ap,clr,STYLE_SOLID,2);
         Seg(id+"xb",tx,e.xp,tb,e.bp,clr,STYLE_DOT,1);
        }
      Seg(id+"ab",ta,e.ap,tb,e.bp,clr,STYLE_SOLID,2);
      Seg(id+"bc",tb,e.bp,tc,e.cp,clr,STYLE_SOLID,2);
      Seg(id+"cd",tc,e.cp,td,e.dp,clr,STYLE_SOLID,2);
      Seg(id+"bd",tb,e.bp,td,e.dp,clr,STYLE_DOT,1);
      if(e.xb<0)
         Seg(id+"ac",ta,e.ap,tc,e.cp,clr,STYLE_DOT,1);
     }
   if(InpZone)
     {
      string z=id+"prz";
      if(ObjectFind(0,z)<0)
        {
         datetime t2=te+(datetime)(10*PeriodSeconds());
         ObjectCreate(0,z,OBJ_RECTANGLE,0,tc,e.near_,t2,e.far_);
         ObjectSetInteger(0,z,OBJPROP_COLOR,clr);
         ObjectSetInteger(0,z,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,z,OBJPROP_FILL,false);
         ObjectSetInteger(0,z,OBJPROP_BACK,true);
         ObjectSetInteger(0,z,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,z,OBJPROP_HIDDEN,true);
         ObjectSetString(0,z,OBJPROP_TOOLTIP,StringFormat("%s %s reversal zone %s - %s",HMName(e.pat),bull ? "bullish" : "bearish",
                         DoubleToString(MathMin(e.near_,e.far_),_Digits),DoubleToString(MathMax(e.near_,e.far_),_Digits)));
        }
     }
   if(InpLabels)
     {
      //--- swing labels: lows below, highs above (X and B are lows of a bullish pattern). Named by the point, so
      //--- patterns sharing swings share one label; D lists every pattern that completed there
      string pt=PREFIX+"L"+(bull ? "b" : "s");
      if(e.xb>=0)
         Label(pt+IntegerToString((long)tx),tx,e.xp,"X",clr,!bull);
      Label(pt+IntegerToString((long)ta),ta,e.ap,"A",clr,bull);
      Label(pt+IntegerToString((long)tb),tb,e.bp,"B",clr,!bull);
      Label(pt+IntegerToString((long)tc),tc,e.cp,"C",clr,bull);
      string dn=pt+"D"+IntegerToString((long)td);
      if(ObjectFind(0,dn)>=0)
         ObjectSetString(0,dn,OBJPROP_TEXT,ObjectGetString(0,dn,OBJPROP_TEXT)+", "+HMName(e.pat));
      else
         Label(dn,td,e.dp,"D  "+HMName(e.pat),clr,!bull);
     }
  }

int OnInit()
  {
   if(!InpABCD && !InpGartley && !InpBat)
     {
      Print(PRODUCT,": switch on at least one pattern");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpLeft<1 || InpRight<1 || InpLeft+InpRight+2>=HM_N || InpTol<0 || InpTol>20 || InpPRZ<=0 || InpPRZ>20 ||
      InpHistory<100 || InpHistory>20000 || InpArrowGap<0)
     {
      Print(PRODUCT,StringFormat(": swing bars 1+ (left + right below %d), tolerance 0-20%%, zone 0-20%%, history 100-20000",HM_N-2));
      return(INIT_PARAMETERS_INCORRECT);
     }
   ZeroMemory(g_p);
   g_p.left=InpLeft; g_p.right=InpRight; g_p.tol=InpTol/100.0; g_p.prz=InpPRZ/100.0;
   g_p.use[HM_ABCD]=InpABCD; g_p.use[HM_GARTLEY]=InpGartley; g_p.use[HM_BAT]=InpBat;
   SetIndexBuffer(0,g_bull);
   SetIndexBuffer(1,g_bear);
   SetIndexBuffer(2,g_mbull);
   SetIndexBuffer(3,g_mbear);
   SetIndexStyle(0,DRAW_ARROW,EMPTY,EMPTY,InpColBull);
   SetIndexStyle(1,DRAW_ARROW,EMPTY,EMPTY,InpColBear);
   SetIndexArrow(0,233);
   SetIndexArrow(1,234);
   SetIndexStyle(2,DRAW_NONE);
   SetIndexStyle(3,DRAW_NONE);
   SetIndexLabel(0,"Bullish pattern");
   SetIndexLabel(1,"Bearish pattern");
   SetIndexLabel(2,"Bullish patterns (1 ABCD, 2 Gartley, 4 Bat)");
   SetIndexLabel(3,"Bearish patterns (1 ABCD, 2 Gartley, 4 Bat)");
   for(int b=0; b<4; b++)
      SetIndexEmptyValue(b,EMPTY_VALUE);
   IndicatorShortName(PRODUCT);
   Clear();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PREFIX);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<InpLeft+InpRight+3)
      return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated==0)                          // first run or the history changed: start again
     {
      Clear();
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(g_bull,EMPTY_VALUE);
      ArrayInitialize(g_bear,EMPTY_VALUE);
      ArrayInitialize(g_mbull,EMPTY_VALUE);
      ArrayInitialize(g_mbear,EMPTY_VALUE);
     }
   else
      for(int s=rates_total-1-(g_start+g_fed); s>=0; s--)
        { g_bull[s]=EMPTY_VALUE; g_bear[s]=EMPTY_VALUE; g_mbull[s]=EMPTY_VALUE; g_mbear[s]=EMPTY_VALUE; }
   bool live=(prev_calculated>0);
   string events="";
//--- feed every closed bar not fed yet, oldest first (i counts from the oldest bar, s is the series index)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      int s=rates_total-1-i;
      bool ev=HMFeed(g_s,g_p,high[s],low[s],close[s]);
      g_fed++;
      if(!ev)
         continue;
      int mb=0,ms=0;
      for(int k=0; k<g_s.nev; k++)
        {
         if(g_s.ev[k].dir>0)
            mb|=(1<<g_s.ev[k].pat);
         else
            ms|=(1<<g_s.ev[k].pat);
         DrawPattern(g_s.ev[k],time,rates_total);
        }
      double gap=InpArrowGap*iATR(NULL,0,14,s);
      if(mb>0)
        { g_bull[s]=low[s]-gap; g_mbull[s]=mb; }
      if(ms>0)
        { g_bear[s]=high[s]+gap; g_mbear[s]=ms; }
      if(live && i==rates_total-2 && time[s]>g_alert_bar)
        {
         g_alert_bar=time[s];
         string tf=TfName();
         if(mb>0)
            events+=StringFormat("Bullish %s reached its zone on %s %s",HMEventNames(g_s,1),_Symbol,tf);
         if(ms>0)
            events+=(events=="" ? "" : "; ")+StringFormat("Bearish %s reached its zone on %s %s",HMEventNames(g_s,-1),_Symbol,tf);
        }
     }
   if(events!="")
      SignalAlertMessage(PRODUCT,events);
   return(rates_total);
  }
//+------------------------------------------------------------------+
