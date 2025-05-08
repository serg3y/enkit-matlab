[p,F,f,e] = listfiles('**\*.json');

for k = 1:numel(f)
    try
        dt = datetime(f{k},'inputformat','yyyyMMdd_HHmmss');
        dt = dateshift(dt,'start','minute') - minutes(mod(minute(dt),5)); %round down

        f{k} = char(dt,'yyyyMMdd_HHmm');
        movefile(p{k}, fullfile(F{k},[f{k} e{k}]))
    end
end