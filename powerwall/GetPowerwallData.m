% Batch download daily 5 minute Powerwall data from Teslamotors.com to csv files.
% Reference: https://tesla-api.timdorr.com/energy-products/energy/history#get-api-1-energy_sites-site_id-calendar_history

% Get your refresh_token from: https://www.myteslamate.com/tesla-token
refresh_token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjI5Skh4dlVBVVFfbDlBVXFhcHBrV2dLRDhRRSJ9.eyJpc3MiOiJodHRwczovL2F1dGgudGVzbGEuY29tL29hdXRoMi92MyIsImF1ZCI6Imh0dHBzOi8vYXV0aC50ZXNsYS5jb20vb2F1dGgyL3YzL3Rva2VuIiwiaWF0IjoxNzQ2ODgwNjg0LCJzY3AiOlsib3BlbmlkIiwib2ZmbGluZV9hY2Nlc3MiXSwib3VfY29kZSI6Ik5BIiwiZGF0YSI6eyJ2IjoiMSIsImF1ZCI6Imh0dHBzOi8vb3duZXItYXBpLnRlc2xhbW90b3JzLmNvbS8iLCJzdWIiOiIxNzEwZjYwYS01ZmJhLTRmNWUtYjY1Yi00OWU4MTk0MWE3OWEiLCJzY3AiOlsib3BlbmlkIiwiZW1haWwiLCJvZmZsaW5lX2FjY2VzcyJdLCJhenAiOiJvd25lcmFwaSIsImFtciI6WyJwd2QiLCJwaG9uZTJmYSJdLCJhdXRoX3RpbWUiOjE3NDY4ODA2Njd9fQ.IrnXE1kZ2ilZvmWJmoQtqXI7Z6MPnAqlho00tU5llCXTg2uJHYrTh3BB7x_D5Io6_OfKJl5JP6_wwH1xcVbzhPey2Ts6_gnnmgY7MSNQeRHsDvEiEfso0YnnyzLIK7C2khgte4n1KqoRWdhTT5rnYC_jtKoqnxWzR51DgifWYtiJIYvqot0jCcKEMvdoYG7NNDDAmxv66uaGtDVWuAUIMFUzcd7T-D-rIcbmLQgs2Uphnq5tkpKlCGDY8M7WqFMIi3FrZxFP6p89dgtgWJ2TnyRmeCBWv-CN8mqg6fKJBxRkQslxc9FC04uQxLeI9qOBslkT9z5nR5vy2SPE3Yxhfw';
start_date = datetime(2024,1,1); % Start date
stop_date  = datetime('today'); % Stop date
data_fold  = fullfile(fileparts(mfilename('fullpath')), 'data'); % Output folder
time_zone  = 'Local';  % Powerwall timezone, eg 'Australia/Adelaide', or 'Local' to use PC timezone

% Prepare
[err, json] = system(['curl -sS -X POST https://auth.tesla.com/oauth2/v3/token -H "Content-Type: application/json" -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"ownerapi\",\"refresh_token\":\"' refresh_token '\",\"scope\":\"openid email offline_access\"}"']);
auth = jsondecode(json);
opt  = weboptions(HeaderFields = {'Authorization' ['Bearer ' auth.access_token]}); % Download setting
info = webread("https://owner-api.teslamotors.com/api/1/products", opt); % Download site info
site_id = string(info.response(1).energy_site_id); % Assumes only one powerwall
[~, ~] = mkdir(fullfile(data_fold, site_id)); % Create output folder, if it does not exist
writelines(jsonencode(info.response, PrettyPrint = true), fullfile(data_fold, site_id + "_info.json")) % Write info to json (optional)

% Main
while start_date < stop_date-1
    end_date = datetime(start_date, 'TimeZone', time_zone, 'Format', "yyyy-MM-dd'T'HH:mm:ssZZZZZ") + 86399/86400; % Set end_date to be 1sec before end of the day, must include correct timezone for the region including daylight savings, eg '2023-01-01T23:59:00+10:30' or '2023-01-02T09:29:00Z' (for Australia/Adelaide in summer)
    url = "https://owner-api.teslamotors.com/api/1/energy_sites/" + site_id + "/calendar_history?kind=power&end_date=" + urlencode(string(end_date));
    csv = fullfile(data_fold, site_id, string(datetime(start_date, 'Format', 'yyyyMMdd')) + ".csv");
    if ~isfile(csv)
        disp(url + ' > ' + csv) % Show progress
        %!curl https://owner-api.teslamotors.com/api/1/energy_sites/2282236/calendar_history?kind=power&end_date=2024-01-01T23%3A59%3A59%2B10%3A30
        data = webread(url, opt).response; % Download one days data
        if ~isempty(data)
            assert(isequal(data.installation_time_zone, end_date.TimeZone), "Set TimeZone='%s'", data.installation_time_zone) % Check that time zones match (optional)
            data = struct2table(data.time_series); % Convert data to a table
            data(:, 2:end) = round(data(:,2:end), 3); % Round values to 3 decimal places (optional)
            writetable(data, csv) % Write to csv
            pause(1) % Avoid "Too Many Requests"
        end
    end
    start_date = start_date + 1;
end