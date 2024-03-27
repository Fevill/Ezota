#include "EzotaUtilities.mqh"
#include "EzotaIndicators.mqh"

CTrade trade;
datetime bullishCrossStartTime = 0; // Pour le croisement haussier
datetime bearishCrossStartTime = 0; // Pour le croisement baissier
datetime openTimeBuy = 0;
datetime openTimeSell = 0;

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

void MoveToBreakEven(double breakEvenTriggerPips, double breakEvenPips)
{
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    if (PositionSelectByTicket(positionTicket) && PositionGetString(POSITION_SYMBOL) == InpSymbol)
    {
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double pointSize = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
      double currentTP = PositionGetDouble(POSITION_TP);
      double breakEvenPrice;

      if (currentTP > 0)
      {

        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
          // Pour les positions d'achat, vérifiez si le profit a atteint le seuil défini
          double pipsProfit = currentProfit / (pointSize * SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_CONTRACT_SIZE));
          if (pipsProfit >= breakEvenTriggerPips)
          {
            // Déplacez le Stop Loss au-dessus du prix d'ouverture d'un nombre spécifié de pips
            breakEvenPrice = openPrice + breakEvenPips * pointSize;
            trade.PositionModify(positionTicket, breakEvenPrice, currentTP);
            Print("Stop Loss déplacé à break-even pour la position d'achat ", positionTicket);
          }
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
          // Répétez la logique pour les positions de vente, en ajustant les calculs comme nécessaire
          double pipsProfit = currentProfit / (pointSize * SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_CONTRACT_SIZE));
          if (pipsProfit >= breakEvenTriggerPips)
          {
            // Déplacez le Stop Loss en dessous du prix d'ouverture d'un nombre spécifié de pips
            breakEvenPrice = openPrice - breakEvenPips * pointSize;
            trade.PositionModify(positionTicket, breakEvenPrice, currentTP);
            Print("Stop Loss déplacé à break-even pour la position de vente ", positionTicket);
          }
        }
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

// Contains functions related to opening, closing, and modifying trades
void PerformTradingOperations()
{
  CopyBufferIndicator();
  display();
  ManagePosition();
  MoveToBreakEven(300, 10);
  AdjustTrailingStop(InpSymbol, InpTrailingStop);
  // Refer to the ManagePosition and related functions in the original script
}
