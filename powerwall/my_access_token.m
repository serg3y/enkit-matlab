function access_token = my_access_token(force)
% Returns a Tesla 'access_token'. Eithe a cached one from file, if its
% fresh, or a new one from auth.tesla.com using a 'refresh_token'.
%   access_token = my_access_token()
%   access_token = my_access_token(force)    - force update (default:0)
%
% Remarks:
% - To access data from Tesla.com, you need an "access_token".
%   This token expires in 8 hours but can be refreshed using a "refresh_token".
%   The "refresh_token" also expires, but only after 45 days of inactivity.
% - To get and use a refresh_token:
%   1. Visit a third-party helper, eg https://www.myteslamate.com/tesla-token
%   2. Save your refresh_token to: .\my_refresh_token.txt
%   3. Run my_access_token.m to generate a new access token and cache it to: .\my_access_token.json
%
% See also: https://www.myteslamate.com/tesla-token 

% Paths
root = fileparts(mfilename('fullpath'));
refresh_token_file = fullfile(root, 'my_refresh_token.txt');
access_token_file = fullfile(root, 'my_access_token.json');
tesla_oath_url = 'https://auth.tesla.com/oauth2/v3/token';

% Try to use an access_token from file, if its fresh
try
    data = jsondecode(fileread(access_token_file));
    is_fresh = datetime(data.expires_at, 'InputFormat', 'yyyy-MM-dd HH:mm:ss') > datetime('now') + minutes(1);
    if nargin < 1 || (~force && is_fresh)
        access_token = data.access_token;
        return
    end
end

% Load refresh_token
try
    refresh_token = strtrim(fileread(refresh_token_file));
catch
    fprintf(2, [ ...
        '\nERROR: Missing refresh_token.txt\n' ...
        '  To access data from Tesla.com, you need an "access_token".\n' ...
        '  This token expires in 8 hours but can be refreshed using a "refresh_token".\n' ...
        '  The "refresh_token" also expires, but only after 45 days of inactivity.\n' ...
        '  To get and use a refresh_token:\n' ...
        '    1. Visit a third-party helper, e.g. https://www.myteslamate.com/tesla-token\n' ...
        '    2. Save your refresh_token to: %s\n' ...
        '    3. Run my_access_token.m to generate a new access token and cache it to: %s\n\n' ...
        ], refresh_token_file, access_token_file)
    return
end

% Generate new access_token
fprintf('\nGetting fresh access_token: %s > %s\n', tesla_oath_url, access_token_file)
cmd = ['curl -sS -X POST ' tesla_oath_url ' -H "Content-Type: application/json" -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"ownerapi\",\"refresh_token\":\"' refresh_token '\",\"scope\":\"openid email offline_access\"}"'];
[err, msg] = system(cmd);
assert(~err, 'Curl failed: %s', msg)
data = jsondecode(msg);
access_token = data.access_token;
data.expires_at = datestr(datetime('now') + seconds(data.expires_in), 'yyyy-mm-dd HH:MM:SS');

% Save access_token
fid = fopen(access_token_file, 'w');
fwrite(fid, jsonencode(data, 'PrettyPrint', true));
fclose(fid);
end
