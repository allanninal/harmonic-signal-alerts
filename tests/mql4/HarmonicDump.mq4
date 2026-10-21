//+------------------------------------------------------------------+
//|                                                 HarmonicDump.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Test EA (not shipped): dumps the MT4 Harmonic Signal Alerts      |
//| buffers and checks repainting in the Strategy Tester (Dump4.mqh).|
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

#define DUMP4_BUFFERS "0,1,2,3"
#define DUMP4_PROBE   "0,1"
#define DUMP4_LIVE                     // the indicator scans only its last InpHistory bars

input bool   InpABCD    = true;
input bool   InpGartley = true;
input bool   InpBat     = true;
input int    InpLeft    = 10;
input int    InpRight   = 5;
input double InpTol     = 5.0;
input double InpPRZ     = 3.0;
input int    InpHistory = 3000;

double IndValue(const int buf,const int shift)
  {
   return(iCustom(NULL,0,"HarmonicSignalAlerts\\HarmonicSignalAlerts",InpABCD,InpGartley,InpBat,InpLeft,InpRight,InpTol,InpPRZ,
                  InpHistory,false,false,false,C'38,166,98',C'226,74,70',0.3,false,false,"alert.wav",false,false,buf,shift));
  }

#include <IndTest4/Dump4.mqh>
//+------------------------------------------------------------------+
