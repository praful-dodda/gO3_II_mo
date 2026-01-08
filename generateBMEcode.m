function code = generateBMEcode(obsType, CTMtype, RAMP, nsmax, nhmax, BMEtype, models)

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