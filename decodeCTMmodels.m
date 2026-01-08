function models = decodeCTMmodels(bitmask_hex)
    bitmask = hex2dec(bitmask_hex);
    modelNames = {'MERRA2-GMI', 'M3fusion', 'OMI-MLS', 'IASI-GOME2', 'UKML', 'NKML'};
    models = {};
    for i = 1:length(modelNames)
        if bitand(bitmask, 2^(i-1))
            models{end+1} = modelNames{i};
        end
    end
end
