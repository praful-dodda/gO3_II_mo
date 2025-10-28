function ctmData = loadRAMPdata(modelName, years, dataDir, forceReload)
% loadRAMPdata - Load RAMP-corrected CTM data from parquet files
%
% Reads lambda1 (mean) and lambda2 (variance) parquet files for specified
% years and creates a cached .mat file for fast subsequent loading.
%
% SYNTAX:
%   ctmData = loadRAMPdata(modelName, years, dataDir, forceReload)
%
% INPUTS:
%   modelName   - Model identifier (e.g., 'UKML')
%   years       - Years to load (e.g., [2015 2016 2017])
%   dataDir     - Directory containing parquet files (default: '1data/CTM')
%   forceReload - Force reload from parquet (1) or use cache (0, default)
%
% OUTPUTS:
%   ctmData - Structure with fields:
%             .modelName  - Model identifier
%             .years      - Years included
%             .lon        - Longitude vector [nGrid × 1]
%             .lat        - Latitude vector [nGrid × 1]
%             .tME        - Time vector in decimal years [1 × nMonths]
%             .Z          - Mean field (lambda1) [nGrid × nMonths]
%             .Zv         - Variance field (lambda2) [nGrid × nMonths]
%             .Zunit      - Units string
%             .version    - RAMP version
%             .loadedAt   - Timestamp
%
% EXAMPLE:
%   % Load 2015-2020 UKML data
%   ctm = loadRAMPdata('UKML', [2015:2020]);
%
%   % Force reload from parquet files
%   ctm = loadRAMPdata('UKML', [2015:2020], '1data/CTM', 1);
%
% FILE NAMING CONVENTION:
%   Parquet files should be named:
%     lambda1_{modelName}_{year}_v{version}-parallel.parquet
%     lambda2_{modelName}_{year}_v{version}-parallel.parquet
%
%   Example:
%     lambda1_UKML_2017_v3-parallel.parquet
%     lambda2_UKML_2017_v3-parallel.parquet

%% Input Validation
if nargin < 1 || isempty(modelName), modelName = 'UKML'; end
if nargin < 2 || isempty(years), years = 2015:2020; end
if nargin < 3 || isempty(dataDir), dataDir = fullfile('1data', 'CTM'); end
if nargin < 4, forceReload = 0; end

% Ensure years is a vector
if isscalar(years)
    years = years:years;
end

fprintf('\n========================================\n');
fprintf('  LOAD RAMP-CORRECTED CTM DATA\n');
fprintf('========================================\n');
fprintf('Model: %s\n', modelName);
fprintf('Years: %s\n', mat2str(years));
fprintf('Data directory: %s\n', dataDir);

%% Check Cache
cacheDir = fullfile('1data', 'CTM');
if ~exist(cacheDir, 'dir')
    mkdir(cacheDir);
end

% Determine RAMP version from first file
sampleFile = dir(fullfile(dataDir, sprintf('lambda1_%s_%d_v*-parallel.parquet', modelName, years(1))));
if isempty(sampleFile)
    error('No parquet files found for %s year %d in %s', modelName, years(1), dataDir);
end

% Extract version from filename (e.g., "v3" from "..._v3-parallel.parquet")
tokens = regexp(sampleFile(1).name, '_v(\d+)-parallel', 'tokens');
if ~isempty(tokens)
    rampVersion = str2double(tokens{1}{1});
else
    rampVersion = 1;  % Default
end

cacheFile = sprintf('CTM_RAMP_%s_%d-%d_v%d.mat', ...
    modelName, min(years), max(years), rampVersion);
cachePath = fullfile(cacheDir, cacheFile);

%% Load from Cache or Parquet
if exist(cachePath, 'file') && ~forceReload
    fprintf('\nLoading from cache: %s\n', cacheFile);
    tic;
    load(cachePath, 'ctmData');
    tLoad = toc;
    fprintf('  Loaded in %.2f seconds\n', tLoad);

    % Verify cached data matches requested years
    if isequal(ctmData.years, years)
        fprintf('  Grid points: %d\n', length(ctmData.lon));
        fprintf('  Time periods: %d\n', length(ctmData.tME));
        fprintf('  Data completeness: %.1f%%\n', 100*sum(~isnan(ctmData.Z(:)))/numel(ctmData.Z));
        fprintf('========================================\n\n');
        return;
    else
        warning('Cached data years %s do not match requested %s. Reloading...', ...
            mat2str(ctmData.years), mat2str(years));
    end
end

fprintf('\nCache not found or force reload requested.\n');
fprintf('Loading from parquet files...\n');

%% Load Parquet Files
nYears = length(years);
nMonths = nYears * 12;

% Storage for all data
lambda1_all = [];
lambda2_all = [];
lon_grid = [];
lat_grid = [];
tME_all = [];

for iYear = 1:nYears
    year = years(iYear);

    fprintf('\n--- Processing Year %d ---\n', year);

    % Construct filenames
    lambda1File = sprintf('lambda1_%s_%d_v%d-parallel.parquet', modelName, year, rampVersion);
    lambda2File = sprintf('lambda2_%s_%d_v%d-parallel.parquet', modelName, year, rampVersion);

    lambda1Path = fullfile(dataDir, lambda1File);
    lambda2Path = fullfile(dataDir, lambda2File);

    % Check files exist
    if ~exist(lambda1Path, 'file')
        error('Lambda1 file not found: %s', lambda1Path);
    end
    if ~exist(lambda2Path, 'file')
        error('Lambda2 file not found: %s', lambda2Path);
    end

    % Read lambda1 (mean)
    fprintf('  Reading %s...\n', lambda1File);
    tic;
    lambda1_table = parquetread(lambda1Path);
    tRead1 = toc;
    fprintf('    Loaded in %.2f seconds (%d rows)\n', tRead1, height(lambda1_table));

    % Read lambda2 (variance)
    fprintf('  Reading %s...\n', lambda2File);
    tic;
    lambda2_table = parquetread(lambda2Path);
    tRead2 = toc;
    fprintf('    Loaded in %.2f seconds (%d rows)\n', tRead2, height(lambda2_table));

    % Extract coordinates (first two columns)
    if iYear == 1
        % First year: get coordinates
        lon_grid = lambda1_table{:, 1};
        lat_grid = lambda1_table{:, 2};

        nGrid = length(lon_grid);
        fprintf('  Grid points: %d\n', nGrid);
        fprintf('  Lon range: [%.2f, %.2f]\n', min(lon_grid), max(lon_grid));
        fprintf('  Lat range: [%.2f, %.2f]\n', min(lat_grid), max(lat_grid));

        % Preallocate
        lambda1_all = NaN(nGrid, nMonths, 'single');
        lambda2_all = NaN(nGrid, nMonths, 'single');
    else
        % Verify coordinates match
        lon_year = lambda1_table{:, 1};
        lat_year = lambda1_table{:, 2};

        if ~isequal(lon_year, lon_grid) || ~isequal(lat_year, lat_grid)
            error('Grid coordinates do not match between years!');
        end
    end

    % Extract monthly data (columns 3-14)
    lambda1_year = lambda1_table{:, 1:12};
    lambda2_year = lambda2_table{:, 1:12};

    % Store in overall array
    monthIdx = (iYear-1)*12 + (1:12);
    lambda1_all(:, monthIdx) = single(lambda1_year);
    lambda2_all(:, monthIdx) = single(lambda2_year);

    % Create time vector for this year
    tME_year = year + (0:11)/12;
    tME_all = [tME_all, tME_year];

    fprintf('  Data range - Mean: [%.2f, %.2f] ppb\n', ...
        min(lambda1_year(:), [], 'omitnan'), max(lambda1_year(:), [], 'omitnan'));
    fprintf('  Data range - Variance: [%.4f, %.2f] ppb²\n', ...
        min(lambda2_year(:), [], 'omitnan'), max(lambda2_year(:), [], 'omitnan'));
end

%% Quality Control
fprintf('\n--- Quality Control ---\n');

% Count NaN values
nNaN_mean = sum(isnan(lambda1_all(:)));
nNaN_var = sum(isnan(lambda2_all(:)));
nTotal = numel(lambda1_all);

fprintf('  NaN in mean: %d / %d (%.2f%%)\n', nNaN_mean, nTotal, 100*nNaN_mean/nTotal);
fprintf('  NaN in variance: %d / %d (%.2f%%)\n', nNaN_var, nTotal, 100*nNaN_var/nTotal);

% Check for negative variance
nNegVar = sum(lambda2_all(:) < 0, 'omitnan');
if nNegVar > 0
    warning('Found %d negative variance values (%.2f%%). Setting to small positive.', ...
        nNegVar, 100*nNegVar/nTotal);
    lambda2_all(lambda2_all < 0) = 0.01;  % Small positive variance
end

% Check for infinite values
nInf_mean = sum(isinf(lambda1_all(:)));
nInf_var = sum(isinf(lambda2_all(:)));
if nInf_mean > 0 || nInf_var > 0
    warning('Found %d infinite mean and %d infinite variance values. Setting to NaN.', ...
        nInf_mean, nInf_var);
    lambda1_all(isinf(lambda1_all)) = NaN;
    lambda2_all(isinf(lambda2_all)) = NaN;
end

%% Package Output Structure
fprintf('\n--- Creating CTM Data Structure ---\n');

ctmData.modelName = modelName;
ctmData.years = years;
ctmData.lon = lon_grid;
ctmData.lat = lat_grid;
ctmData.tME = tME_all;
ctmData.Z = lambda1_all;      % Mean field (lambda1)
ctmData.Zv = lambda2_all;     % Variance field (lambda2)
ctmData.Zname = sprintf('%s-RAMP', modelName);
ctmData.Zunit = 'ppb';
ctmData.Zlabel = sprintf('%s RAMP-corrected MDA8 Ozone', modelName);
ctmData.version = rampVersion;
ctmData.loadedAt = datestr(now);
ctmData.nGrid = length(lon_grid);
ctmData.nMonths = nMonths;

fprintf('  Model: %s (RAMP v%d)\n', modelName, rampVersion);
fprintf('  Grid points: %d\n', ctmData.nGrid);
fprintf('  Time periods: %d months (%d years)\n', nMonths, nYears);
fprintf('  Mean range: [%.2f, %.2f] %s\n', ...
    min(ctmData.Z(:), [], 'omitnan'), max(ctmData.Z(:), [], 'omitnan'), ctmData.Zunit);
fprintf('  Variance range: [%.4f, %.2f] %s²\n', ...
    min(ctmData.Zv(:), [], 'omitnan'), max(ctmData.Zv(:), [], 'omitnan'), ctmData.Zunit);

%% Save Cache
fprintf('\n--- Saving Cache ---\n');
fprintf('  File: %s\n', cacheFile);

tic;
save(cachePath, 'ctmData', '-v7.3');
tSave = toc;

fileInfo = dir(cachePath);
fprintf('  Saved in %.2f seconds\n', tSave);
fprintf('  File size: %.1f MB\n', fileInfo.bytes / 1024^2);

fprintf('\n========================================\n');
fprintf('  CTM DATA LOADING COMPLETE\n');
fprintf('========================================\n\n');

end
