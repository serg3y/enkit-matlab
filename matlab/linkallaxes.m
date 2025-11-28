function linkallaxes(datatypes_list)
% Automatically find and link axes in the current figure on the X and/or Y
% dimensions based on axis datatypes.
%   linkallaxes()   - link axes whose types are 'datetime' or 'duration'.
%   linkallaxes(datatypes_list)   - specify custom list of datatypes.
%
% Remarks:
% - X and Y dimensions are linked independently.
% - An axis is linked on a given dimension if its limit datatype appears in
%   datatypes_list.

if nargin < 1 || isempty(datatypes_list)
    datatypes_list = ["datetime", "duration"];
else
    datatypes_list = string(datatypes_list(:)');
end

% Find all axes
ax = findobj(gcf, 'Type', 'axes');
if numel(ax) < 2
    return;
end

% Get axis datatypes
for i = numel(ax):-1:1
    xtype{i} = class(ax(i).XLim);
    ytype{i} = class(ax(i).YLim);
end

% Link
for datatype = datatypes_list

    % Lnk X axes
    maskX = xtype == datatype;
    if sum(maskX) > 1
        linkaxes(ax(maskX), 'x');
    end

    % Link Y axes
    maskY = ytype == datatype;
    if sum(maskY) > 1
        linkaxes(ax(maskY), 'y');
    end
end
end
