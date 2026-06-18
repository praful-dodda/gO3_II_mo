function [cube, cubes] = loadCompositeCube(cfg, bestT)
% loadCompositeCube - Assemble per-method cubes and compose a per-year best cube
%
% Shared by runPostprocess (pipeline) and makePaperReport (figures) so both use
% the identical composite cube. Reads the cached per-method cubes (fast) and
% stitches each year from its best method (decision D2), falling back to
% cfg.fallbackMethod where a year's best method has no estimate files.
%
% SYNTAX:
%   [cube, cubes] = loadCompositeCube(cfg, bestT)
%
% INPUTS:
%   cfg   - struct with fields: methodConfig, fallbackMethod, srcDir, outDir,
%           yearRange (see runPostprocess defaults)
%   bestT - table with Year, BestMethod (from bestMethodByYear); may be empty
%
% OUTPUTS:
%   cube  - composite cube (composeBestMethodCube) or single-method cube
%   cubes - containers.Map of the per-method cubes actually loaded
%
% SEE ALSO: assembleBMEcube, composeBestMethodCube, runPostprocess, makePaperReport

if nargin < 2, bestT = table(); end

methodsNeeded = string(cfg.fallbackMethod);
if ~isempty(bestT) && height(bestT) > 0
    methodsNeeded = unique([methodsNeeded; ...
        string(bestT.BestMethod(~ismissing(bestT.BestMethod)))], 'stable');
end
methodsNeeded = methodsNeeded(methodsNeeded ~= "");

cubes = containers.Map();
for i = 1:numel(methodsNeeded)
    mth = char(methodsNeeded(i));
    try
        c = assembleBMEcube(mth, local_cubeOpts(cfg));
        cubes(mth) = c;
        fprintf('  loaded cube for method %s (%d months)\n', mth, c.nMonths);
    catch ME
        warning('loadCompositeCube:cube', 'Skipping method %s: %s', mth, ME.message);
    end
end
if isempty(cubes)
    error('loadCompositeCube:noCubes', ...
        'No method cubes could be assembled from %s. Run the estimation first.', cfg.srcDir);
end

if ~isempty(bestT) && height(bestT) > 0
    cube = composeBestMethodCube(cubes, bestT, struct('fallbackMethod', cfg.fallbackMethod));
    fprintf('  composed per-year best-method cube (%d months)\n', cube.nMonths);
else
    ks = keys(cubes); cube = cubes(ks{1});
    fprintf('  no best-method table; using single method %s\n', ks{1});
end

end

% ========================================================================
function o = local_cubeOpts(cfg)
mc = cfg.methodConfig;
o = struct('goScenario', mc.goScenario, 'logTransf', mc.logTransf, ...
    'areaCode', mc.areaCode, 'mapResolution', mc.mapResolution, ...
    'dataFormat', mc.dataFormat, 'keepOnlyLand', mc.keepOnlyLand, ...
    'srcDir', cfg.srcDir, 'outDir', fullfile(cfg.outDir, 'cubes'), ...
    'yearRange', cfg.yearRange, 'saveCache', true, 'verbose', false);
end
