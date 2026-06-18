function softOut = maskSoftDataLeakage(softData, valCoords, leakRadius, leakRadiusDefault)
% maskSoftDataLeakage - Remove CBV soft-data leakage near held-out stations
%
% In checker-board validation (CBV), the gridded soft data (e.g. M3fusion) was
% bias-corrected against surface observations within a correction radius of each
% grid cell. Cells near a *held-out validation* station therefore already encode
% that station -> leakage. This function hard-drops (sets to NaN) every soft grid
% cell within a per-source radius of any validation station, so the held-out
% signal cannot re-enter through the soft data. NaN cells are dropped downstream
% by valstg2stv in getTOARknowledgeBase.
%
% The method is generic across soft datasets; only the RADIUS is per-source
% (a source that is NOT station-corrected, e.g. a satellite product, takes
% radius 0 and is left untouched).
%
% SYNTAX:
%   softOut = maskSoftDataLeakage(softData, valCoords, leakRadius)
%   softOut = maskSoftDataLeakage(softData, valCoords, leakRadius, leakRadiusDefault)
%
% INPUTS:
%   softData   - single soft-model struct OR cell array of such structs. Each
%                struct must have:
%                  .sMS  [nCells x 2]  grid cell [lon lat]
%                  .Z    [nCells x nTime] mean field (masked to NaN per cell)
%                  .Zv   [nCells x nTime] variance (masked to NaN if present)
%                  .modelName  char (used to look up the radius)
%   valCoords  - [nVal x 2] [lon lat] of held-out validation stations
%   leakRadius - scalar degrees applied to ALL sources, OR a struct mapping
%                sanitized modelName (non-alphanumerics removed) -> radius in
%                degrees. 0 or absent => that source is not masked. An optional
%                field .default applies to unlisted sources.
%   leakRadiusDefault - fallback radius (deg) for a model not found in a struct
%                leakRadius that also lacks a .default field (default 2.0).
%
% OUTPUT:
%   softOut    - copy of softData with contaminated cells set to NaN.
%
% NOTE: distances are Euclidean in degrees (consistent with getCheckerBoard's
% degree boxes); adequate for the ~2 deg correction footprint.
%
% SEE ALSO: getCheckerBoard, getTOARknowledgeBase, runCBV_toar, getLeakTag

if nargin < 4 || isempty(leakRadiusDefault), leakRadiusDefault = 2.0; end

wasStruct = isstruct(softData);
if wasStruct
    models = {softData};
else
    models = softData;   % already a cell array
end

if isempty(valCoords)
    softOut = softData;   % nothing held out -> nothing to mask
    return;
end

for m = 1:numel(models)
    sd = models{m};
    if ~isfield(sd, 'sMS') || isempty(sd.sMS) || ~isfield(sd, 'Z')
        continue;
    end

    mn = '';
    if isfield(sd, 'modelName'), mn = sd.modelName; end
    r = local_resolveRadius(mn, leakRadius, leakRadiusDefault);

    if isempty(r) || r <= 0
        fprintf('    [leak-control] %s: radius 0 -> not masked.\n', local_name(mn));
        models{m} = sd;
        continue;
    end

    % Cells whose [lon lat] is within r degrees of ANY validation station.
    nbrs = rangesearch(valCoords, sd.sMS, r);
    maskCells = ~cellfun(@isempty, nbrs);

    nDrop = sum(maskCells);
    if nDrop > 0
        sd.Z(maskCells, :) = NaN;
        if isfield(sd, 'Zv') && ~isempty(sd.Zv)
            sd.Zv(maskCells, :) = NaN;
        end
    end
    fprintf('    [leak-control] %s: r=%.2f deg, dropped %d/%d cells (%.1f%%).\n', ...
        local_name(mn), r, nDrop, numel(maskCells), 100*nDrop/max(1,numel(maskCells)));

    models{m} = sd;
end

if wasStruct
    softOut = models{1};
else
    softOut = models;
end
end

% ------------------------------------------------------------------------
function r = local_resolveRadius(modelName, leakRadius, defR)
% Per-source radius lookup. Scalar leakRadius applies to all sources; struct
% leakRadius is keyed by sanitized modelName (e.g. 'OMI-MLS' -> 'OMIMLS').
if isnumeric(leakRadius)
    r = leakRadius;
    return;
end
if ~isstruct(leakRadius)
    r = defR;
    return;
end
key = regexprep(char(modelName), '[^a-zA-Z0-9]', '');
if ~isempty(key) && isfield(leakRadius, key)
    r = leakRadius.(key);
elseif isfield(leakRadius, 'default')
    r = leakRadius.default;
else
    r = defR;
    warning('maskSoftDataLeakage:noRadius', ...
        'No leakRadius entry for soft model "%s"; using default %.2f deg.', ...
        local_name(modelName), defR);
end
end

% ------------------------------------------------------------------------
function s = local_name(mn)
if isempty(mn), s = '(unnamed)'; else, s = char(mn); end
end
