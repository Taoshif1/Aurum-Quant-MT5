#ifndef AURUM_POSITION_GUARD_MQH
#define AURUM_POSITION_GUARD_MQH
class AQPositionGuard
{
public:
   static int Count(string symbol,ulong magic)
   {
      int count=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      { ulong ticket=PositionGetTicket(i); if(ticket>0 && PositionGetString(POSITION_SYMBOL)==symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==magic) count++; }
      return count;
   }
   static bool CanOpen(string symbol,ulong magic,int maximum,string &reason)
   {
      if(maximum<1){reason="invalid position limit";return false;}
      if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING && PositionSelect(symbol))
      {reason="netting symbol already has a position";return false;}
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         ulong ticket=OrderGetTicket(i);if(ticket==0){reason="active order data unavailable";return false;}
         if(OrderGetString(ORDER_SYMBOL)==symbol &&
            (AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING || (ulong)OrderGetInteger(ORDER_MAGIC)==magic))
         {reason="existing pending order blocks entry";return false;}
      }
      int n=Count(symbol,magic); if(n>=maximum) { reason=StringFormat("position limit %d/%d",n,maximum); return false; } reason="OK"; return true; }
   static bool OwnOrder(ulong ticket,string symbol,ulong magic)
   { return ticket>0 && OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==symbol && (ulong)OrderGetInteger(ORDER_MAGIC)==magic; }
   static bool OwnHistoryOrder(ulong ticket,string symbol,ulong magic)
   { return ticket>0 && HistoryOrderSelect(ticket) && HistoryOrderGetString(ticket,ORDER_SYMBOL)==symbol && (ulong)HistoryOrderGetInteger(ticket,ORDER_MAGIC)==magic; }
   static bool OwnDeal(ulong ticket,string symbol,ulong magic)
   { return ticket>0 && HistoryDealSelect(ticket) && HistoryDealGetString(ticket,DEAL_SYMBOL)==symbol && (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)==magic; }
};
#endif
