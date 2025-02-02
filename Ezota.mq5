#include <Trade\Trade.mqh>
#include "EzotaInputs.mqh"
#include "EzotaIndicators.mqh"
#include "EzotaTradeManagement.mqh"
#include "EzotaUtilities.mqh"

double Lots = 1.0;
double TpFactor = 1.2;
CTrade _trade;
int totalBars;
ulong _ticket;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Initialize indicators and check input parameters
  totalBars = iBars(InpSymbol, InpTimeframe);
  return InitializeIndicatorsAndInputs();
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  DeinitializeIndicators();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
{
  // Main trading logic
  // PerformTradingOperations();
  CopyBufferIndicator();
  int bars = iBars(InpSymbol, InpTimeframe);
  if (totalBars != bars)
  {
    totalBars = bars;
    double cl1 = iClose(InpSymbol, InpTimeframe, 1);
    double cl2 = iClose(InpSymbol, InpTimeframe, 2);

    if (PositionSelectByTicket(_ticket))
    {
      double sl = stBuffer[1];
      sl = NormalizeDouble(sl, _Digits);

      double posSl = PositionGetDouble(POSITION_SL);
      double posTp = PositionGetDouble(POSITION_TP);
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
        if (sl > posSl)
        {
          if (_trade.PositionModify(_ticket, sl, posTp))
          {
            Print(__FUNCTION__, " > Pos #", _ticket, " was modify...");
          }
        }
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
      {
        if (sl < posSl || posSl == 0)
        {
          if (_trade.PositionModify(_ticket, sl, posTp))
          {
            Print(__FUNCTION__, " > Pos #", _ticket, " was modify...");
          }
        }
      }
    }

    if (cl1 > stBuffer[1] && cl2 < stBuffer[0])
    {
      Print(__FUNCTION__, " > Buy Signal ...");

      if (_ticket > 0)
      {
        if (PositionSelectByTicket(_ticket))
        {
          if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
          {
            if (_trade.PositionClose(_ticket))
            {
              Print(__FUNCTION__, " > Pos #", _ticket, " was closed...");
            }
          }
        }
      }

      double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
      ask = NormalizeDouble(ask, _Digits);

      double sl = stBuffer[1];
      sl = NormalizeDouble(sl, _Digits);

      double tp = ask + (ask - sl) * TpFactor;
      tp = NormalizeDouble(tp, _Digits);

      if (_trade.Buy(Lots, InpSymbol, ask, sl, tp))
      {
        if (_trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
          _ticket = _trade.ResultOrder();
        }
      };
    }

    else if (cl1 < stBuffer[1] && cl2 > stBuffer[0])
    {
      Print(__FUNCTION__, " > Sell Signal ...");
      if (_ticket > 0)
      {
        if (PositionSelectByTicket(_ticket))
        {
          if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
          {
            if (_trade.PositionClose(_ticket))
            {
              Print(__FUNCTION__, " > Pos #", _ticket, " was closed...");
            }
          }
        }
      }

      double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
      bid = NormalizeDouble(bid, _Digits);

      double sl = stBuffer[1];
      sl = NormalizeDouble(sl, _Digits);

      double tp = bid - (sl - bid) * TpFactor;
      tp = NormalizeDouble(tp, _Digits);

      if (_trade.Sell(Lots, InpSymbol, bid, sl, tp))
      {
        if (_trade.ResultRetcode() == TRADE_RETCODE_DONE)
        {
          _ticket = _trade.ResultOrder();
        }
      };
    }
  }
}
