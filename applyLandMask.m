function zk_masked = applyLandMask(sk, zk, dataDir)
% applyLandMask - Masks ocean points by setting them to NaN for plotting
%
% Takes estimation points and values, identifies land vs ocean, and sets
% ocean values to NaN so they won't be displayed in plots.
%
% SYNTAX:
%   zk_masked = applyLandMask(sk, zk, dataDir)
%
% INPUTS:
%   sk       - [n x 2] matrix of spatial points [lon, lat]
%   zk       - [n x 1] or [n x m] matrix of values at points sk
%   dataDir  - Path to data directory containing coastlines.mat
%              (optional, default: '1data')
%
% OUTPUT:
%   zk_masked - Same size as zk, with ocean values set to NaN
%
% EXAMPLE:
%   YkBMEm_masked = applyLandMask(BMEs.sk, BMEs.YkBMEm);
%   plotField(BMEs.sk, YkBMEm_masked, displayArea, maskcontour);

if nargin < 3
    dataDir = '1data';
end

% Initialize output (copy input)
zk_masked = zk;

% Try coastlines.mat first (primary method, produces better results)
coastFile = fullfile(dataDir, 'coastlines.mat');
if exist(coastFile, 'file')
    try
        fprintf('  Applying land mask using coastlines.mat...\n');
        coast = load(coastFile, 'coastlon', 'coastlat');

        % Check which points are on land
        on_land = inpolygon(sk(:, 1), sk(:, 2), ...
            coast.coastlon, coast.coastlat);

        % Set ocean points to NaN
        zk_masked(~on_land, :) = NaN;

        nTotal = size(sk, 1);
        nLand = sum(on_land);
        nOcean = nTotal - nLand;
        fprintf('    Masked %d ocean points (%.1f%%), kept %d land points (%.1f%%)\n', ...
            nOcean, 100*nOcean/nTotal, nLand, 100*nLand/nTotal);

        return;

    catch ME
        warning('Could not apply land mask using coastlines.mat: %s', ME.message);
        fprintf('  Attempting fallback to landareas.shp...\n');
    end
end

% Fallback to landareas.shp
try
    fprintf('  Applying land mask using landareas.shp...\n');
    landShapefile = 'landareas.shp';
    landAreas = shaperead(landShapefile);

    % Pre-allocate logical array
    on_land = false(size(sk, 1), 1);

    % For each land polygon, check which points are inside
    nPolygons = length(landAreas);
    for iPoly = 1:nPolygons
        if mod(iPoly, 100) == 0
            fprintf('    Processing polygon %d/%d (%.1f%%)...\n', ...
                iPoly, nPolygons, 100*iPoly/nPolygons);
        end

        % Get polygon coordinates
        polyLon = landAreas(iPoly).X(:);
        polyLat = landAreas(iPoly).Y(:);

        % Remove NaN separators
        validIdx = ~isnan(polyLon) & ~isnan(polyLat);
        polyLon = polyLon(validIdx);
        polyLat = polyLat(validIdx);

        % Skip if polygon is empty
        if isempty(polyLon)
            continue;
        end

        % Check which points (not yet marked as land) are in this polygon
        pointsToCheck = ~on_land;
        if any(pointsToCheck)
            in_this_poly = inpolygon(sk(pointsToCheck, 1), ...
                                    sk(pointsToCheck, 2), ...
                                    polyLon, polyLat);

            % Update the land mask
            temp = find(pointsToCheck);
            on_land(temp(in_this_poly)) = true;
        end
    end

    % Set ocean points to NaN
    zk_masked(~on_land, :) = NaN;

    nTotal = size(sk, 1);
    nLand = sum(on_land);
    nOcean = nTotal - nLand;
    fprintf('    Masked %d ocean points (%.1f%%), kept %d land points (%.1f%%)\n', ...
        nOcean, 100*nOcean/nTotal, nLand, 100*nLand/nTotal);

catch ME
    warning('Could not apply land mask using landareas.shp: %s', ME.message);
    warning('No land masking applied. Displaying all points.');
    % Return original data unchanged
end

end
