Australian Energy Market Operator (AEMO) provides National Electricity Market (NEM) price and demand history data going back to 1998.

Columns:
  REGION: Region name, eg "NSW1" "QLD1" "VIC1" "SA1" "TAS1"
  SETTLEMENTDATE: Marks the end of a trading interval in NEM time (+10:00)
  TOTALDEMAND: Operational Demand of the Grid in MW
  RRP: Regional Reference Price (RRP) is the spot price in $/MWh (exGST).
  PERIODTYPE: "TRADE" indicates settlement price, ie not a forecast.

Remarks:
 - To compute spot price in cents/kWh (incGST), use the following:
   spot =  RRP / 10 * 1.1
 - Sampling period changed from 30 min to 5 minutes on 2021-10-01 00:00

Example data:
  https://aemo.com.au/aemo/data/nem/priceanddemand/PRICE_AND_DEMAND_202501_sa1.csv
  REGION,SETTLEMENTDATE,TOTALDEMAND,RRP,PERIODTYPE
  SA1,2025/01/01 00:05:00,1379.47,141.48,TRADE
  SA1,2025/01/01 00:10:00,1367.61,136.59,TRADE
  SA1,2025/01/01 00:15:00,1379.99,142.05,TRADE
  ...

Source:
  https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data
  
Other Links:
  NEM dashboard: https://www.aemo.com.au/Energy-systems/Electricity/National-Electricity-Market-NEM/Data-NEM/Data-Dashboard-NEM