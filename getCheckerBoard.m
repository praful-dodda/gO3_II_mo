function [trainMask, valMask] = getCheckerBoard(sMS, boxSize, fold, plotFlag)
% getCheckerBoard - Generate checkerboard spatial pattern for cross-validation
%
% Creates a checkerboard pattern dividing spatial locations into training
% and validation sets. The pattern alternates between "black" and "white"
% squares, with the fold parameter determining which squares are for training.
%
% SYNTAX:
%   [trainMask, valMask] = getCheckerBoard(sMS, boxSize, fold, plotFlag)
%
% INPUTS:
%   sMS      - nPoints × 2 matrix of spatial coordinates [lon, lat]
%   boxSize  - Size of checkerboard squares in degrees
%              Scalar: same size for lon and lat
%              2-element: [lonSize, latSize]
%   fold     - Which fold to use:
%              1 = "black" squares for training, "white" for validation
%              2 = "white" squares for training, "black" for validation
%   plotFlag - Optional: 1 to plot checkerboard pattern, 0 to skip (default: 0)
%
% OUTPUTS:
%   trainMask - nPoints × 1 logical array (true = training set)
%   valMask   - nPoints × 1 logical array (true = validation set)
%
% DESCRIPTION:
%   The checkerboard pattern is created by:
%   1. Dividing space into grid boxes of size boxSize
%   2. Assigning each box a "color" based on its grid indices (i+j is even/odd)
%   3. Using one "color" for training, the other for validation
%   4. The fold parameter swaps which color is used for training
%
% EXAMPLES:
%   % Create 5-degree checkerboard
%   [trainMask, valMask] = getCheckerBoard(obs.sMS, 5, 1);
%
%   % Create rectangular checkerboard (10° lon × 5° lat)
%   [trainMask, valMask] = getCheckerBoard(obs.sMS, [10, 5], 2);
%
%   % Use for cross-validation
%   trainData = obs.Z(trainMask, :);
%   valData = obs.Z(valMask, :);

%% Input Validation
if nargin < 4 || isempty(plotFlag)
    plotFlag = 0;  % Default: no plotting
end

if nargin < 3
    fold = 1;
end

if nargin < 2 || isempty(boxSize)
    boxSize = 5;  % Default 5-degree boxes
end

% Handle scalar boxSize (same for lon and lat)
if isscalar(boxSize)
    boxSizeLon = boxSize;
    boxSizeLat = boxSize;
else
    boxSizeLon = boxSize(1);
    boxSizeLat = boxSize(2);
end

% Validate fold
if fold ~= 1 && fold ~= 2
    error('fold must be 1 or 2');
end

%% Extract Coordinates
lon = sMS(:, 1);
lat = sMS(:, 2);
nPoints = length(lon);

%% Create Checkerboard Pattern

% Find spatial extent
lonMin = min(lon);
lonMax = max(lon);
latMin = min(lat);
latMax = max(lat);

% Create grid reference point (use minimum coordinates)
% This ensures consistent grid alignment across different subsets
lonRef = floor(lonMin / boxSizeLon) * boxSizeLon;
latRef = floor(latMin / boxSizeLat) * boxSizeLat;

% Calculate grid indices for each point
% Grid index = floor((coordinate - reference) / boxSize)
gridLon = floor((lon - lonRef) / boxSizeLon);
gridLat = floor((lat - latRef) / boxSizeLat);

% Checkerboard pattern: assign "color" based on sum of grid indices
% If (gridLon + gridLat) is even → "black" square
% If (gridLon + gridLat) is odd  → "white" square
isBlack = mod(gridLon + gridLat, 2) == 0;

%% Assign Training and Validation Sets
if fold == 1
    % Fold 1: black squares for training, white for validation
    trainMask = isBlack;
    valMask = ~isBlack;
else
    % Fold 2: white squares for training, black for validation
    trainMask = ~isBlack;
    valMask = isBlack;
end

%% Summary Statistics
fprintf('Checkerboard pattern generated:\n');
fprintf('  Box size: %.1f° lon × %.1f° lat\n', boxSizeLon, boxSizeLat);
fprintf('  Fold: %d\n', fold);
fprintf('  Training points: %d (%.1f%%)\n', sum(trainMask), 100*sum(trainMask)/nPoints);
fprintf('  Validation points: %d (%.1f%%)\n', sum(valMask), 100*sum(valMask)/nPoints);
fprintf('  Spatial extent: [%.1f, %.1f] lon × [%.1f, %.1f] lat\n', ...
    lonMin, lonMax, latMin, latMax);

%% Plot Checkerboard Pattern (Optional)
if plotFlag
    figure('Position', [100 100 900 700]);

    % Calculate grid lines for box boundaries
    lonGridMin = lonRef;
    lonGridMax = ceil((lonMax - lonRef) / boxSizeLon) * boxSizeLon + lonRef;
    latGridMin = latRef;
    latGridMax = ceil((latMax - latRef) / boxSizeLat) * boxSizeLat + latRef;

    lonGridLines = lonGridMin:boxSizeLon:lonGridMax;
    latGridLines = latGridMin:boxSizeLat:latGridMax;

    % Draw checkerboard boxes
    for iLon = 1:length(lonGridLines)-1
        for iLat = 1:length(latGridLines)-1
            % Determine box color based on grid indices
            boxIsBlack = mod(iLon + iLat, 2) == 0;

            % Set fill color based on fold
            if (fold == 1 && boxIsBlack) || (fold == 2 && ~boxIsBlack)
                % Training box
                faceColor = [0.8 0.9 1.0];  % Light blue
                faceAlpha = 0.3;
            else
                % Validation box
                faceColor = [1.0 0.9 0.8];  % Light orange
                faceAlpha = 0.3;
            end

            % Draw rectangle
            rectangle('Position', [lonGridLines(iLon), latGridLines(iLat), ...
                boxSizeLon, boxSizeLat], ...
                'FaceColor', faceColor, 'EdgeColor', [0.3 0.3 0.3], ...
                'LineWidth', 0.5, 'FaceAlpha', faceAlpha);
            hold on;
        end
    end

    % Plot stations
    scatter(lon(trainMask), lat(trainMask), 30, 'b', 'filled', ...
        'MarkerFaceAlpha', 0.6, 'DisplayName', 'Training stations');
    scatter(lon(valMask), lat(valMask), 30, 'r', 'filled', ...
        'MarkerFaceAlpha', 0.6, 'DisplayName', 'Validation stations');

    % Formatting
    xlabel('Longitude (°)');
    ylabel('Latitude (°)');
    title(sprintf('Checkerboard Pattern: Box=%.1f°, Fold=%d', boxSizeLon, fold));
    legend('Location', 'best');
    grid on;
    axis equal tight;

    % Add summary text
    text(0.02, 0.98, sprintf('Training: %d (%.1f%%)\nValidation: %d (%.1f%%)', ...
        sum(trainMask), 100*sum(trainMask)/nPoints, ...
        sum(valMask), 100*sum(valMask)/nPoints), ...
        'Units', 'normalized', 'VerticalAlignment', 'top', ...
        'BackgroundColor', 'white', 'EdgeColor', 'black', 'FontSize', 9);
end

end
