# Batch download daily 5 minute Powerwall data from Teslamotors.com to csv files.
# Reference: https://tesla-api.timdorr.com/energy-products/energy/history#get-api-1-energy_sites-site_id-calendar_history

# Get your token from: https://chromewebstore.google.com/detail/access-token-generator-fo/djpjpanpjaimfjalnpkppkjiedmgpjpe
$TOKEN = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjI5Skh4dlVBVVFfbDlBVXFhcHBrV2dLRDhRRSJ9.eyJpc3MiOiJodHRwczovL2F1dGgudGVzbGEuY29tL29hdXRoMi92MyIsImF6cCI6Im93bmVyYXBpIiwic3ViIjoiMTcxMGY2MGEtNWZiYS00ZjVlLWI2NWItNDllODE5NDFhNzlhIiwiYXVkIjpbImh0dHBzOi8vb3duZXItYXBpLnRlc2xhbW90b3JzLmNvbS8iLCJodHRwczovL2F1dGgudGVzbGEuY29tL29hdXRoMi92My91c2VyaW5mbyJdLCJzY3AiOlsib3BlbmlkIiwiZW1haWwiLCJvZmZsaW5lX2FjY2VzcyJdLCJhbXIiOltdLCJleHAiOjE3NDY5MTEzMDYsImlhdCI6MTc0Njg4MjUwNiwib3VfY29kZSI6Ik5BIiwibG9jYWxlIjoiZW4tQVUifQ.pkSTxCEXjuasZFcw4X6J8x5wh-CDnmegqdfyxGqlOqz_oFNryIQkTXLpPBgTBx8UDtIpdLaStKFCjmp_F3yp4Opcr7VHU5ISPsEWsuEq_ykx5Lje0fMn0FgrQXlBrJqWmLaoo3ZgoFcEM4Qo4EX2eTkEDM8SxlahPXmtB7G6oN7r7HYeVflYVqkY22jUaPgEjmk8v911rx99OgtOJ9A8M19Yv_OCb_ejutnHf9PYXgjAz8-TU58FOGDpeJrvW1uHagMX5hZpSKw_NwwDWJQv0kXZPqofUlpFQwl1SRX-YxaWXahOuB__Pk6hL1v-DSo0Bk_ff6wb1xqEFf0dyO1sXg'
# $START = Get-Date '2019-07-30' # Start date (time of day is ignored)
$START = Get-Date '2024-01-01' # Start date (time of day is ignored)
$STOP  = Get-Date # Stop date (time of day is ignored)
$FOLD  = 'C:\Powerwall\data\ps' # Output folder
$ZONE  = 'Local' # Powerwall timezone, eg 'Australia/Adelaide', or 'Local' to use PC timezone

# Prepare
$auth = Invoke-RestMethod -Uri "https://auth.tesla.com/oauth2/v3/token" -Method Post -Body @{grant_type="refresh_token"; client_id="ownerapi"; refresh_token=$TOKEN}  # Authenticate
$opt  = @{ Authorization = "Bearer $($auth.access_token)" } # Download setting
$info = Invoke-RestMethod -Uri "https://owner-api.teslamotors.com/api/1/products" -Headers $opt # Download site info
$site_id = $info.response[0].energy_site_id # Assumes only one powerwall
New-Item -ItemType Directory -Force -Path (Join-Path $FOLD $site_id) > $null # Create output folder, if it does not exist
$info.response | ConvertTo-Json | Out-File (Join-Path $FOLD ("$site_id"+"_info.json")) # Write info to json (optional)

# Main
while ($START -le $STOP.AddDays(-1)){ # Step through days
    $end_date = [datetime]::SpecifyKind($START,$ZONE).AddSeconds(86399) # Set end_date to be 1sec before end of the day, must include correct timezone for the region including daylight savings, eg '2023-01-01T23:59:00+10:30' or '2023-01-02T09:29:00Z' (for Australia/Adelaide in summer)
    $url = "https://owner-api.teslamotors.com/api/1/energy_sites/$site_id/calendar_history?kind=power&end_date=" + [Uri]::EscapeDataString($end_date.ToString("yyyy-MM-ddTHH:mm:ssK")) # eg https://owner-api.teslamotors.com/api/1/energy_sites//calendar_history?kind=power&end_date=2023-12-05T00%3A00%3A01%2B10%3A30
    $csv = [IO.Path]::Combine($FOLD, $site_id, $START.ToString("yyyyMMdd") + ".csv")
    if (-Not (Test-Path $csv)) {
        "$url > $csv" # Show progress
        $data = Invoke-RestMethod -Uri $url -Headers $opt # Download one days data
        if ($data.response){
            if (-Not (276,288,300 -contains $data.response.time_series.GetLength(0))){ # Check output size (optional)
                " Unexpected data size: $($data.response.time_series.GetLength(0))"
                " Expected data size is 288 and 276 or 300 on daylight savings days"
                " Note: installation_time_zone was " + $data.response.installation_time_zone  # print installation_time_zone
            }
            $data = $data.response.time_series # Data as an object array
            $data = $data | ForEach-Object {$_.PSObject.Properties | ForEach-Object {if ($_.Value -is [Decimal]) {$_.Value = [math]::Round($_.Value, 3)}}; $_} # Round values to 3 decimal places (optional)
            ($data | ConvertTo-Csv -NoTypeInformation).replace('"','') | Out-File $csv # Write to csv
        }
        Start-Sleep -s 1 # Avoid "Too Many Requests"
    }
    $START = $START.AddDays(1)
}