function linkallaxes(datatypes)
if nargin < 1 || isempty(datatypes)
    datatypes = ["datetime" "duration"];
end

% Link x or y
ax = findobj(gcf, 'type', 'axes');
if numel(ax) > 1
    for dim = ["X" "Y"]
        types = cellfun(@class, {ax.(dim+"Tick")}, 'UniformOutput', false);
        [grpi, grp] = findgroups(types);
        for k = 1:max(grpi)
            if ismember(grp{k}, datatypes)
                ind = grpi == k;
                if nnz(ind) > 1
                    linkaxes(ax(ind), lower(dim(1)));
                end
            end
        end
    end
end
