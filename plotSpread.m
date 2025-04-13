function plotSpread(ax, x, y, x2, y2, color)
% Plots a region about x,y defined by x2,y2.
x = x + seconds(0.01); % HACK to fix patch
[X, Y] = makeSteps(x, y); % Makes into teps
[X2, Y2] = makeSteps(x2, y2);
XX = [X(:); flipud(X2(:))]; % Ford and then reverse
YY = [Y(:); flipud(Y2(:))];
patch(ax, XX, YY, color, 'FaceAlpha', 0.3, 'EdgeColor', color, 'EdgeAlpha', 0.2);
end