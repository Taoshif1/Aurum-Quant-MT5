#ifndef AURUM_TESTER_STATISTICS_MQH
#define AURUM_TESTER_STATISTICS_MQH
struct AQTesterMetrics
{
   double net_profit,gross_profit,gross_loss,profit_factor,expected_payoff,equity_drawdown,equity_relative_drawdown,recovery_factor,sharpe;
   int trades,winners,losers,max_consecutive_losses;
};
class AQTesterResearch
{
public:
   static void Capture(AQTesterMetrics &m)
   {
      m.net_profit=TesterStatistics(STAT_PROFIT);m.gross_profit=TesterStatistics(STAT_GROSS_PROFIT);m.gross_loss=TesterStatistics(STAT_GROSS_LOSS);
      m.profit_factor=TesterStatistics(STAT_PROFIT_FACTOR);m.expected_payoff=TesterStatistics(STAT_EXPECTED_PAYOFF);m.equity_drawdown=TesterStatistics(STAT_EQUITY_DD);
      m.equity_relative_drawdown=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);m.recovery_factor=TesterStatistics(STAT_RECOVERY_FACTOR);m.sharpe=TesterStatistics(STAT_SHARPE_RATIO);
      m.trades=(int)TesterStatistics(STAT_TRADES);m.winners=(int)TesterStatistics(STAT_PROFIT_TRADES);m.losers=(int)TesterStatistics(STAT_LOSS_TRADES);m.max_consecutive_losses=(int)TesterStatistics(STAT_MAX_CONLOSS_TRADES);
   }
   static double UntunedDiagnosticScore(const AQTesterMetrics &m) { return 0.0; }
   static void Log(const AQTesterMetrics &m)
   { PrintFormat("AURUM|TESTER_STATS|net=%.2f|gross_profit=%.2f|gross_loss=%.2f|pf=%.4f|expected=%.4f|equity_dd=%.2f|equity_dd_pct=%.2f|recovery=%.4f|sharpe=%.4f|trades=%d|wins=%d|losses=%d|max_consecutive_losses=%d",m.net_profit,m.gross_profit,m.gross_loss,m.profit_factor,m.expected_payoff,m.equity_drawdown,m.equity_relative_drawdown,m.recovery_factor,m.sharpe,m.trades,m.winners,m.losers,m.max_consecutive_losses); }
};
#endif
