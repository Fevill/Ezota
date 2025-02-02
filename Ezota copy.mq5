//+------------------------------------------------------------------+
//|                                                        Ezota.mq5 |
//|                                                           FEVILL |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Include                                  |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
//--- input parameters
input int InpFastPeriod = 20;  // Fast period
input int InpSlowPeriod = 200; // Slow period
input int InpStopLoss = 10;    // Stop loss in pips
input int InpTakeProfit = 20;  // Take profit in pips
input int InpTakeProfit1 = 20; // Premier niveau de Take Profit en pips
input int InpTakeProfit2 = 40; // Deuxième niveau de Take Profit en pips
input int InpTakeProfit3 = 60; // Troisième niveau de Take Profit en pips
input int InpTrailingStop = 150;   // Trailing Stop in pips
input string InpSymbol = "XAUUSD"; // Currency

//+------------------------------------------------------------------+
//| Global variable                                                  |
//+------------------------------------------------------------------+
int fastHandles;
int slowHandles;
double fastBuffer[];
double slowBuffer[];
bool lastActionWasBuy = false;
datetime lastBullishCrossoverTime = 0;
datetime lastBearishCrossoverTime = 0;
datetime bullishCrossStartTime = 0; // Pour le croisement haussier
datetime bearishCrossStartTime = 0; // Pour le croisement baissier

datetime openTimeBuy = 0;
datetime openTimeSell = 0;
CTrade trade;
MqlTick tickInfo;

int OnInit()
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
  ArraySetAsSeries(fastBuffer, true);
  ArraySetAsSeries(slowBuffer, true);
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
  if (fastHandles != INVALID_HANDLE)
  {
    IndicatorRelease(fastHandles);
  }
  if (slowHandles != INVALID_HANDLE)
  {
    IndicatorRelease(slowHandles);
  }
}

//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
// Example function to dynamically calculate the volume
double CalculateDynamicVolume(string symbol)
{
  // Placeholder for dynamic volume calculation
  // Replace with your own logic
  double volume = 0.1; // Default volume
  return volume;
}

//+------------------------------------------------------------------+
//| Display                                                          |
//+------------------------------------------------------------------+
void display()
{
  Comment("fast[0]: ", fastBuffer[0], "\n", "fast[1]: ", fastBuffer[1], "\n", "slow[0]: ", slowBuffer[0], "\n", "slow[1]: ", slowBuffer[1]);
}

//+------------------------------------------------------------------+
//| CopyBuffer indicator                                             |
//+------------------------------------------------------------------+
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
}

//+------------------------------------------------------------------+
//| Manage Position                                                  |
//+------------------------------------------------------------------+

// Vérifie un croisement haussier
bool CheckBullishCrossover()
{
  datetime currentTime = TimeCurrent();

  if (!lastActionWasBuy && ((fastBuffer[1] <= slowBuffer[1] && fastBuffer[0] > slowBuffer[0]) ||
                            (fastBuffer[0] > slowBuffer[0] && fastBuffer[1] > slowBuffer[1])))
  {

    if (bullishCrossStartTime == 0)
    {
      bullishCrossStartTime = currentTime; // Commencer le suivi du temps
      Print("Bullish crossover initiation detected, starting timer.");
      return false; // Attendre pour confirmer le croisement
    }
    else if (currentTime - bullishCrossStartTime >= 60)
    {
      bullishCrossStartTime = 0; // Réinitialiser pour le prochain croisement
      lastActionWasBuy = true;   // Marquer qu'une action d'achat a été effectuée
      Print("Bullish crossover confirmed after 5 minutes, setting last action to BUY.");
      return true; // Confirmer le croisement haussier
    }
  }
  else
  {
    if (bullishCrossStartTime != 0)
    {
      Print("Bullish crossover condition no longer met, resetting timer.");
    }
    bullishCrossStartTime = 0; // Réinitialiser si le croisement n'est pas confirmé
  }

  return false;
}

// Vérifie un croisement baissier
bool CheckBearishCrossover()
{
  datetime currentTime = TimeCurrent();

  if (lastActionWasBuy && ((fastBuffer[1] >= slowBuffer[1] && fastBuffer[0] < slowBuffer[0]) ||
                           (fastBuffer[0] < slowBuffer[0] && fastBuffer[1] < slowBuffer[1])))
  {

    if (bearishCrossStartTime == 0)
    {
      bearishCrossStartTime = currentTime; // Commencer le suivi du temps
      Print("Bearish crossover initiation detected, starting timer.");
      return false; // Attendre pour confirmer le croisement
    }
    else if (currentTime - bearishCrossStartTime >= 300)
    {
      bearishCrossStartTime = 0; // Réinitialiser pour le prochain croisement
      lastActionWasBuy = false;  // Marquer qu'une action de vente a été effectuée
      Print("Bearish crossover confirmed after 5 minutes, setting last action to SELL.");
      return true; // Confirmer le croisement baissier
    }
  }
  else
  {
    if (bearishCrossStartTime != 0)
    {
      Print("Bearish crossover condition no longer met, resetting timer.");
    }
    bearishCrossStartTime = 0; // Réinitialiser si le croisement n'est pas confirmé
  }

  return false;
}

// Fonction pour ouvrir des positions, avec une vérification supplémentaire pour le nouveau croisement
void OpenPosition(bool isBuy)
{
  datetime currentTime = TimeCurrent();
  double price = SymbolInfoDouble(InpSymbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
  if (price <= 0)
    return; // Assurez-vous que le prix est un nombre positif

  double pointSize = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
  int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
  double pipSize = pointSize * 10;
  if (digits == 3 || digits == 5)
    pipSize = pointSize * 10;
  else if (digits == 2 || digits == 4)
    pipSize = pointSize;
  int tpLevels[] = {InpTakeProfit1, InpTakeProfit2, InpTakeProfit3, 0, 0};
  // double sl = isBuy ? (price - InpStopLoss * pipSize) : (price + InpStopLoss * pipSize);
  // double tp = isBuy ? (price + InpTakeProfit * pipSize) : (price - InpTakeProfit * pipSize);

  double volume = CalculateDynamicVolume(InpSymbol);
  ENUM_ORDER_TYPE type = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

  if ((isBuy && openTimeBuy != currentTime) || (!isBuy && openTimeSell != currentTime))
  {
    for (int tradeCount = 0; tradeCount < 5; tradeCount++)
    { // Boucle pour ouvrir 5 trades

      double tpPips = tpLevels[tradeCount]; // Sélectionnez le TP pour chaque trade basé sur le tableau tpLevels
      double tp = tradeCount < 3 ? isBuy ? (price + tpPips * pipSize) : (price - tpPips * pipSize) : 0;
      double sl = isBuy ? (price - InpStopLoss * pipSize) : (price + InpStopLoss * pipSize);

      if (isBuy)
        openTimeBuy = currentTime;
      else
        openTimeSell = currentTime;

      bool isOrderPlaced = trade.PositionOpen(InpSymbol, type, volume, price, NormalizeDouble(sl, digits), NormalizeDouble(tp, digits), "Ezota EA");
      if (!isOrderPlaced)
      {
        Print("Failed to open ", (isBuy ? "BUY" : "SELL"), " position for ", InpSymbol, ". Error code: ", GetLastError());
      }
      else
      {
        Print("Ouverture d'une position ", isBuy ? "d'achat" : "de vente", " pour ", InpSymbol, " avec SL=", sl, " TP=", tp);
      }
    }
  }
}

void CloseOppositePositions(bool isBuy)
{
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    if (PositionSelectByTicket(positionTicket))
    {

      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if (isBuy && positionType == POSITION_TYPE_SELL && InpSymbol == _Symbol)
      {
        // Fermer la position de vente si on veut acheter
        trade.PositionClose(positionTicket);
        Print("Fermeture de la position de vente pour ", InpSymbol);
      }
      else if (!isBuy && positionType == POSITION_TYPE_BUY && InpSymbol == _Symbol)
      {
        // Fermer la position d'achat si on veut vendre
        trade.PositionClose(positionTicket);
        Print("Fermeture de la position d'achat pour ", InpSymbol);
      }
    }
  }
}



void AdjustTrailingStop(string symbol, double trailingStopPips)
{
  double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
  trailingStopPips *= pipSize; // Convertir les pips en points

  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    if (PositionSelectByTicket(positionTicket) && PositionGetString(POSITION_SYMBOL) == symbol)
    {
      double currentTP = PositionGetDouble(POSITION_TP); // Obtenez le TP actuel

      // Continuer seulement si le TP est non défini ou égal à zéro
      if (currentTP == 0)
      {
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = SymbolInfoDouble(symbol, PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SYMBOL_BID : SYMBOL_ASK);
        double newSL = 0;

        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
          newSL = currentPrice - trailingStopPips; // Pour les achats, ajustez le SL à 300 pips sous le prix actuel
          // Ne déplacez le SL que s'il est plus favorable et ne pas ramener en dessous du prix d'ouverture
          if (newSL > openPrice && (currentSL == 0 || newSL > currentSL))
          {
            trade.PositionModify(positionTicket, newSL, 0);
            Print("Trailing stop ajusté pour l'achat: ticket ", positionTicket, " à ", newSL / pipSize, " pips.");
          }
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
          newSL = currentPrice + trailingStopPips; // Pour les ventes, ajustez le SL à 300 pips au-dessus du prix actuel
          // Ne déplacez le SL que s'il est plus favorable et ne pas ramener au-dessus du prix d'ouverture
          if (newSL < openPrice && (currentSL == 0 || newSL < currentSL))
          {
            trade.PositionModify(positionTicket, newSL, 0);
            Print("Trailing stop ajusté pour la vente: ticket ", positionTicket, " à ", newSL / pipSize, " pips.");
          }
        }
      }
    }
  }
}

// Gère la logique de position basée sur les croisements
void ManagePosition()
{
  if (CheckBullishCrossover())
  {
    CloseOppositePositions(true);
    OpenPosition(true); // Vérifie et ouvre une position d'achat si possible
  }
  else if (CheckBearishCrossover())
  {
    CloseOppositePositions(false);
    OpenPosition(false); // Vérifie et ouvre une position de vente si possible
  }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
{
  CopyBufferIndicator();
  display();
  ManagePosition();
  MoveToBreakEven(300, 10);
  AdjustTrailingStop(InpSymbol, InpTrailingStop);
}