function rgb = color2rgb(str, isLightMode)
% Convert colour spec or name to RGB triplet, adjusted for dark mode.
%   rgb = color2rgb('r')           % returns soft red


if isnumeric(str)
rgb = str; % already RGB
return
end

str = lower(char(str));
if nargin>1 && isLightMode
    % Light mode: darker colours
    switch str
        case {'r' 'red'},     rgb = [0.7 0.2 0.2];
        case {'g' 'green'},   rgb = [0.2 0.6 0.3];
        case {'b' 'blue'},    rgb = [0.2 0.4 0.7];
        case {'y' 'yellow'},  rgb = [0.8 0.8 0.3];
        case {'m' 'magenta'}, rgb = [0.6 0.4 0.8];
        case {'c' 'cyan'},    rgb = [0.3 0.8 0.8];
        case {'w' 'white'},   rgb = [0.9 0.9 0.9];
        case {'k' 'black'},   rgb = [0.4 0.4 0.4];
        otherwise, error('Unknown color spec: %s', str);
    end
else
    % Dark mode: lighter colours
    switch str
        case {'r' 'red'},     rgb = [1.0 0.4 0.4];
        case {'g' 'green'},   rgb = [0.4 1.0 0.6];
        case {'b' 'blue'},    rgb = [0.4 0.8 1.0];
        case {'y' 'yellow'},  rgb = [1.0 1.0 0.4];
        case {'m' 'magenta'}, rgb = [0.8 0.6 1.0];
        case {'c' 'cyan'},    rgb = [0.6 1.0 1.0];
        case {'w' 'white'},   rgb = [1.0 1.0 1.0];
        case {'k' 'black'},   rgb = [0.6 0.6 0.6];
        otherwise, error('Unknown color spec: %s', str);
    end
end
end
