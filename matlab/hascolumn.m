function tf = hascolumn(T, colName)
% Return true if table T has the specified column(s)
tf = ismember(colName, T.Properties.VariableNames);
end
