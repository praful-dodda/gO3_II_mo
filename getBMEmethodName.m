function methodName = getBMEmethodName(BMEmethod, goScenario)
% getBMEmethodName - Generate full descriptive name for BME method and GO scenario
%
% Creates human-readable method names from BME method codes and global offset
% scenarios, used in plots, legends, configuration comparisons, etc.
%
% SYNTAX:
%   methodName = getBMEmethodName(BMEmethod, goScenario)
%
% INPUT:
%   BMEmethod  - String, BME method code (e.g., '10000133', '13000313-01')
%   goScenario - Numeric, global offset scenario code
%                0 = Zero/flat (constant mean)
%                1 = Flat (constant mean, legacy)
%                2 = Domain-wide S/T smoothing
%                3 = Regional S/T smoothing (fine GO)
%                6 = Local S/T smoothing
%
% OUTPUT:
%   methodName - String, descriptive method name
%
% EXAMPLES:
%   methodName = getBMEmethodName('10000133', 0)
%   % → 'Obs. only (flat GO)'
%
%   methodName = getBMEmethodName('10000133', 3)
%   % → 'Obs. only (fine GO)'
%
%   methodName = getBMEmethodName('13000313-01', 3)
%   % → 'Obs. + MERRA2-GMI'
%
%   methodName = getBMEmethodName('13000313-06', 3)
%   % → 'Obs. + M3fusion + OMI-MLS'
%
%   methodName = getBMEmethodName('13000313-16', 3)
%   % → 'Obs. + M3fusion + OMI-MLS + UKML'
%
% MODEL CODE MAPPING (hex bitmask):
%   01 = MERRA2-GMI
%   02 = M3fusion
%   04 = OMI-MLS
%   08 = IASI-GOME2
%   10 = UKML
%   20 = NJML
%   03 = MERRA2-GMI + M3fusion
%   05 = MERRA2-GMI + OMI-MLS
%   06 = M3fusion + OMI-MLS
%   09 = MERRA2-GMI + IASI-GOME2
%   0A = M3fusion + IASI-GOME2
%   11 = MERRA2-GMI + UKML
%   12 = M3fusion + UKML
%   15 = MERRA2-GMI + OMI-MLS + UKML
%   16 = M3fusion + OMI-MLS + UKML
%   21 = MERRA2-GMI + NJML
%   22 = M3fusion + NJML
%   3F = All models (MERRA2-GMI + M3fusion + OMI-MLS + IASI-GOME2 + UKML + NJML)
%
% SEE ALSO: parseBMEcode, decodeCTMmodels, describeBMEcode
%
% USAGE IN PLOTTING:
%   % Generate config names automatically
%   configPatterns = {'CBV_BME10000133_go0*.mat', 'CBV_BME13000313-01_go3*.mat'};
%   configNames = cellfun(@(p) getBMEmethodName(extractBMEmethod(p), extractGOscenario(p)), ...
%                         configPatterns, 'UniformOutput', false);

% Input validation
if nargin < 2
    error('Both BMEmethod and goScenario are required');
end

if isempty(BMEmethod)
    error('BMEmethod cannot be empty');
end

% Convert BMEmethod to string if numeric
if isnumeric(BMEmethod)
    BMEmethod = num2str(BMEmethod);
end

% Parse the BME method code to get CTM models
[~, ~, ~, ~, ~, ~, CTMmodels] = parseBMEcode(BMEmethod);

% Determine base description
% Check if no CTM models (obs only)
% decodeCTMmodels returns {'obs. only'} when no models are found
isObsOnly = isempty(CTMmodels) || ...
            (iscell(CTMmodels) && (isempty(CTMmodels{1}) || strcmpi(CTMmodels{1}, 'obs. only')));

if isObsOnly
    % No CTM models - observation only
    goName = getGOscenarioName(goScenario);
    methodName = sprintf('Obs. only (%s)', goName);
else
    % Has CTM models - build model name list
    if iscell(CTMmodels)
        % Join multiple models with ' + '
        modelStr = strjoin(CTMmodels, ' + ');
    else
        modelStr = CTMmodels;
    end
    methodName = sprintf('Obs. + %s', modelStr);
end

end

function goName = getGOscenarioName(goScenario)
% getGOscenarioName - Convert GO scenario code to descriptive name
%
% Maps global offset scenario codes to human-readable names
%
% INPUT:
%   goScenario - Numeric, global offset scenario code
%
% OUTPUT:
%   goName - String, descriptive name for the GO scenario

switch goScenario
    case 0
        goName = 'flat GO';
    case 1
        goName = 'flat GO';  % Legacy, same as 0
    case 2
        goName = 'domain GO';
    case 3
        goName = 'fine GO';  % Regional S/T smoothing (most common)
    case 6
        goName = 'local GO';
    otherwise
        goName = sprintf('GO%d', goScenario);
        warning('Unknown GO scenario: %d. Using default name: %s', goScenario, goName);
end

end
