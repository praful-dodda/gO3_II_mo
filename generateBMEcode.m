function code = generateBMEcode(obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, models)
% generateBMEcode - Generate BME configuration code based on input parameters
% Syntax:
%   code = generateBMEcode(obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, models)
% INPUTS:
%   obsType   - Observation type (0: none, 1: flat GO, 2: fine GO)
%   CTMtype   - CTM data type (0: none, 1: direct, 2: indirect)
%   RAMP      - 1x3 vector indicating RAMP parameters
%   nsmax     - Maximum number of soft data points
%   nhmax     - Maximum number of hard data points
%   BMEtype   - BME method type
%   models    - Cell array of CTM model names included (e.g., {'MERRA2-GMI', 'M3fusion'})
% OUTPUT:
%   code      - Generated BME configuration code string
% Example:
%   code = generateBMEcode(1, 3, [0 0 0], 3, 3, 3, {'M3fusion', 'UKML'});


    % If models cell array has repeated entries, keep only unique ones
    nmodels = length(models);
    uniqueModels = cell(1, nmodels);

    for i = 1:nmodels
        isUnique = true;
        for j = 1:i-1
            if strcmp(models{i}, models{j})
                isUnique = false;
                break;
            end
        end
        if isUnique
            uniqueModels{i} = models{i};
        end
    end
    models = uniqueModels(~cellfun('isempty', uniqueModels));

    % Base 8-digit code
    base = sprintf('%d%d%d%d%d%d%d%d', obsType, CTMtype, RAMP(1), RAMP(2), RAMP(3), nsmax, nhmax, BMEtype);
    
    % CTM bitmask
    % modelMap = struct('MERRA2-GMI', 1, 'M3fusion', 2, 'OMI-MLS', 4, ...
    %                   'IASI-GOME2', 8, 'UKML', 16, 'NJML', 32);

    % CTM bitmask using Map
    modelMap = containers.Map({'MERRA2-GMI', 'M3fusion', 'OMI-MLS', ...
                               'IASI-GOME2', 'UKML', 'NJML'}, ...
                              [1, 2, 4, 8, 16, 32]);
    bitmask = 0;
    for i = 1:length(models)
        bitmask = bitmask + modelMap(models{i});
    end
    
    % Full code
    code = sprintf('%s-%02X', base, bitmask);
end