%% extractModelSpatialInfo.m - Extract spatial grids from all model outputs
% 
% This script reads model CSV files, extracts spatial coordinates (lon, lat),
% verifies consistency across years, and saves as .mat files for quick loading
%
% Author: [Your name]
% Date: [Date]

clear; clc;

%% Setup
baseDir = '1data/CTM/model_output_data';  % Adjust to your data directory
outputDir = fullfile(baseDir, 'spatial_grids');

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

fprintf('========================================\n');
fprintf('  EXTRACTING MODEL SPATIAL INFORMATION\n');
fprintf('========================================\n\n');

%% Define Models and Their Properties
models = struct();

% AM4 2008-2023
models(1).name = 'AM4';
models(1).folder = 'AM4 2008-2023';
models(1).pattern = 'AM4-monthly-mda8-%d.csv';
models(1).years = 2008:2023;

% CAMS 2003-2023
models(2).name = 'CAMS';
models(2).folder = 'CAMS 2003-2023';
models(2).pattern = 'CAMS_monthly_%d.csv';
models(2).years = 2003:2023;

% CESM1-CAM4-Chem 1990-2001
models(3).name = 'CESM1_CAM4_Chem';
models(3).folder = 'CESM1-CAM4-Chem 1990-2001';
models(3).pattern = 'CESM1-CAM4-Chem-monthly-dma8-%d.csv';
models(3).years = 1990:2001;

% CESM1 WACCM 1990-2001 (missing 1997-1999)
models(4).name = 'CESM1_WACCM';
models(4).folder = 'CESM1 WACCM 1990-2001 (missing 1997 1998 1999)';
models(4).pattern = 'WACCM-monthly-dma8-%d.csv';
models(4).years = [1990:1996, 2000:2001];

% CESM2.2-CAM4-Chem 2002-2022
models(5).name = 'CESM2_2_CAM4_Chem';
models(5).folder = 'CESM2.2-CAM4-Chem 2002-2022';
models(5).pattern = 'CESM2.2-monthly-dma8-%d.csv';
models(5).years = 2002:2022;

% CHASER 1990-2010
models(6).name = 'CHASER';
models(6).folder = 'CHASER 1990-2010';
models(6).pattern = 'CHASER-monthly-dma8-%d.csv';
models(6).years = 1990:2010;

% GEOS-CF 2018-2023
models(7).name = 'GEOS_CF';
models(7).folder = 'GEOS-CF 2018-2023';
models(7).pattern = 'GEOS-CF-monthly-dma8-%d.csv';
models(7).years = 2018:2023;

% GEOS-chem 2006-2016
models(8).name = 'GEOS_chem';
models(8).folder = 'GEOS-chem 2006-2016';
models(8).pattern = 'GEOS_monthly_%d.csv';
models(8).years = 2006:2016;

% GEOS-GMI 1996-2022
models(9).name = 'GEOS_GMI';
models(9).folder = 'GEOS-GMI 1996 - 2022';
models(9).pattern = 'GEOS-GMI-monthly-dma8-%d.csv';
models(9).years = 1996:2022;

% GFDL AM3 1990-2007
models(10).name = 'GFDL_AM3';
models(10).folder = 'GFDL AM3 1990-2007';
models(10).pattern = 'GFDL AM3-monthly-dma8-%d.csv';
models(10).years = 1990:2000;
models(10).pattern2 = 'GFDL AM3-monthly-mda8-%d.csv';
models(10).years2 = 2001:2007;

% MERRA2-GMI 1990-2019
models(11).name = 'MERRA2_GMI';
models(11).folder = 'MERRA2-GMI 1990-2019';
models(11).pattern = 'MERRA-monthly-dma8-%d.csv';
models(11).years = 1990:2019;

% MOCAGE 1990-2010 (missing 1998)
models(12).name = 'MOCAGE';
models(12).folder = 'MOCAGE 1990-2010 (missing 1998)';
models(12).pattern = 'MOCAGE-monthly-dma8-%d.csv';
models(12).years = [1990:1997, 1999:2010];

% MRI-ESM1 1990-2010
models(13).name = 'MRI_ESM1';
models(13).folder = 'MRI-ESM1 1990-2010';
models(13).pattern = 'MRI-ESM1-monthly-dma8-%d.csv';
models(13).years = 1990:2010;

% MRI-ESM2 2011-2017
models(14).name = 'MRI_ESM2';
models(14).folder = 'MRI-ESM2 2011-2017';
models(14).pattern = 'MRI-ESM2-monthly-dma8-%d.csv';
models(14).years = 2011:2017;

% TCR-2 2005-2021
models(15).name = 'TCR2';
models(15).folder = 'TCR-2 2005-2021';
models(15).pattern = 'TCR2_monthly_%d.csv';
models(15).years = 2005:2021;

% M3fusion 
models(16).name = 'M3fusion';
models(16).folder = 'M3fusion 1990-2023/yearlyFiles';
models(16).pattern = 'M3fusion-monthly-mda8-%d.csv';
models(16).years = 1990:2023;

% UKML 
models(17).name = 'UKML';
models(17).folder = 'UK Cambridge ML/yearlyFiles';
models(17).pattern = 'reshaped_popwt_ozone_%d.csv';
models(17).years = 2003;

% NJML 
models(18).name = 'NJML';
models(18).folder = 'nanjing university ML/yearlyFiles';
models(18).pattern = 'NJML-monthly-dma8-%d.csv';
models(18).years = 2004;

models = models(17:18);

%% Process Each Model
nModels = length(models);
results = struct();

for iModel = 1:nModels
    modelName = models(iModel).name;
    modelFolder = fullfile(baseDir, models(iModel).folder);
    
    fprintf('\n[%d/%d] Processing %s...\n', iModel, nModels, modelName);
    fprintf('  Folder: %s\n', models(iModel).folder);
    
    % Check if folder exists
    if ~exist(modelFolder, 'dir')
        fprintf('  WARNING: Folder not found, skipping.\n');
        continue;
    end
    
    % Extract spatial information
    try
        spatialInfo = extractSpatialGrid(modelFolder, models(iModel));
        
        if ~isempty(spatialInfo)
            % Check grid uniformity
            fprintf('  Checking grid uniformity...\n');
            try
                gridData = struct('lon', spatialInfo.lon, 'lat', spatialInfo.lat);
                uniformityCheck = analyzeGridUniformity(gridData, 'struct');
                spatialInfo.isUniform = uniformityCheck.isUniform;
                spatialInfo.gridType = uniformityCheck.gridType;
                spatialInfo.lonResolution = uniformityCheck.lonResolution;
                spatialInfo.latResolution = uniformityCheck.latResolution;
                fprintf('  Grid type: %s\n', upper(uniformityCheck.gridType));
                if uniformityCheck.isUniform
                    fprintf('  Resolution: %.4f° × %.4f°\n', ...
                        uniformityCheck.lonResolution, uniformityCheck.latResolution);
                    fprintf('  Thinning: VALID (can use simple thinning)\n');
                else
                    fprintf('  Thinning: CAUTION (%s)\n', uniformityCheck.recommendations);
                end
            catch
                spatialInfo.isUniform = false;
                spatialInfo.gridType = 'unknown';
                spatialInfo.lonResolution = NaN;
                spatialInfo.latResolution = NaN;
                fprintf('  Uniformity check failed - assuming irregular\n');
            end

            % Save results
            results.(modelName) = spatialInfo;

            % Save individual .mat file with uniformity info
            matFilename = sprintf('%s_spatial_grid.mat', modelName);
            matPath = fullfile(outputDir, matFilename);

            lon = spatialInfo.lon;
            lat = spatialInfo.lat;
            nGridPoints = spatialInfo.nGridPoints;
            yearsChecked = spatialInfo.yearsChecked;
            isConsistent = spatialInfo.isConsistent;
            isUniform = spatialInfo.isUniform;
            gridType = spatialInfo.gridType;
            lonResolution = spatialInfo.lonResolution;
            latResolution = spatialInfo.latResolution;

            save(matPath, 'lon', 'lat', 'nGridPoints', 'yearsChecked', ...
                'isConsistent', 'isUniform', 'gridType', 'lonResolution', 'latResolution');

            fprintf('  ✓ Saved: %s\n', matFilename);
            fprintf('  Grid size: %d points\n', nGridPoints);
            fprintf('  Lon range: [%.2f, %.2f]\n', min(lon), max(lon));
            fprintf('  Lat range: [%.2f, %.2f]\n', min(lat), max(lat));
            fprintf('  Years checked: %d\n', length(yearsChecked));
            fprintf('  Spatial consistency: %s\n', ...
                iif(isConsistent, 'PASS', 'FAIL'));
        else
            fprintf('  WARNING: Could not extract spatial information\n');
        end
    catch ME
        fprintf('  ERROR: %s\n', ME.message);
    end
end

%% Save Combined Results
fprintf('\n========================================\n');
fprintf('  SAVING COMBINED RESULTS\n');
fprintf('========================================\n');

combinedFile = fullfile(outputDir, 'all_models_spatial_grids.mat');
save(combinedFile, 'results', 'models');
fprintf('Combined file saved: %s\n', combinedFile);

%% Summary Report
fprintf('\n========================================\n');
fprintf('  SUMMARY REPORT\n');
fprintf('========================================\n\n');

fprintf('%-25s %10s %15s %15s\n', 'Model', 'Grid Pts', 'Status', 'Years');
fprintf('%s\n', repmat('-', 70, 1));

modelNames = fieldnames(results);
for i = 1:length(modelNames)
    modelName = modelNames{i};
    info = results.(modelName);
    
    status = iif(info.isConsistent, 'CONSISTENT', 'INCONSISTENT');
    
    fprintf('%-25s %10d %15s %15s\n', ...
        modelName, info.nGridPoints, status, ...
        sprintf('%d-%d', min(info.yearsChecked), max(info.yearsChecked)));
end

fprintf('\nTotal models processed: %d\n', length(modelNames));
fprintf('Output directory: %s\n', outputDir);

%% Helper Functions

function spatialInfo = extractSpatialGrid(modelFolder, modelDef)
    % Extract and verify spatial grid consistency across years
    
    spatialInfo = struct();
    spatialInfo.lon = [];
    spatialInfo.lat = [];
    spatialInfo.nGridPoints = 0;
    spatialInfo.yearsChecked = [];
    spatialInfo.isConsistent = false;
    
    % Get list of years to check
    years = modelDef.years;
    
    % Reference spatial grid (from first available year)
    refLon = [];
    refLat = [];
    refYear = [];
    
    % Try to find first valid file
    for iYear = 1:length(years)
        year = years(iYear);
        
        % Try primary pattern
        filename = sprintf(modelDef.pattern, year);
        filepath = fullfile(modelFolder, filename);
        
        % If primary doesn't exist, try secondary pattern (for GFDL AM3)
        if ~exist(filepath, 'file') && isfield(modelDef, 'pattern2')
            filename = sprintf(modelDef.pattern2, year);
            filepath = fullfile(modelFolder, filename);
        end
        
        if exist(filepath, 'file')
            try
                % Read CSV
                data = readtable(filepath);
                
                % Extract lon and lat (first two columns)
                refLon = data{:, 1};
                refLat = data{:, 2};
                refYear = year;
                
                fprintf('  Reference year: %d (%d grid points)\n', refYear, length(refLon));
                break;
            catch ME
                fprintf('  Warning: Could not read %s: %s\n', filename, ME.message);
            end
        end
    end
    
    if isempty(refLon)
        fprintf('  ERROR: No valid files found\n');
        return;
    end
    
    % Now verify consistency across all years
    yearsChecked = refYear;
    isConsistent = true;
    nInconsistent = 0;
    
    for iYear = 1:length(years)
        year = years(iYear);
        
        if year == refYear
            continue;
        end
        
        % Try primary pattern
        filename = sprintf(modelDef.pattern, year);
        filepath = fullfile(modelFolder, filename);
        
        % If primary doesn't exist, try secondary pattern
        if ~exist(filepath, 'file') && isfield(modelDef, 'pattern2')
            filename = sprintf(modelDef.pattern2, year);
            filepath = fullfile(modelFolder, filename);
        end
        
        if ~exist(filepath, 'file')
            fprintf('  Missing file: %s\n', filename);
            continue;
        end
        
        try
            % Read CSV
            data = readtable(filepath);
            
            % Extract lon and lat
            lon = data{:, 1};
            lat = data{:, 2};
            
            % Check consistency
            if length(lon) ~= length(refLon)
                fprintf('  WARNING: Year %d has different grid size (%d vs %d)\n', ...
                    year, length(lon), length(refLon));
                isConsistent = false;
                nInconsistent = nInconsistent + 1;
            elseif max(abs(lon - refLon)) > 1e-6 || max(abs(lat - refLat)) > 1e-6
                fprintf('  WARNING: Year %d has different coordinates\n', year);
                isConsistent = false;
                nInconsistent = nInconsistent + 1;
            end
            
            yearsChecked = [yearsChecked, year];
            
        catch ME
            fprintf('  Warning: Could not read %s: %s\n', filename, ME.message);
        end
    end
    
    % Package results
    spatialInfo.lon = refLon;
    spatialInfo.lat = refLat;
    spatialInfo.nGridPoints = length(refLon);
    spatialInfo.yearsChecked = sort(yearsChecked);
    spatialInfo.isConsistent = isConsistent;
    spatialInfo.nInconsistent = nInconsistent;
    
    if nInconsistent > 0
        fprintf('  WARNING: %d/%d years had inconsistent grids\n', ...
            nInconsistent, length(yearsChecked));
    end
end

function result = iif(condition, trueVal, falseVal)
    % Inline if function
    if condition
        result = trueVal;
    else
        result = falseVal;
    end
end