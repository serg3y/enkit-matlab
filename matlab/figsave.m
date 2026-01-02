function figsave(fig, file, rez, txt, varargin)
% Save a figure as an image with custom resolution and text scaling.
%   figsave        - Save current figure as 'Figure.jpg'
%   figsave(fig)       - Select figure handle
%   figsave(fig, file)     - Specify output file (default: 'Figure.jpg')
%   figsave(fig, file, rez)    - Specify resolution [H V] in pixels (default: [900 600])
%   figsave(fig, file, rez, txt)   - Specify text scale factor (default: 1)
%
% Example:
%   clf
%   text(0.1, 0.5, ["text should be" "50 pixels high"], 'FontSize', 50)
%   figsave(gcf, 'Figure.jpg', [900 600])
%
% Notes:
% - Automatically preserves dark backgrounds.
% - Supports saving as jpg, gif (animated) or fig.
% - Text scaling affects both figure size and print resolution.

persistent cmap

% Default arguments
if nargin < 1 || isempty(fig),  fig  = gcf;          end  % Figure handle
if nargin < 2 || isempty(file), file = 'Figure.jpg'; end  % Output filename
if nargin < 3 || isempty(rez),  rez  = [900 600];    end  % Resolution [H V]
if nargin < 4 || isempty(txt),  txt  = 1;            end  % Text scale factor

% Prepare figure for printing
set(fig, 'PaperUnits', 'inches', 'PaperPosition', [0 0 rez / (100 * txt)]);

% Preserve dark background colours
if get(fig, 'Color') < 0.5
    set(fig, 'InvertHardcopy', 'off');
end

% Render figure as RGB image (slow but accurate)
% set(gcf, 'PaperPositionMode', 'auto') % HACK to supress warning
pause(0.1)
img = print(fig, '-RGBImage', ['-r' num2str(100 * txt, '%f')]);

% Ensure output folder exists
outDir = fileparts(file);
if ~isempty(outDir) && ~isfolder(outDir)
    mkdir(outDir)
end

% Print where file will be saved
if isempty(outDir)
    file = fullfile(cd, file);
end
fprintf(' > %s\n', file)

% Save file based on extension
if endsWith(file, '.jpg', 'IgnoreCase', true)
    imwrite(img, file, 'Quality', 95);

elseif endsWith(file, '.gif', 'IgnoreCase', true)
    % First frame or append mode for animated GIFs
    if ~isfile(file)
        if size(img, 3) == 3
            [img, cmap] = rgb2ind(img, 32);
        else
            [img, cmap] = gray2ind(img, 32);
        end
        pause(0.1);
        imwrite(img, cmap, file, 'gif', 'DelayTime', 0.2, 'Loopcount', inf, varargin{:});
    else
        if size(img, 3) == 3
            img = rgb2ind(img, cmap);
        else
            img = gray2ind(img, cmap);
        end
        pause(0.1);
        imwrite(img, cmap, file, 'gif', 'DelayTime', 0.2, 'WriteMode', 'append', varargin{:});
    end

elseif endsWith(file, '.fig', 'IgnoreCase', true)
    savefig(fig, file);

else
    imwrite(img, file);
end

end
