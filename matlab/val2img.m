function img = val2img(A, range, cmap)
% Convert numeric array to an RGB image using a colormap
%
%   img = VAL2IMG(A) maps the values of array A to colors using the default
%   colormap (jet) and the range of values in A.
%
%   img = VAL2IMG(A, RANGE) uses the specified RANGE = [min max] to scale
%   the values before mapping to the colormap.
%
%   img = VAL2IMG(A, RANGE, CMAP) uses the specified colormap CMAP (Nx3 array).
%
% Example:
%   A = peaks(200);
%   img = val2img(A, [-6 6], jet(256));
%   imshow(img);

% Set defaults
if nargin < 2 || isempty(range)
    range = [min(A(:)), max(A(:))];
end
if nargin < 3 || isempty(cmap)
    cmap = colormap;
end

% Clip values to the specified range
% A = min(max(A, range(1)), range(2));

% Scale values to colormap indices
idx = round(rescale(A, 1, size(cmap,1), 'InputMin', range(1), 'InputMax', range(2)));

% Convert indices to img image
img = ind2rgb(idx, cmap);
end
