function path = enkitPath(varargin)
% Return the root folder of the repository or executable

if isdeployed
    % Compiled - root folder of the extracted CTF archive
    root = ctfroot;
else
    % Development - parent folder of this file
    root = fileparts(fileparts(mfilename('fullpath')));
end

path = fullfile(root, varargin{:});

end
