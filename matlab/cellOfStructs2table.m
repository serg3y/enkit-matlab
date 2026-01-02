function T = cellOfStructs2table(C)
allFields = cellfun(@fieldnames, C, 'UniformOutput', false);
uniqueFields = string(unique(cat(1, allFields{:})))';
for k = 1:numel(C)
    for f = setdiff(uniqueFields, allFields{k})
        C{k}.(f) = [];
    end
end
T = struct2table([C{:}]);
end
