# Download AEMO historic electricity prices
# https://aemo.com.au/energy-systems/electricity/national-electricity-market-nem/data-nem/aggregated-data
# https://aemo.com.au/aemo/data/nem/priceanddemand

import os
import time
import subprocess
from datetime import datetime
from pathlib import Path

states = ["NSW", "QLD", "VIC", "SA", "TAS"]
now = datetime.now()

for state in states:
    for year in range(2000, 2030):
        for month in range(1, 13):
            if datetime(year, month, 1) < now:

                # Set folder and filename
                folder = Path(state)
                filename = f"PRICE_AND_DEMAND_{year}{month:02d}_{state}1.csv"
                filepath = folder / filename

                # Download if file is missing or was downloaded before the month finished
                if month < 12:
                    next_month_second = datetime(year, month + 1, 2)
                else:
                    next_month_second = datetime(year + 1, 1, 2)

                need_download = (
                    not filepath.exists() or
                    datetime.fromtimestamp(filepath.stat().st_mtime) < next_month_second
                )

                if need_download:
                    # Create folder if it doesn't exist
                    folder.mkdir(exist_ok=True)

                    # Construct URL and curl command
                    url = f"https://aemo.com.au/aemo/data/nem/priceanddemand/{filename}"
                    cmd = f'curl -sS "{url}" -o "{filepath}"'

                    print(cmd)       # Show progress
                    subprocess.run(cmd, shell=True)  # Download
                    time.sleep(1)    # Be nice to server
