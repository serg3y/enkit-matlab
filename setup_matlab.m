% Add all folders containing *.m files to matlab path

fold = fileparts(mfilename('fullpath'));
filt = fullfile(fold, '**', '*.m');
list = unique({dir(filt).folder}');
list = list(~contains(list, 'old'));
addpath(list{:})
savepath