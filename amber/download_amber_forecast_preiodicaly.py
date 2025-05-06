# Periodically downloads Amber price forecasts.
# - Downloads 24 hrs @ 30 min and 1 hr @ 5 min, every 5 minutes.
# - Delay download by 30–45 sec, after the 5 minute mark, to ensure
#     prices update and to be nice to server. 
# - File name is NEM time (+1000) at start of download, e.g.
#     forecast/sa_30min/json/20250403_013132.json

import os
import re
import sys
import time
import random
import datetime
import subprocess

txt = open('amber.ini').read()
state  = re.search(r'state\s*=\s*(\S+)',  txt).group(1)
siteId = re.search(r'siteId\s*=\s*(\S+)', txt).group(1)
token  = re.search(r'token\s*=\s*(\S+)',  txt).group(1)

period = 5  # Delay between downloads (min)
rand_delay = datetime.timedelta(seconds=random.uniform(0, 15))  # random delay, 0-15 sec

def download_amber_forecast_once(state, siteId, token, span, rez):
    # Download current Amber price forecast.

    fold = os.path.join('forecast', f'forecast_{state}_{rez}min', 'json')
    os.makedirs(fold, exist_ok=True)

    # Download
    start_time = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=10)))  # NEM time (+1000)
    file = os.path.join(fold, start_time.strftime('%Y%m%d_%H%M%S') + '.json')
    url = f'https://api.amber.com.au/v1/sites/{siteId}/prices/current?previous={span[0]}&next={span[1]}&resolution={rez}'
    cmd = f'curl -sS -X GET "{url}" -H "Authorization: Bearer {token}" -o "{file}"'  # curl command
    print(cmd)  # Progress
    subprocess.call(cmd, shell=True)  # Download

while True:
    system_time = datetime.datetime.now()
    minutes_since_hour = system_time.minute
    delay_minutes = period - (minutes_since_hour % period) + 0.5
    offset = datetime.timedelta(minutes=delay_minutes) + rand_delay
    download_time = system_time.replace(second=0, microsecond=0) + offset

    print(f'Next download: {download_time}')  # Progress

    sleep_seconds = (download_time - system_time).total_seconds()
    if sleep_seconds > 0:
        time.sleep(sleep_seconds)

    try:
        download_amber_forecast_once(state, siteId, token, [48, 48], 30)  # Download ±24 hr @ 30 min
        download_amber_forecast_once(state, siteId, token, [12, 12], 5)   # Download ±1 hr @ 5 min
    except Exception as ex:
        print(ex, file=sys.stderr)  # Print errors to screen
