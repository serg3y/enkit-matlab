# Batch download daily 5 minute Powerwall data from Teslamotors.com to csv files.
# Reference: https://tesla-api.timdorr.com/energy-products/energy/history#get-api-1-energy_sites-site_id-calendar_history

# One time setup: pip install requests pandas tzlocal
import requests, pandas, tzlocal, datetime, os, json, time, urllib.parse

# Get your token from: https://chromewebstore.google.com/detail/access-token-generator-fo/djpjpanpjaimfjalnpkppkjiedmgpjpe
refresh_token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjI5Skh4dlVBVVFfbDlBVXFhcHBrV2dLRDhRRSJ9.eyJpc3MiOiJodHRwczovL2F1dGgudGVzbGEuY29tL29hdXRoMi92MyIsImF1ZCI6Imh0dHBzOi8vYXV0aC50ZXNsYS5jb20vb2F1dGgyL3YzL3Rva2VuIiwiaWF0IjoxNzQ2ODgwNjg0LCJzY3AiOlsib3BlbmlkIiwib2ZmbGluZV9hY2Nlc3MiXSwib3VfY29kZSI6Ik5BIiwiZGF0YSI6eyJ2IjoiMSIsImF1ZCI6Imh0dHBzOi8vb3duZXItYXBpLnRlc2xhbW90b3JzLmNvbS8iLCJzdWIiOiIxNzEwZjYwYS01ZmJhLTRmNWUtYjY1Yi00OWU4MTk0MWE3OWEiLCJzY3AiOlsib3BlbmlkIiwiZW1haWwiLCJvZmZsaW5lX2FjY2VzcyJdLCJhenAiOiJvd25lcmFwaSIsImFtciI6WyJwd2QiLCJwaG9uZTJmYSJdLCJhdXRoX3RpbWUiOjE3NDY4ODA2Njd9fQ.IrnXE1kZ2ilZvmWJmoQtqXI7Z6MPnAqlho00tU5llCXTg2uJHYrTh3BB7x_D5Io6_OfKJl5JP6_wwH1xcVbzhPey2Ts6_gnnmgY7MSNQeRHsDvEiEfso0YnnyzLIK7C2khgte4n1KqoRWdhTT5rnYC_jtKoqnxWzR51DgifWYtiJIYvqot0jCcKEMvdoYG7NNDDAmxv66uaGtDVWuAUIMFUzcd7T-D-rIcbmLQgs2Uphnq5tkpKlCGDY8M7WqFMIi3FrZxFP6p89dgtgWJ2TnyRmeCBWv-CN8mqg6fKJBxRkQslxc9FC04uQxLeI9qOBslkT9z5nR5vy2SPE3Yxhfw'
start_date = datetime.datetime(2024,1,1) # Start date (time of day is ignored)
stop_date = datetime.datetime.now() # Stop date (time of day is ignored)
data_fold = os.path.dirname(os.path.abspath(__file__)) # Output folder
time_zone = 'Local' # Powerwall timezone, eg 'Australia/Adelaide', or 'Local' to use PC timezone

# Prepare
auth = requests.post('https://auth.tesla.com/oauth2/v3/token', data={'grant_type':'refresh_token', 'client_id':'ownerapi', 'refresh_token':refresh_token}).json() # Authenticate
opt  = {'Authorization': 'Bearer ' + auth['access_token']} # Download setting
info = requests.get('https://owner-api.teslamotors.com/api/1/products', headers=opt).json() # Download site info
site_id = str(info['response'][0]['energy_site_id'])
os.makedirs(os.path.join(data_fold, site_id), exist_ok=True) # Create output folder, if it does not exist
with open(os.path.join(data_fold, site_id + "_info.json"), 'w') as info_file: json.dump(info['response'], info_file, indent=4)
if time_zone == 'Local':
    time_zone = tzlocal.get_localzone()

# Main
while start_date < stop_date - datetime.timedelta(days=1):
    end_date = (start_date + datetime.timedelta(seconds=86399)).replace(tzinfo = time_zone) # Set end_date to be 1sec before end of the day, must include correct timezone for the region including daylight savings, eg '2023-01-01T23:59:59+10:30' or '2023-01-01T13:29:59Z' (for Australia/Adelaide in summer)
    end_date_str = end_date.strftime('%Y-%m-%dT%H:%M:%S') + end_date.strftime('%z')[:3] + ':' + end_date.strftime('%z')[3:]
    url = f"https://owner-api.teslamotors.com/api/1/energy_sites/{site_id}/calendar_history?kind=power&end_date={urllib.parse.quote(end_date_str)}" # eg 'https://owner-api.teslamotors.com/api/1/energy_sites/2282236/calendar_history?kind=power&end_date=2023-12-20T23%3A59%3A59%2B10%3A30'
    csv = os.path.join(data_fold, site_id, start_date.strftime('%Y%m%d') + ".csv")
    if not os.path.isfile(csv):
        print(f'{url} > {csv}') # Show progress
        data_response = requests.get(url, headers=opt).json()
        data = data_response.get('response', {})
        if data:
            assert data['installation_time_zone'] == end_date.tzinfo.key # Check that time zones match (optional)
            data = pandas.DataFrame(data['time_series']) # Convert data to a table
            data = data.round(3) # Round values to 3 decimal placed (optional) 
            data = data.astype(str).replace(to_replace="0\.0$", value="0", regex=True) # Replace python's 0.0 with just 0 (optional)
            data.to_csv(csv, index=False) # Write to csv
            time.sleep(1) # Avoid "Too Many Requests"
    start_date += datetime.timedelta(days=1)