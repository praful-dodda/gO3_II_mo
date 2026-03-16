function [colors, lineStyles, markers, lineWidths] = getCBVmodelStyles(methodCodes, configNames)
% getCBVmodelStyles - Assign unique colors and line styles to CBV model configurations
%
% Assigns consistent, visually distinct colors and line styles to each model
% configuration based on BME method codes.
%
% COLOR STRATEGY:
%   - Simple methods (single CTM): Lighter/pastel colors
%   - Complex methods (2+ CTMs): Brighter/saturated colors
%   - Each 2-CTM combination: Unique color
%
% LINE STYLE STRATEGY:
%   - Simple methods: Dashed lines, thinner (1.5)
%   - Complex methods: Solid lines, thicker (2.5)
%
% SYNTAX:
%   [colors, lineStyles, markers, lineWidths] = getCBVmodelStyles(methodCodes, configNames)
%
% INPUTS:
%   methodCodes - Cell array of BME method codes (e.g., {'10000133', '13000313-01', ...})
%   configNames - Cell array of configuration names (same length as methodCodes)
%
% OUTPUTS:
%   colors     - Nx3 matrix of RGB color values
%   lineStyles - Cell array of line style strings ('-', '--')
%   markers    - Cell array of marker strings ('o', 's', '^', 'd')
%   lineWidths - Nx1 vector of line widths
%
% EXAMPLES:
%   methodCodes = {'10000133', '13000313-01', '13000313-05'};
%   configNames = {'Obs. only', 'Obs. + MERRA2-GMI', 'Obs. + MERRA2-GMI + OMI-MLS'};
%   [colors, lineStyles, markers, lineWidths] = getCBVmodelStyles(methodCodes, configNames);
%
% SEE ALSO: parseBMEcode, decodeCTMmodels, plotCBVresults_Phase4

%% Input validation
if nargin < 2
    configNames = cell(size(methodCodes));
end

nConfigs = length(methodCodes);
if length(configNames) ~= nConfigs
    error('methodCodes and configNames must have the same length');
end

%% Define color palette
% LIGHT colors for simple methods (single CTM)
lightColors = struct();
lightColors.obs_only = [0.68, 0.85, 0.90];      % Light Blue
lightColors.MERRA2_GMI = [0.70, 0.87, 0.54];    % Light Green
lightColors.M3fusion = [0.98, 0.60, 0.60];      % Light Red/Pink
lightColors.OMI_MLS = [1.00, 0.75, 0.47];       % Light Orange
lightColors.UKML = [0.79, 0.70, 0.84];          % Light Purple
lightColors.NJML = [0.76, 0.60, 0.42];          % Light Brown
lightColors.IASI_GOME2 = [0.90, 0.90, 0.60];    % Light Yellow

% BRIGHT colors for complex methods (2-CTM combinations) - each unique
brightColors = struct();
brightColors.MERRA2_GMI_OMI_MLS = [0.00, 0.50, 0.00];    % Dark Green
brightColors.M3fusion_OMI_MLS = [0.70, 0.13, 0.13];       % Dark Red
brightColors.MERRA2_GMI_UKML = [0.13, 0.55, 0.13];        % Forest Green
brightColors.M3fusion_UKML = [0.86, 0.08, 0.24];          % Crimson
brightColors.MERRA2_GMI_NJML = [0.00, 0.50, 0.50];        % Teal
brightColors.M3fusion_NJML = [0.55, 0.00, 0.55];          % Dark Magenta
brightColors.OMI_MLS_UKML = [0.80, 0.40, 0.00];           % Burnt Orange
brightColors.OMI_MLS_NJML = [0.60, 0.20, 0.00];           % Rust
brightColors.UKML_NJML = [0.40, 0.20, 0.60];              % Deep Purple
brightColors.MERRA2_GMI_M3fusion = [0.00, 0.39, 0.00];    % Dark Green variant

% Colors for 3+ CTM combinations
brightColors.three_plus = [0.80, 0.00, 0.80];             % Magenta

% Fallback
fallbackColor = [0.50, 0.50, 0.50];  % Gray

%% Initialize outputs
colors = zeros(nConfigs, 3);
lineStyles = cell(nConfigs, 1);
markers = cell(nConfigs, 1);
lineWidths = zeros(nConfigs, 1);

%% Process each configuration
for iConfig = 1:nConfigs
    methodCode = methodCodes{iConfig};
    configName = configNames{iConfig};

    % Strip _goX suffix if present
    methodCode = regexprep(methodCode, '_go\d+$', '');

    % Parse BME code to get CTM models
    try
        [~, ~, ~, ~, ~, ~, ctmModels] = parseBMEcode(methodCode);
    catch
        ctmModels = {};
    end

    % Determine number of CTM models
    if isempty(ctmModels) || (iscell(ctmModels) && ...
            (isempty(ctmModels{1}) || strcmpi(ctmModels{1}, 'obs. only')))
        nCTMs = 0;
        ctmModels = {};
    else
        if iscell(ctmModels)
            nCTMs = length(ctmModels);
        else
            nCTMs = 1;
            ctmModels = {ctmModels};
        end
    end

    % Assign style based on complexity
    if nCTMs <= 1
        % Simple methods: dashed, thin lines
        lineStyles{iConfig} = '--';
        lineWidths(iConfig) = 1.5;
        if nCTMs == 0
            markers{iConfig} = 'o';  % Circle for obs only
        else
            markers{iConfig} = 's';  % Square for single CTM
        end
    else
        % Complex methods: solid, thick lines
        lineStyles{iConfig} = '-';
        lineWidths(iConfig) = 2.5;
        if nCTMs == 2
            markers{iConfig} = '^';  % Triangle for 2 CTMs
        else
            markers{iConfig} = 'd';  % Diamond for 3+ CTMs
        end
    end

    % Assign color based on CTM models
    if nCTMs == 0
        % Obs. only -> Light Blue
        colors(iConfig, :) = lightColors.obs_only;
    elseif nCTMs == 1
        % Single CTM -> Light color based on model
        colors(iConfig, :) = getSingleCTMcolor(ctmModels{1}, lightColors, fallbackColor);
    elseif nCTMs == 2
        % Two CTMs -> Unique bright color for each combination
        colors(iConfig, :) = getTwoCTMcolor(ctmModels, brightColors, fallbackColor);
    else
        % Three+ CTMs -> Magenta
        colors(iConfig, :) = brightColors.three_plus;
    end

    % Fallback: if color is still zeros, try to infer from config name
    if all(colors(iConfig, :) == 0)
        colors(iConfig, :) = inferColorFromName(configName, lightColors, brightColors, fallbackColor);
    end
end

end

%% Helper function: Get color for single CTM
function color = getSingleCTMcolor(ctmModel, lightColors, fallbackColor)
    switch ctmModel
        case 'MERRA2-GMI'
            color = lightColors.MERRA2_GMI;
        case 'M3fusion'
            color = lightColors.M3fusion;
        case 'OMI-MLS'
            color = lightColors.OMI_MLS;
        case 'UKML'
            color = lightColors.UKML;
        case 'NJML'
            color = lightColors.NJML;
        case 'IASI-GOME2'
            color = lightColors.IASI_GOME2;
        otherwise
            color = fallbackColor;
    end
end

%% Helper function: Get color for two-CTM combination
function color = getTwoCTMcolor(ctmModels, brightColors, fallbackColor)
    % Sort models alphabetically for consistent key
    models = sort(ctmModels);
    model1 = models{1};
    model2 = models{2};

    % Create lookup key
    key = sprintf('%s_%s', strrep(model1, '-', '_'), strrep(model2, '-', '_'));

    % Look up color
    switch key
        case 'MERRA2_GMI_OMI_MLS'
            color = brightColors.MERRA2_GMI_OMI_MLS;
        case 'M3fusion_OMI_MLS'
            color = brightColors.M3fusion_OMI_MLS;
        case 'MERRA2_GMI_UKML'
            color = brightColors.MERRA2_GMI_UKML;
        case 'M3fusion_UKML'
            color = brightColors.M3fusion_UKML;
        case 'MERRA2_GMI_NJML'
            color = brightColors.MERRA2_GMI_NJML;
        case 'M3fusion_NJML'
            color = brightColors.M3fusion_NJML;
        case 'OMI_MLS_UKML'
            color = brightColors.OMI_MLS_UKML;
        case 'OMI_MLS_NJML'
            color = brightColors.OMI_MLS_NJML;
        case 'NJML_UKML'
            color = brightColors.UKML_NJML;
        case 'UKML_NJML'
            color = brightColors.UKML_NJML;
        case 'M3fusion_MERRA2_GMI'
            color = brightColors.MERRA2_GMI_M3fusion;
        case 'MERRA2_GMI_M3fusion'
            color = brightColors.MERRA2_GMI_M3fusion;
        otherwise
            % Generate a unique color based on hash of model names
            color = generateHashColor(key, fallbackColor);
    end
end

%% Helper function: Generate color from hash (for unknown combinations)
function color = generateHashColor(key, fallbackColor)
    % Simple hash-based color generation
    h = sum(double(key));
    hue = mod(h, 360) / 360;
    saturation = 0.7;
    value = 0.8;

    % Convert HSV to RGB
    c = value * saturation;
    x = c * (1 - abs(mod(hue * 6, 2) - 1));
    m = value - c;

    if hue < 1/6
        color = [c, x, 0] + m;
    elseif hue < 2/6
        color = [x, c, 0] + m;
    elseif hue < 3/6
        color = [0, c, x] + m;
    elseif hue < 4/6
        color = [0, x, c] + m;
    elseif hue < 5/6
        color = [x, 0, c] + m;
    else
        color = [c, 0, x] + m;
    end

    if any(isnan(color))
        color = fallbackColor;
    end
end

%% Helper function: Infer color from configuration name
function color = inferColorFromName(configName, lightColors, brightColors, fallbackColor)
    color = fallbackColor;

    if isempty(configName)
        return;
    end

    configNameLower = lower(configName);

    % Check for obs only
    if contains(configNameLower, 'obs. only') || contains(configNameLower, 'obs only')
        if ~contains(configNameLower, '+')
            color = lightColors.obs_only;
            return;
        end
    end

    % Count '+' to determine complexity
    numPlus = length(strfind(configName, '+'));

    if numPlus == 0
        % Single model - check which one
        if contains(configName, 'MERRA2-GMI')
            color = lightColors.MERRA2_GMI;
        elseif contains(configName, 'M3fusion')
            color = lightColors.M3fusion;
        elseif contains(configName, 'OMI-MLS')
            color = lightColors.OMI_MLS;
        elseif contains(configName, 'UKML')
            color = lightColors.UKML;
        elseif contains(configName, 'NJML')
            color = lightColors.NJML;
        end
    elseif numPlus == 1
        % Two models (Obs + one CTM) - light color
        if contains(configName, 'MERRA2-GMI')
            color = lightColors.MERRA2_GMI;
        elseif contains(configName, 'M3fusion')
            color = lightColors.M3fusion;
        elseif contains(configName, 'OMI-MLS')
            color = lightColors.OMI_MLS;
        elseif contains(configName, 'UKML')
            color = lightColors.UKML;
        elseif contains(configName, 'NJML')
            color = lightColors.NJML;
        end
    elseif numPlus >= 2
        % Three+ models (Obs + two+ CTMs) - bright color
        if contains(configName, 'MERRA2-GMI') && contains(configName, 'OMI-MLS')
            color = brightColors.MERRA2_GMI_OMI_MLS;
        elseif contains(configName, 'M3fusion') && contains(configName, 'OMI-MLS')
            color = brightColors.M3fusion_OMI_MLS;
        elseif contains(configName, 'MERRA2-GMI') && contains(configName, 'UKML')
            color = brightColors.MERRA2_GMI_UKML;
        elseif contains(configName, 'M3fusion') && contains(configName, 'UKML')
            color = brightColors.M3fusion_UKML;
        elseif contains(configName, 'MERRA2-GMI') && contains(configName, 'NJML')
            color = brightColors.MERRA2_GMI_NJML;
        else
            color = brightColors.three_plus;
        end
    end
end
