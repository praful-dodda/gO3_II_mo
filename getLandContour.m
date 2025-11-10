function landContour = getLandContour(dataDir)
% getLandContour - Generate land boundary contour for masking ocean areas in plots
%
% Returns a contour of land boundaries suitable for use as maskcontour
% parameter in plotFieldTOAR function. Ocean areas outside this contour
% will be masked (filled with white) in plots.
%
% SYNTAX:
%   landContour = getLandContour(dataDir)
%
% INPUTS:
%   dataDir - Path to data directory containing coastlines.mat
%             (optional, default: '1data')
%
% OUTPUT:
%   landContour - [n x 2] matrix of [lon, lat] points defining land boundaries
%                 NaN rows separate disconnected land masses
%                 Returns [] if no contour data is available
%
% EXAMPLE:
%   landContour = getLandContour();
%   plotFieldTOAR(sk, zk, ax, landContour);

if nargin < 1
    dataDir = '1data';
end

landContour = [];

% Try coastlines.mat first (primary method, produces better results)
coastFile = fullfile(dataDir, 'coastlines.mat');
if exist(coastFile, 'file')
    try
        fprintf('  Loading land contour from coastlines.mat...\n');
        coast = load(coastFile, 'coastlon', 'coastlat');

        % Format as n x 2 matrix [lon, lat]
        landContour = [coast.coastlon(:), coast.coastlat(:)];

        % Remove any invalid points
        validIdx = ~isnan(landContour(:,1)) & ~isnan(landContour(:,2));
        if ~all(validIdx)
            % Keep NaN rows as separators between land masses
            fprintf('    Land contour has %d segments (separated by NaN)\n', ...
                sum(isnan(landContour(:,1))) + 1);
        end

        fprintf('    Land contour loaded: %d points\n', size(landContour, 1));
        return;

    catch ME
        warning('Could not load coastlines.mat: %s', ME.message);
        fprintf('  Attempting fallback to landareas.shp...\n');
    end
end

% Fallback to landareas.shp
try
    fprintf('  Loading land contour from landareas.shp...\n');
    landShapefile = 'landareas.shp';
    landAreas = shaperead(landShapefile);

    fprintf('    Loaded %d land polygons from landareas.shp\n', length(landAreas));

    % Combine all land polygon boundaries into single contour with NaN separators
    landContour = [];
    for iPoly = 1:length(landAreas)
        % Get polygon coordinates
        polyLon = landAreas(iPoly).X(:);
        polyLat = landAreas(iPoly).Y(:);

        % Remove existing NaN separators (we'll add our own)
        validIdx = ~isnan(polyLon) & ~isnan(polyLat);
        polyLon = polyLon(validIdx);
        polyLat = polyLat(validIdx);

        % Skip if polygon is empty
        if isempty(polyLon)
            continue;
        end

        % Add this polygon to contour with NaN separator
        landContour = [landContour; [polyLon, polyLat]; [NaN, NaN]];
    end

    fprintf('    Land contour created: %d points from %d polygons\n', ...
        size(landContour, 1), length(landAreas));

catch ME
    warning('Could not load landareas.shp: %s', ME.message);
    warning('No land contour available. Ocean masking will not be applied.');
    landContour = [];
end

end
