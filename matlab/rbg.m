function cmap = rbg
cmap = [
    0.7 1.0 0.7
    0   1.0 0
    0   0.1 0
    0   0   0
    0.1 0   0
    1.0 0   0
    1.0 0.7 0.7];
cmap = interp1([-130 -65 -1 0 1 65 130], cmap, 130:-1:-130);
end