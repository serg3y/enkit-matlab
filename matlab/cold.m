function cmap = cold(varargin)
cmap = hot(varargin{:});
cmap = circshift(cmap, 1, 2);
end