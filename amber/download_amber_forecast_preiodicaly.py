# Periodically downloads Amber price forecasts.
# - Downloads 24 hrs @ 30 min and 1 hr @ 5 min, every 5 minutes.
# - Delay download by 30-45 sec, after the 5 minute mark, to ensure
#     prices update and to be nice to server. 
# - File name is NEM time (+1000) at start of download, e.g.
#     data/forecast_sa_30min/json/20250403_013132.json
# - Jiggles mouse ±1 px before each download to prevent Win10 idle suspend.

import os, re, sys, time, random, datetime, subprocess, winsound, ctypes

data_fold = os.path.dirname(os.path.abspath(__file__))
txt = open(os.path.join(data_fold, 'amber.ini')).read()
print(txt)
state  = re.search(r'state\s*=\s*(\S+)',  txt).group(1)
id = re.search(r'id\s*=\s*(\S+)', txt).group(1)
token  = re.search(r'token\s*=\s*(\S+)',  txt).group(1)
period = 5  # Delay between downloads (min)
rand_delay = datetime.timedelta(seconds=random.uniform(0, 15))  # random delay, 0-15 sec

def jiggle_mouse():
    """Move mouse 1 px right then back, to prevent Win10 idle suspend."""
    ctypes.windll.user32.mouse_event(0x0001, 1, 0, 0, 0)   # move +1 px
    ctypes.windll.user32.mouse_event(0x0001, -1, 0, 0, 0)  # move -1 px

def download_amber_forecast_once(state, id, token, span, rez):

    # Prepare folder and filename
    out_fold = os.path.join('data', f'forecast_{state}_{rez}min', 'json')
    os.makedirs(out_fold, exist_ok=True)
    dt = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=10)))
    dt = dt.replace(minute=dt.minute - dt.minute % 5, second=0, microsecond=0)  # Round to nearest 5 min
    file = os.path.join(out_fold, dt.strftime('%Y%m%d_%H%M') + '.json')

    # Build and run curl command
    url = f'https://api.amber.com.au/v1/sites/{id}/prices/current?previous={span[0]}&next={span[1]}&resolution={rez}'
    cmd = f'curl -sS -X GET "{url}" -H "Authorization: Bearer {token}" -o "{file}"'  # curl command
    print(f' {url}\n > {file}')  # Progress
    subprocess.call(cmd, shell=True)  # Download

while True:
    
    # Wait till next download time
    current_time = datetime.datetime.now()
    download_time = current_time.replace(minute=(current_time.minute // 5) * 5, second=0, microsecond=0) + datetime.timedelta(minutes=5.5) + rand_delay
    print(f'\nNext download: {download_time.replace(microsecond=0)}')  # Progress
    time.sleep((download_time - current_time).total_seconds())
    
    # Jiggle mouse to prevent Win10 idle suspend
    jiggle_mouse()

    # Initiate downloads
    try:
        download_amber_forecast_once(state, id, token, [48, 48], 30)  # Download ±24 hr @ 30 min
        download_amber_forecast_once(state, id, token, [12, 144], 5)  # Download ±1 hr @ 5 min
    except Exception as ex:
        print(ex, file=sys.stderr)  # Print errors to screen
        winsound.Beep(400, 200)