function [cmap, ticks] = cold2hot(m, c, ticks)
%compression factor 0+

% Defaults
if nargin<1 || isempty(m), m = 256; end
if nargin<2 || isempty(c), c = 1; end % compression factor
if nargin<3, ticks = []; end

c1 = cold(m/2);
c2 = hot(m/2);

% if gamma ~= 1
    c1 = applyGamma(c1, c);
    c2 = applyGamma(c2, c);
% end

cmap = [flipud(c1); c2];

if ~isempty(ticks)
    scale = max(abs(ticks));
    % ticks = abs(ticks/scale) .^ c .* sign(ticks) * scale;
    ticks = compress(ticks/scale, c) * scale;
end

end

function [cmap, ticks] = applyGamma(cmap, c, ticks)
    x = linspace(0, 1, size(cmap,1));
    % y = x.^c;
    y = compress(x, c);
    cmap = interp1(x, cmap, y);
end

function y = compress(x, c)
if c>0
    y = x * (1 + c) ./ (1 + c .* abs(x));
else
    y = x ./ (1 + c .* (1 - sign(x).*x));
end
end