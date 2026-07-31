function outFiles = downscaleEstimateFiles(jobs, opts)
% downscaleEstimateFiles - Downscale monthly BME estimate files to a finer grid
%
% For each (year, method) job, finds the monthly 5BMEspatialPlots estimate files
% and writes one downscaled file per month to opts.outDir, keeping the SOURCE
% filename and appending "_<interp>" (e.g. ..._time2016.00_bicubic.mat). Each
% output holds a drop-in BMEs struct (sk/tk/YkBMEm/XkBMEv) on the fine grid plus
% a .downscale metadata substruct.
%
% The ozone field is interpolated with opts.interp (default 'bicubic'); the
% estimation variance, if present, is carried by nearest-neighbour onto the same
% fine cells (bicubic/spline produce no true uncertainty - see
% docs/DOWNSCALING_METHODS.txt). All months share ONE fixed fine land grid, so
% the outputs stack cleanly.
%
% SYNTAX:
%   outFiles = downscaleEstimateFiles(jobs)
%   outFiles = downscaleEstimateFiles(jobs, opts)
%
% INPUTS:
%   jobs - N x 2 cell array, each row {year (int), methodCode (char)}
%          e.g. {2016,'13000313-06'; 2017,'13000313-0E'; 2018,'13000313-0E'}
%   opts - (optional) struct:
%       .targetRes    fine resolution (deg). default 0.5.
%       .interp       ozone method: 'bicubic'(def)|'bilinear'|'spline'|...
%       .varInterp    variance carry method. default 'nearest'.
%       .srcDir       default '5BMEspatialPlots'.
%       .outDir       default fullfile('8postprocess','downscale').
%       .methodConfig struct(goScenario,logTransf,areaCode,mapResolution,
%                     dataFormat,keepOnlyLand) matching the estimate filenames.
%                     default = production (3,0,0,1.0,'stug',1).
%       .targetGrid   [nT x 2] fixed fine grid. default = getTOARmapGrid at
%                     targetRes, land only.
%       .validateFirst run a held-out-node skill check on each job's first month
%                     and print it. default true.
%       .overwrite    default true.
%       .verbose      default true.
%
% OUTPUT:
%   outFiles - cellstr of written file paths.
%
% SEE ALSO: downscaleEstimates, assembleBMEcube, getTOARmapGrid

if nargin < 2 || isempty(opts), opts = struct(); end
opts = local_defaults(opts);
mc = opts.methodConfig;

if ~exist(opts.outDir, 'dir'), mkdir(opts.outDir); end

%% Fixed fine target grid (shared by every month so outputs align)
if isempty(opts.targetGrid)
    if opts.verbose, fprintf('Building %.2f° land target grid...\n', opts.targetRes); end
    opts.targetGrid = getTOARmapGrid(opts.targetRes, true, false);
end
nT = size(opts.targetGrid, 1);
if opts.verbose, fprintf('Fine grid: %d land cells at %.2f°\n', nT, opts.targetRes); end

% Reused option structs for the per-month downscale calls
ozOpts = struct('method', opts.interp, 'targetGrid', opts.targetGrid, ...
    'sourceRes', mc.mapResolution, 'maskToSource', false, ...
    'validate', false, 'verbose', false);
vrOpts = struct('method', opts.varInterp, 'targetGrid', opts.targetGrid, ...
    'sourceRes', mc.mapResolution, 'maskToSource', false, ...
    'validate', false, 'verbose', false);

outFiles = {};
for j = 1:size(jobs, 1)
    year = jobs{j, 1}; code = jobs{j, 2};
    fileBase = sprintf('BME%s_go%d_lt%d_area%d_res%.2f_%s_land%d', code, ...
        mc.goScenario, mc.logTransf, mc.areaCode, mc.mapResolution, ...
        mc.dataFormat, mc.keepOnlyLand);
    listing = dir(fullfile(opts.srcDir, sprintf('%s_time%d.*.mat', fileBase, year)));
    if isempty(listing)
        warning('downscaleEstimateFiles:noFiles', ...
            'No files for %d / %s (base %s)', year, code, fileBase);
        continue;
    end
    if opts.verbose
        fprintf('\n[%d  %s]  %d monthly files -> %s\n', year, code, ...
            numel(listing), opts.outDir);
    end

    for k = 1:numel(listing)
        srcPath = fullfile(listing(k).folder, listing(k).name);
        S = load(srcPath, 'BMEs');
        B = S.BMEs;
        lon = B.sk(:, 1); lat = B.sk(:, 2);
        oz  = B.YkBMEm(:);

        % Optional one-shot skill log on the first month of the job
        if opts.validateFirst && k == 1
            v = downscaleEstimates(struct('lon', lon, 'lat', lat, 'val', oz), ...
                struct('method', opts.interp, 'targetRes', opts.targetRes, ...
                'sourceRes', mc.mapResolution, 'validate', true, 'verbose', false));
            h = v.validation;
            fprintf('   holdout(%s, %s): RMSE=%.3f MAE=%.3f R2=%.3f (n=%d)\n', ...
                opts.interp, listing(k).name, h.RMSE(1), h.MAE(1), h.R2(1), h.nHoldout(1));
        end

        % Ozone (chosen interp) onto the fixed fine grid
        dz = downscaleEstimates(struct('lon', lon, 'lat', lat, 'val', oz), ozOpts);

        % Variance carried by nearest neighbour onto the SAME cells
        if isfield(B, 'XkBMEv') && ~isempty(B.XkBMEv)
            dv = downscaleEstimates(struct('lon', lon, 'lat', lat, ...
                'val', B.XkBMEv(:)), vrOpts);
            xkv = dv.val;
        else
            xkv = nan(size(dz.val));
        end

        % Assemble drop-in BMEs struct on the fine grid
        BMEs = struct();
        BMEs.sk       = [dz.lon, dz.lat];
        BMEs.tk       = B.tk;
        BMEs.YkBMEm   = dz.val;
        BMEs.XkBMEv   = xkv;
        BMEs.downscale = struct('interp', opts.interp, 'varInterp', opts.varInterp, ...
            'sourceRes', mc.mapResolution, 'targetRes', opts.targetRes, ...
            'method', code, 'srcFile', listing(k).name, ...
            'createdBy', 'downscaleEstimateFiles', 'createdOn', datestr(now)); %#ok<TNOW1,DATST>

        % Output name = source name with the res tag rewritten to the TARGET
        % resolution (the data is now finer), plus the interp-method suffix.
        [~, base] = fileparts(listing(k).name);
        base = strrep(base, sprintf('res%.2f', mc.mapResolution), ...
            sprintf('res%.2f', opts.targetRes));
        outName = sprintf('%s_%s.mat', base, opts.interp);
        outPath = fullfile(opts.outDir, outName);
        if exist(outPath, 'file') && ~opts.overwrite
            if opts.verbose, fprintf('   skip (exists): %s\n', outName); end
        else
            save(outPath, 'BMEs', '-v7.3');
            outFiles{end+1} = outPath; %#ok<AGROW>
        end
    end
    if opts.verbose
        fprintf('   wrote %d files (%d fine cells each)\n', numel(listing), nT);
    end
end

if opts.verbose
    fprintf('\nDone: %d files written to %s\n', numel(outFiles), opts.outDir);
end
end

% ========================================================================
function opts = local_defaults(opts)
d = struct('targetRes', 0.5, 'interp', 'bicubic', 'varInterp', 'nearest', ...
    'srcDir', '5BMEspatialPlots', 'outDir', fullfile('8postprocess', 'downscale'), ...
    'targetGrid', [], 'validateFirst', true, 'overwrite', true, 'verbose', true);
d.methodConfig = struct('goScenario', 3, 'logTransf', 0, 'areaCode', 0, ...
    'mapResolution', 1.0, 'dataFormat', 'stug', 'keepOnlyLand', 1);
f = fieldnames(d);
for i = 1:numel(f)
    if ~isfield(opts, f{i}) || isempty(opts.(f{i})), opts.(f{i}) = d.(f{i}); end
end
end
