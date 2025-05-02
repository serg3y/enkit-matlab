% Download AEMO historic electricity prices
% https://aemo.com.au/aemo/data/nem/priceanddemand

for state = ["NSW" "QLD" "VIC" "SA" "TAS"]
    for year = 2020:2030
        for month = 1:12
            if datetime(year, month, 1) < datetime('now')

                fold = state;
                file = sprintf("PRICE_AND_DEMAND_%g%02g_%s1.csv", year, month, state);
                path = fullfile(fold, file);

                if ~isfile(path) || dir(path).date < datetime(year, month + 1, 2) % Download if file is missing or was downloaded before the month finished

                    if ~isfolder(state), mkdir(state), end
                    url = "https://aemo.com.au/aemo/data/nem/priceanddemand/" + file;
                    cmd = sprintf('curl -sS "%s" > "%s"', url, path);
                    disp(cmd) % Show progress
                    system(cmd); % Download
                    pause(1) % Be nice to server
                end
            end
        end
    end
end
