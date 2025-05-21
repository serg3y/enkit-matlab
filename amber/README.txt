Amber Energy price history in CSV

Columns:
 time:   Start time of each period
 spot:   Spot price provide by AEMO (cents/kWh)
 RTOU:   Residential time of use tariff (cents/kWh)
         Is defined using local time, which follow day light savings time
 RTOUCL: Residential time of use controlled load tariff (cents/kWh)
         Is defined using NEM time, which ignores day light savings time
 FIT:    Feed in tariff (cents/kWh)
         Same as spot price

Remarks:
- Price can be calculate using spot price using tariff info, eg
  price = spot*1.1105195 + tariff  (cents/kWh inc. GST)
  RTOU_tariff = 25.56422 (peak), 13.21122 (off-peak), 9.08622 (day)
- Tariff values are updated on 1 July

Source:
 - Amber support email, 2024-04-22 to 2024-11-29
 - Amber API, 2024-11-30 to 2025-04-30
   https://app.amber.com.au/developers/

Links:
  https://www.sapowernetworks.com.au/public/download.jsp?id=328119
  https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/
  https://www.sapowernetworks.com.au/your-power/billing/pricing-tariffs/electricity-tariffs/
  https://www.sapowernetworks.com.au/public/download.jsp?id=9508
