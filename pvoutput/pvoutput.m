% This application connects to a PVOutput.org and can download:
%   1. Public system metadata - requires your API key and system ID
%   2. Public production data - requires your username and password
%
% Configuration:
%   Create 'pvoutput.ini' with the following content:
%     apiKey   = my_apikey
%     systemId = my_systemid
%     username = my_username
%     password = my_password

% Alternative to usrename and password:
% - Log in at https://pvoutput.org/login.jsp
% - Open Developer Tools (F12)
% - Go to Application > Cookies
% - Copy the value of 'JSESSIONID'

% https://pvoutput.org/login.jsp
% https://pvoutput.org/listmap.jsp?sid=64149
% https://pvoutput.org/intraday.jsp?id=74980&sid=66481
% https://pvoutput.org/intraday.jsp?id=75868&sid=67301
% https://pvoutput.org/intraday.jsp?id=81955&sid=72664
% pvoutput().login
% pvoutput().downloadInfo(64149)
% pvoutput().downloadProduction(66481, ["2024-11-01" "2025-12-14"])
% East coast, good: 42623
% East coast, bad: 6704

classdef pvoutput

    properties
        apiKey
        systemId
        username
        password
        % JSESSIONID % alternative to username and password (depricated)
        inifile = fullfile(fileparts(mfilename('fullpath')), 'pvoutput.ini')
        cookie = fullfile(fileparts(mfilename('fullpath')), 'cookies.txt')
        datafold = fullfile(fileparts(mfilename('fullpath')), 'data')
        pvlist = fullfile(fileparts(mfilename('fullpath')), 'data', 'pvlist.csv')
    end

    methods

        function obj = pvoutput()
            % Parse ini file
            txt = fileread(obj.inifile);
            getVal = @(prop)regexp(txt, ['(?<=^' prop '\s*=\s*)[^ \r\n]+'], 'match', 'lineanchors', 'once');
            for prop = fieldnames(obj)'
                val = getVal(prop{1});
                if ~isempty(val)
                    obj.(prop{1}) = val;
                end
            end
        end


        function login(obj)
            % Login and save cookie.txt (requires username and passowrd)
            %   login()

            % Example: pvoutput().login
            % !curl -L -c "cookies.txt" -b "cookies.txt" -d "login=***&password=***" "https://pvoutput.org/index.jsp"

            fprintf(' Signing in...')
            cmd = sprintf('curl -L -c "%s" -b "%s" -d "login=%s&password=%s" "https://pvoutput.org/index.jsp"', obj.cookie, obj.cookie, obj.username, obj.password);
            [err, msg] = system(cmd);
            assert(~err, ' Login failed: %s', msg)
            assert(~contains(msg, 'Login or password incorrect'), '%s', 'Login or password incorrect')
            fprintf(' > %s\n', obj.cookie)
        end

        
        function S = readPVlist(obj, refresh)
            if isfile(obj.pvlist) && ~refresh
                S = readtable(obj.pvlist);
            else
                j = dir(fullfile(obj.datafold, '*.json'));
                sysIdList = erase({j.name}, '.json');
                j = fullfile({j.folder}, {j.name});
                for k = numel(j):-1:1
                    s = jsondecode(fileread(j{k}));
                    d = dir(fullfile(erase(j{k}, '.json'), '*.csv'));
                    t = datetime(erase({d.name}, '.csv'), 'InputFormat','yyyyMMdd');
                    s.firstDay = min(t);
                    s.lastDay = max(t);
                    s.files = numel(d);
                    s.gaps = round(100 - numel(d) / days(range(t) + 1) * 100, 2);
                    s.sysId = sysIdList{k};
                    S{k} = s;
                end
                S = cellOfStructs2table(S);
                S = movevars(S, 'sysId', 'Before', 1);
                writetable(S, obj.pvlist)
            end
        end


        function T = readProduction(obj, sid, span)
            days = datetime(span(1)) : datetime(span(2));
            fold = fullfile(obj.datafold, num2str(sid));
            T = table();
            for k = 1:numel(days)
                daystr = string(days(k), 'yyyyMMdd');
                file   = fullfile(fold, sprintf('%s.csv', daystr));
                if ~isfile(file), continue, end
                Tk = readtable(file);
                T  = [T; Tk]; %#ok<AGROW>
            end
        end


        function downloadInfo(obj, sid, staleThresh)
            % Download system information (requires an API key)
            %   downloadInfo(obj, sid)

            % Example: pvoutput().downloadInfo(62777)
            % !curl -s -H "X-Pvoutput-Apikey: ***" -H "X-Pvoutput-SystemId: ***" "https://pvoutput.org/service/r2/getsystem.jsp?sid1=62777"

            if nargin<3 || isempty(staleThresh), staleThresh = -30; end
            sid = string(sid);

            file = fullfile(obj.datafold, sid + ".json");

            % Skip existing
            if isfile(file) && datetime(dir(file).date) > datetime('now') + staleThresh
                return
            end

            % Prepare
            url = sprintf('https://pvoutput.org/service/r2/getsystem.jsp?sid1=%s', sid);
            cmd = sprintf('curl -s -H "X-Pvoutput-Apikey: %s" -H "X-Pvoutput-SystemId: %s" "%s"', obj.apiKey, obj.systemId, url);
            fprintf(' %s', url);

            % Download
            [err, msg] = system(cmd); % eg, msg = 'Alex Enfield,6600,5085,24,275,Jinko JKM275PP-60,1,5000,Fronius FROPRIMO5.0-1,N,NaN,No,20180829,-34.858477,138.616912,5;;0'
            assert(~err, 'ERROR: %s', msg); % Check

            % Parse
            blocks = split(msg, ';');
            f1 = split(blocks{1}, ',');
            data = struct(...
                'name', f1{1}, ...
                'size_kw', str2double(f1{2})/1000, ...
                'postcode', f1{3}, ...
                'tilt', str2double(f1{4}), ...
                'orientation', str2double(f1{5}), ...
                'panel', f1{6}, ...
                'panelCount', str2double(f1{7}), ...
                'inverter', f1{9}, ...
                'lat', str2double(f1{14}), ...
                'lon', str2double(f1{15}));

            % Save
            if ~isfolder(obj.datafold)
                mkdir(obj.datafold)
            end
            fid = fopen(file, 'w+');
            fprintf(fid, '%s', jsonencode(data, 'PrettyPrint', true));
            fclose(fid);
            fprintf(' > %s\n', file)

        end


        function downloadProduction(obj, sid, span)

            % Authenticate
            obj.login
            sid = string(sid);
            obj.downloadInfo(sid)

            dayVec = checkdate(span(1)) : checkdate(span(2));
            fold = fullfile(obj.datafold, sid);

            if ~isfolder(fold)
                mkdir(fold)
            end

            fprintf(' Downloading missing pvoutput data for system = %s, from %s to %s (%g days)\n', sid, string(dayVec([1 end]), 'yyyy-MM-dd'), numel(dayVec))
            for k = 1:numel(dayVec)
                daystr = string(dayVec(k), 'yyyyMMdd');
                file = fullfile(fold, sprintf('%s.csv', daystr));

                % Check
                if isfile(file) && dayVec(k) + days(3) > datetime(dir(file).date, 'TimeZone', dayVec(k).TimeZone)
                    delete(file) % File might be incomplete
                end
                if isfile(file)
                    continue % Skip existing files
                end
                fprintf(' %g/%g: %s', k, numel(dayVec), daystr);

                % Prepare
                url = sprintf('https://pvoutput.org/intraday.jsp?id=70662&sid=%s&dt=%s&gs=0&m=0', sid, daystr);
                auth = obj.cookie; % alternative auth = "JSESSIONID=" + obj.JSESSIONID
                cmd = sprintf('curl -sS -b "%s" "%s"', auth, url);
                fprintf(' %s', url);

                % Download
                [err, html] = system(cmd);
                assert(~err, 'ERROR: %s', html);
                pause(abs(randn) * 2)

                % Parse time
                text = regexp(html, '(?<=timeArray = \[)[^\]]*', 'match', 'once');
                time = dayVec(k) + minutes(str2double(strsplit(text, ',')))';

                % Parse values
                text = regexp(html, '(?<=dataEnergyOut = \[)[^\]]*', 'match', 'once');
                produced_kwh = str2double(strsplit(text, ','))';

                % Build table
                T = table(time, produced_kwh);
                n = sum(isfinite(T.produced_kwh));

                if n == 0
                    fprintf(' no data\n');
                    continue
                end
                fprintf(' (n=%d)\n', n);

                % Fill missing values
                T = fillMissing(T, dayVec(k), minutes(5));

                % Save
                writetable(T, file);
            end
        end


        % function getproduction(obj, sid, span)
        %     % Example: pvoutput().getproduction(62777, ["2024-11-20" "2025-12-05"])
        %     % !curl -b "cookies.txt" "https://pvoutput.org/intraday.jsp?id=70662&sid=42623&dt=20250108&gs=0&m=0"
        % 
        %     obj.downloadInfo(sid)
        % 
        %     days = datetime(span(1)) : datetime(span(2));
        %     for k = 1:numel(days)
        %         daystr = string(days(k), 'yyyyMMdd');
        %         fold = fullfile(obj.datafold, num2str(sid));
        %         file = fullfile(fold, sprintf('%s.csv', daystr));
        %         fprintf('%g/%g: %s', k, numel(days), daystr);
        % 
        %         % Skip existing
        %         if isfile(file)
        %             T = readtable(file);
        %             n = sum(isfinite(T.produced_kwh));
        %             fprintf(' (n=%d)\n', n);
        %             continue
        %         end
        % 
        %         % Prepare
        %         url = sprintf('https://pvoutput.org/intraday.jsp?id=70662&sid=%d&dt=%s&gs=0&m=0', sid, daystr);
        %         auth = obj.cookie; % alternative auth = "JSESSIONID=" + obj.JSESSIONID
        %         cmd = sprintf('curl -b "%s" "%s"', auth, url);
        %         fprintf(' %s', url)
        % 
        %         % Download
        %         [err, html] = system(cmd);
        %         assert(~err, 'ERROR: %s', html); % Check
        %         pause(abs(randn)*2) % Don't spam
        % 
        %         % Parse time
        %         text = regexp(html, '(?<=timeArray = \[)[^\]]*', 'match', 'once');
        %         time = days(k) + minutes(str2double(strsplit(text, ',')))';
        % 
        %         % Parse values
        %         text = regexp(html, '(?<=dataEnergyOut = \[)[^\]]*', 'match', 'once');
        %         produced_kwh = str2double(strsplit(text, ','))';
        % 
        %         % Make a table
        %         T = table(time, produced_kwh);
        % 
        %         % Check
        %         n = sum(isfinite(T.produced_kwh));
        %         if n == 0
        %             fprintf(' no data, skip\n');
        %             continue
        %         else
        %             fprintf(' (n=%d)\n', n);
        %         end
        % 
        %         % Fill missing values with NaN
        %         step = minutes(5);
        %         T = fillMissing(T, days(k), step);
        % 
        %         % Write CSV
        %         if ~isfolder(fold)
        %             mkdir(fold)
        %         end
        %         writetable(T, file);
        %     end
        % end
    end
end

function T = fillMissing(T, day, step)
    % Ensure table is sorted
    T = sortrows(T, 'time');

    % Build complete time grid
    fullTimes = (day : step : day+1-step)';

    % Convert to timetable
    t = table2timetable(T);

    % Fill missing with NaN
    t = retime(t, fullTimes, 'fillwithmissing');

    % Convert back to table
    T = timetable2table(t);
end



% JUNK

% https://pvoutput.org/intraday.jsp?id=70662&sid=62777&dt=20251128&gs=0&m=0
% 
% !curl -c cookies.txt -d "user=s3rg3y@hotmail.com&password=ihpihnth" https://pvoutput.org/user/login
% 
% 
% 'webprd1~1pi50l67s50gp11plfj8zumfut'
%
% !curl -b "JSESSIONID=1pi50l67s50gp11plfj8zumfut" "https://pvoutput.org/intraday.jsp?id=70662&sid=62777&dt=20251128&gs=0&m=0"
%
%
% cmd = 'curl -L -sS %s --cookie cookies.txt --cookie-jar cookies.txt https://pvoutput.org/user/login -d "identity=s3rg3y@hotmail.com&password=ihpihnth"'
% cmd = 'curl --cookie-jar "cookies.txt" "https://pvoutput.org/login" -d "username=s3rg3y@hotmail.com&password=ihpihnth"'
% system(cmd)
%
%
% cmd = 'curl -L -A "Mozilla/5.0" --cookie-jar cookies.txt --cookie cookies.txt -e "https://pvoutput.org/login" -d "redirect=https%3A%2F%2Fpvoutput.org%2F" -d "username=s3rg3y@hotmail.com" -d "password=ihpihnth" https://pvoutput.org/login'
% system(cmd)
%
%
% username = 's3rg3y@hotmail.com';
% password = 'ihpihnth';   % your PVOutput password
% cookieFile = 'cookies.txt';
%
% cmd = sprintf([ ...
%     'curl -L ' ...
%     '-A "Mozilla/5.0" ' ...
%     '--cookie-jar "%s" ' ...
%     '--cookie "%s" ' ...
%     '-e "https://pvoutput.org/login" ' ...
%     '-d "username=%s" ' ...
%     '-d "password=%s" ' ...
%     '-d "sid=0" ' ...
%     'https://pvoutput.org/login' ], ...
%     cookieFile, cookieFile, username, password);
%
% status = system(cmd);
%
%
% cmd = 'curl -b "JSESSIONID=abcd1234..." https://pvoutput.org/intraday.jsp?sid=62777'
% status = system(cmd);
%
%
% opt = weboptions('HeaderFields', {'X-Pvoutput-Apikey' obj.apiKey; 'X-Pvoutput-SystemId' obj.sysId}, 'Timeout', 20);
% html = webread(url, opt);
%
%
%
% !curl -c cookies.txt -d "user=s3rg3y@hotmail.com&password=ihpihnth" https://pvoutput.org/user/login
%
%
% key=Your-API-Key&sid=Your-System-Id&
%
% https://pvoutput.org/service/r2/addoutput.jsp?key=dce7214970c4615900680a72c356f9c566936551&sid=25037&d=20100830&g=12000
%
% https://pvoutput.org/service/r2/addoutput.jsp?key=dce7214970c4615900680a72c356f9c566936551&sid=25037&id=70662&sid=%d&dt=%s&gs=0&m=0
%
%
% Curl command with headers
% cmd = sprintf('curl -s "%s" -H "X-Pvoutput-Apikey: %s" -H "X-Pvoutput-SystemId: %s" ', url, obj.apiKey, obj.sysId);
% [status, cmdout] = system(cmd)
%
%
%
% https://pvoutput.org/login.jsp

% !curl -b "JSESSIONID=1pi50l67s50gp11plfj8zumfut" "https://pvoutput.org/intraday.jsp?id=70662&sid=62777&dt=20251128&gs=0&m=0"
% !curl -b "JSESSIONID=webprd1~hrw5emqfvz821wc5811kpgflq" "https://pvoutput.org/intraday.jsp?id=70662&sid=62777&dt=20251128&gs=0&m=0"
% !curl -b "JSESSIONID=webprd1~hrw5emqfvz821wc5811kpgflq" "https://pvoutput.org/intraday.jsp?id=70662&sid=62777&dt=20251128&gs=0&m=0"






% Your credentials
% apikey   = 'dce7214970c4615900680a72c356f9c566936551';
% systemid = '25037';    % your own system id
% sid1     = '62777';             % the system you want info about
% 
% % Build request
% url = 'https://pvoutput.org/service/r2/getsystem.jsp';
% 
% options = weboptions( ...
%     'HeaderFields', { ...
%         'X-Pvoutput-Apikey',     apikey; ...
%         'X-Pvoutput-SystemId',   systemid ...
%     }, ...
%     'Timeout', 20);

% Query
% response = webread(url, 'sid1', sid1, options);

% Response format:
% systemName;systemSize;postcode;orientation;tilt;lat;lon;status;...
% parts = split(response, ';');

% lat = str2double(parts{6});
% lon = str2double(parts{7});
% 
% fprintf('Latitude: %.6f\nLongitude: %.6f\n', lat, lon);
