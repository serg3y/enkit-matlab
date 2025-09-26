function [group, model, dist, model_txt] = ransacLines(x, y, numLines, distThresh, numIter)
% Fit multiple straight lines to x,y data using RANSAC and vertical
% ditance. Second pass assigns every point to the closest detected line.
%   group = ransacLines(x, y, numLines, distThresh, numIter)
%   [group, model, distance, model_txt] = ransacLines(__)
%
% Inputs:
%   x          - Vector of x coordinates of data points.
%   y          - Vector of y coordinates of data points.
%   numLines   - Number of lines to detect (integer).
%   distThresh - Distance threshold: points within this distance to a line
%                are considered inliers.
%   numIter    - Number of random RANSAC iterations per line.
%
% Outputs:
%   group      - Vector of same length as x,y. Entry i gives the line
%                index (1..numLines) to which point (x(i),y(i)) belongs.
%   model      - Cell array of fitted line models. Each entry is a
%                [slope intercept] pair from POLYFIT for the detected line.
%   dist       - Distance of each point to the closest line.
%   model_txt  - Model expressed as text, eg {'y=0.181521x+1.12147';...}

%
% Method:
% - RANSAC (Random Sample Consensus) repeatedly samples two random points,
%   fits a line, and counts how many points fall within distThresh.
%   The best line is selected, refit using all its inliers, and its
%   points are removed from the pool. This is repeated until numLines
%   lines are found.
%
% Example:
% x = rand(300, 1) * 10;
% y =[0.5*x(  1:100) + 2 + randn(100, 1) * 0.2
%     -1 *x(101:200) + 8 + randn(100, 1) * 0.3
%     0.2*x(201:300) + 1 + randn(100, 1) * 0.1];
% [ind, ~, ~, txt] = ransacLines(x, y, 3, 0.3, 200);
% clf, hold on
% gscatter(x, y, ind);
% legend(txt)
%
% See also: POLYFIT, POLYVAL

n = numel(x);
group = zeros(n, 1); % line index for each point
rem = true(n, 1);
model = cell(numLines, 1); % store line coefficients [slope intercept]

for k = 1 : numLines
    bestInliers = [];
    idx = find(rem);
    if numel(idx) < 2
        model(k:end) = [];
        break  % not enough points left to fit another line
    end

    for iter = 1:numIter
        % Pick 2 points with distinct X values
        pts = randsample(idx, 2);
        if abs(x(pts(1)) - x(pts(2))) < 1e-12
            continue
        end

        p = polyfit(x(pts), y(pts), 1);
        d = abs(y(rem) - polyval(p, x(rem)));
        inlier = find(rem);
        inlier = inlier(d < distThresh);

        if numel(inlier) > numel(bestInliers)
            bestInliers = inlier;
            bestModel = p;
        end
    end

    model{k} = bestModel;
    group(bestInliers) = k;
    rem(bestInliers) = false;
end

% Sort groups using intercept
[~, i] = sort(cellfun(@(x)x(2), model), 'descend');
model = model(i);

% Second pass - assign every point to the closest line
dist = zeros(n, numel(model));
for k = 1 : numel(model)
    dist(:, k) = y(:) - polyval(model{k}, x(:));
end
[dist, group] = min(abs(dist), [], 2);

% Third pass: refit each group (ignore outliers)
inlier = abs(dist) < distThresh; % ignore outliers
for k = 1:numel(model)
    idx = group == k; % points assigned to this group
    model{k} = polyfit(x(idx & inlier), y(idx & inlier), 1); % refit line
end

if nargout > 3
    model_txt = cellfun(@(x)sprintf('y=%.8gx%+.8g', x), model, 'UniformOutput', 0);
end

end
