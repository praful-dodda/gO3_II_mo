function savedPath = saveTOARfigure(fig, basename, saveDir, varargin)
% saveTOARfigure - Save TOAR figure with consistent naming and quality settings
%
% SYNTAX:
%   savedPath = saveTOARfigure(fig, basename, saveDir)
%   savedPath = saveTOARfigure(fig, basename, saveDir, 'Name', Value, ...)
%
% INPUTS:
%   fig      - Figure handle to save
%   basename - Base filename without extension (e.g., 'TOARgo_go3_lt0_CBV_box3.0_fold1_2016-2018')
%   saveDir  - Directory to save figure (created if doesn't exist)
%
% OPTIONAL PARAMETERS:
%   'format'     - 'png', 'fig', or 'both' (default: 'png')
%   'dpi'        - Resolution in DPI (default: 300)
%   'overwrite'  - Overwrite existing files (default: true)
%
% OUTPUTS:
%   savedPath - Full path to saved PNG file (or .fig if format='fig')
%
% EXAMPLE:
%   fig = figure;
%   plot(1:10);
%   saveTOARfigure(fig, 'TOARgo_go3_box2.0_fold1', 'results/GO/CBV', 'dpi', 300);
%
% SEE ALSO:
%   getTOARglobalOffset, getTOARautoCov

%% Parse inputs
p = inputParser;
addRequired(p, 'fig');
addRequired(p, 'basename', @ischar);
addRequired(p, 'saveDir', @ischar);
addParameter(p, 'format', 'png', @(x) ismember(x, {'png', 'fig', 'both'}));
addParameter(p, 'dpi', 300, @isnumeric);
addParameter(p, 'overwrite', true, @islogical);

parse(p, fig, basename, saveDir, varargin{:});
opts = p.Results;

%% Create directory if needed
if ~exist(saveDir, 'dir')
    mkdir(saveDir);
    fprintf('  Created directory: %s\n', saveDir);
end

%% Save figure
savedPath = '';

% Save PNG
if ismember(opts.format, {'png', 'both'})
    pngPath = fullfile(saveDir, [basename '.png']);

    if exist(pngPath, 'file') && ~opts.overwrite
        fprintf('  Figure already exists (not overwriting): %s\n', basename);
        savedPath = pngPath;
    else
        % Set paper properties for consistent output
        set(fig, 'PaperPositionMode', 'auto');
        set(fig, 'PaperUnits', 'inches');
        pos = get(fig, 'Position');
        set(fig, 'PaperSize', [pos(3), pos(4)]/96);  % Convert pixels to inches

        % Save with specified DPI
        print(fig, pngPath, '-dpng', sprintf('-r%d', opts.dpi));
        fprintf('  Saved figure: %s.png\n', basename);
        savedPath = pngPath;
    end
end

% Save FIG
if ismember(opts.format, {'fig', 'both'})
    figPath = fullfile(saveDir, [basename '.fig']);

    if exist(figPath, 'file') && ~opts.overwrite
        fprintf('  Figure already exists (not overwriting): %s\n', basename);
        if isempty(savedPath)
            savedPath = figPath;
        end
    else
        savefig(fig, figPath);
        fprintf('  Saved figure: %s.fig\n', basename);
        if isempty(savedPath)
            savedPath = figPath;
        end
    end
end

end
