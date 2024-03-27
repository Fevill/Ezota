#include "EzotaInputs.mqh"

int fastHandles;
int slowHandles;
int stHandles; //Supertrend
double fastBuffer[];
double slowBuffer[];
double stBuffer[];
bool lastActionWasBuy = false;

// Initializes moving averages and checks inputs
int InitializeIndicatorsAndInputs()
{
  // Check user input
  if (InpFastPeriod <= 0)
  {
    Alert("Fast period <= 0");
    return INIT_PARAMETERS_INCORRECT;
  }
  if (InpSlowPeriod <= 0)
  {
    Alert("Slow period <= 0");
    return INIT_PARAMETERS_INCORRECT;
  }
  if (InpFastPeriod >= InpSlowPeriod)
  {
    Alert("Fast period >= Slow period");
    return INIT_PARAMETERS_INCORRECT;
  }
  if (InpStopLoss <= 0)
  {
    Alert("Stop lost <= 0");
    return INIT_PARAMETERS_INCORRECT;
  }
  if (InpTakeProfit <= 0)
  {
    Alert("Take profit <= 0");
    return INIT_PARAMETERS_INCORRECT;
  }
  if (InpSymbol == "")
  {
    Alert("Symbol in not define");
    return INIT_PARAMETERS_INCORRECT;
  }

  // Create Handles
  fastHandles = iMA(InpSymbol, PERIOD_CURRENT, InpFastPeriod, 0, MODE_EMA, PRICE_CLOSE);

  if (fastHandles == INVALID_HANDLE)
  {
    Alert("Failed to create fast handle");
    return INIT_FAILED;
  }

  slowHandles = iMA(InpSymbol, PERIOD_CURRENT, InpSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
  if (slowHandles == INVALID_HANDLE)
  {
    Alert("Failed to create slow handle");
    return INIT_FAILED;
  }
  
  stHandles = iCustom(InpSymbol, InpTimeframe, "Supertrend.ex5",InpPeriods,InpMultiplier);
  if (stHandles == INVALID_HANDLE)
  {
    Alert("Failed to create supertrend handle");
    return INIT_FAILED;
  }
  
  ArraySetAsSeries(fastBuffer, true);
  ArraySetAsSeries(slowBuffer, true);
  return (INIT_SUCCEEDED);
}

// Releases indicator handles
void DeinitializeIndicators()
{
  if (fastHandles != INVALID_HANDLE)
  {
    IndicatorRelease(fastHandles);
  }
  if (slowHandles != INVALID_HANDLE)
  {
    IndicatorRelease(slowHandles);
  }
  if (stHandles != INVALID_HANDLE)
  {
    IndicatorRelease(stHandles);
  }
}

// Copies the latest indicator data into buffers
void CopyBufferIndicator()
{
  int values = CopyBuffer(fastHandles, 0, 0, 2, fastBuffer);
  if (values != 2)
  {
    Print("Not enough data for fast moving average");
    return;
  }
  values = CopyBuffer(slowHandles, 0, 0, 2, slowBuffer);
  if (values != 2)
  {
    Print("Not enough data for slow moving average");
    return;
  }
   values = CopyBuffer(stHandles, 0, 0, 3, stBuffer);
  if (values != 3)
  {
    Print("Not enough data for supertrend");
    return;
  }
}
