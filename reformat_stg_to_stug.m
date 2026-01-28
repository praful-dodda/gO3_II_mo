function grid_data = reformat_stg_to_stug(stg_data, varargin)
% REFORMAT_STG_TO_STUG - Reformat STG data to STUG structure with caching support
%
% Converts STG data to STUG structure, automatically handling both uniform
% and non-uniform grids. Includes smart caching to avoid redundant reformatting.
%
% SYNTAX:
%   grid_data = reformat_stg_to_stug(stg_data)
%   grid_data = reformat_stg_to_stug(stg_data, 'Name', Value, ...)
%
% INPUT:
%   stg_data - struct with fields:
%              .sMS  [N×2 double]  - Grid point locations [lon, lat]
%              .tME  [1×T double]  - Time values
%              .Xms  [N×T single]  - Data values (grid points × time)
%              .Xvs  [N×T single]  - Variances (optional)
%
% OPTIONAL PARAMETERS:
%   % Grid processing:
%   'tolerance'     - Tolerance for grid uniformity check (default: 1e-6)
%   'resolution'    - Grid resolution for non-uniform data (default: auto)
%   'method'        - Interpolation method if non-uniform: 'linear', 'hybrid' (default: 'hybrid')
%
%   % Caching:
%   'cacheDir'      - Directory to save/load cached STUG data (default: '0cache/stug')
%   'modelName'     - Model/dataset name for file naming (default: 'unknown')
%   'areaCode'      - Geographic area code (default: 'global')
%   'dataFormat'    - Data format identifier (default: 'stug')
%   'forceReformat' - Force reformatting even if cached file exists (default: false)
%   'saveCache'     - Save reformatted data to cache (default: true)
%
%   % Other:
%   'verbose'       - Show progress messages (default: true)
%
% OUTPUT:
%   grid_data - struct with fields:
%               .x    [nx×1 double]   - Longitude grid vector
%               .y    [ny×1 double]   - Latitude grid vector
%               .time [nt×1 double]   - Time vector
%               .Lon  [nx×ny double]  - Longitude mesh
%               .Lat  [nx×ny double]  - Latitude mesh
%               .Z    [nx×ny×nt single] - Data array
%               .Zvar [nx×ny×nt single] - Variance array (if Xvs provided)
%               .metadata - Reformatting information
%
% EXAMPLES:
%   % Basic usage (with caching)
%   grid_data = reformat_stg_to_stug(KS.softdata, 'modelName', 'M3fusion');
%
%   % With detailed naming
%   grid_data = reformat_stg_to_stug(KS.softdata, ...
%       'modelName', 'OMI-MLS', 'areaCode', 'NA', ...
%       'dataFormat', 'stug_v2');
%
%   % Force reformat (skip cache)
%   grid_data = reformat_stg_to_stug(KS.softdata, 'forceReformat', true);
%
%   % No caching
%   grid_data = reformat_stg_to_stug(KS.softdata, 'saveCache', false);
%
% CACHING:
%   Cached files are saved with naming convention:
%   stug_{modelName}_{areaCode}_y{startYear}-{endYear}_{dataHash}.mat
%
% BEHAVIOR:
%   1. If cached file exists and forceReformat=false: Load from cache
%   2. Check if grid is uniform:
%      - If uniform: Fast reshaping (no interpolation)
%      - If non-uniform: Use stg_to_stug with hybrid method
%   3. If saveCache=true: Save result to cache file
%
% SEE ALSO: stg_to_stug, neighbours_stug_optimized, neighbours_stug_index

%% Parse inputs
p = inputParser;
addRequired(p, 'stg_data', @isstruct);

% Grid processing parameters
addParameter(p, 'tolerance', 1e-6, @(x) isscalar(x) && x > 0);
addParameter(p, 'resolution', [], @(x) isempty(x) || (isscalar(x) && x > 0));
addParameter(p, 'method', 'hybrid', @(x) ismember(x, {'linear', 'natural', 'nearest', 'hybrid'}));

% Caching parameters
addParameter(p, 'cacheDir', '0cache/stug', @ischar);
addParameter(p, 'modelName', 'unknown', @ischar);
addParameter(p, 'areaCode', 'global', @ischar);
addParameter(p, 'dataFormat', 'stug', @ischar);
addParameter(p, 'forceReformat', false, @islogical);
addParameter(p, 'saveCache', true, @islogical);

% Other parameters
addParameter(p, 'verbose', true, @islogical);

parse(p, stg_data, varargin{:});
opts = p.Results;

%% Validate input structure
required_fields = {'sMS', 'tME', 'Xms'};
for i = 1:length(required_fields)
    if ~isfield(stg_data, required_fields{i})
        error('Input structure must contain field: %s', required_fields{i});
    end
end

%% Extract data
sMS = stg_data.sMS;      % [N×2] grid point locations
tME = stg_data.tME;      % [1×T] or [T×1] time values
Xms = stg_data.Xms;      % [N×T] data values

%% Check if fields are empty
empty_fields = {};
if isempty(sMS)
    empty_fields{end+1} = 'sMS';
end
if isempty(tME)
    empty_fields{end+1} = 'tME';
end
if isempty(Xms)
    empty_fields{end+1} = 'Xms';
end

if ~isempty(empty_fields)
    if opts.verbose
        fprintf('\n⚠️  WARNING: Input structure contains empty fields:\n');
        for i = 1:length(empty_fields)
            fprintf('   - %s is empty\n', empty_fields{i});
        end
        fprintf('Returning empty structure.\n\n');
    end

    % Return empty structure
    grid_data = struct('x', [], 'y', [], 'time', [], 'Lon', [], 'Lat', [], ...
                       'Z', [], 'Zvar', [], 'metadata', struct());
    return;
end

[n_points, n_times] = size(Xms);

% Validate dimensions match
if size(sMS, 1) ~= n_points
    error('sMS has %d points but Xms has %d points. Dimensions must match.', ...
          size(sMS, 1), n_points);
end

%% Generate cache file name based on data characteristics
% Extract year range from time data
allYears = floor(tME(:));
if ~isempty(tME)
    year_start = min(allYears);
    year_end = max(allYears);
else
    year_start = 0;
    year_end = 0;
end

% Create unique hash from spatial and temporal bounds
lon_range = [min(sMS(:,1)), max(sMS(:,1))];
lat_range = [min(sMS(:,2)), max(sMS(:,2))];
hash_string = sprintf('%.6f_%.6f_%.6f_%.6f_%d_%d_%d', ...
    lon_range(1), lon_range(2), lat_range(1), lat_range(2), ...
    n_points, n_times, length(tME));
data_hash = char(java.security.MessageDigest.getInstance('MD5').digest(uint8(hash_string)));
data_hash = sprintf('%02x', data_hash);
data_hash = data_hash(1:8);  % Use first 8 characters

% Construct cache file name
cache_filename = sprintf('stug_%s_%s_y%d-%d_%s.mat', ...
    opts.modelName, opts.areaCode, year_start, year_end, data_hash);
cache_filepath = fullfile(opts.cacheDir, cache_filename);

%% Try to load from cache
if ~opts.forceReformat && exist(cache_filepath, 'file')
    if opts.verbose
        fprintf('=== Loading Cached STUG Data ===\n');
        fprintf('Cache file: %s\n', cache_filename);
    end

    try
        cached = load(cache_filepath);
        grid_data = cached.grid_data;

        if opts.verbose
            fprintf('✓ Loaded from cache successfully\n');
            fprintf('  Grid: %d × %d × %d\n', length(grid_data.x), ...
                    length(grid_data.y), length(grid_data.time));
        end

        % Update metadata to indicate it was loaded from cache
        grid_data.metadata.loaded_from_cache = true;
        grid_data.metadata.cache_file = cache_filepath;
        grid_data.metadata.load_time = datetime('now');
        return;
    catch ME
        if opts.verbose
            warning('Failed to load cache file: %s\nReformatting from scratch...', ME.message);
        end
    end
end

%% Reformat data (either uniform reshape or hybrid regridding)
if opts.verbose
    fprintf('=== Reformatting STG to STUG Structure ===\n');
    fprintf('Input: %d grid points × %d time steps\n', n_points, n_times);
end

%% Check grid uniformity and determine processing method
lon_vals = sMS(:, 1);
lat_vals = sMS(:, 2);

% Find unique values
unique_lon = unique(lon_vals);
unique_lat = unique(lat_vals);

nx = length(unique_lon);
ny = length(unique_lat);

if opts.verbose
    fprintf('Detected grid dimensions: %d (lon) × %d (lat)\n', nx, ny);
end

% Check if grid is complete and uniform
is_complete_grid = (nx * ny == n_points);
is_uniform = false;

if is_complete_grid
    % Grid has right number of points, check if uniformly spaced
    dx_uniform = true;
    dy_uniform = true;

    % Check longitude spacing
    if nx > 1
        dx_vec = diff(unique_lon);
        dx_mean = mean(dx_vec);
        dx_std = std(dx_vec);
        dx_uniform = (dx_std / abs(dx_mean) <= opts.tolerance);
        dx = dx_mean;
    else
        dx = NaN;
    end

    % Check latitude spacing
    if ny > 1
        dy_vec = diff(unique_lat);
        dy_mean = mean(dy_vec);
        dy_std = std(dy_vec);
        dy_uniform = (dy_std / abs(dy_mean) <= opts.tolerance);
        dy = dy_mean;
    else
        dy = NaN;
    end

    is_uniform = dx_uniform && dy_uniform;
end

% Decide on processing method
if is_uniform
    % Grid is uniform - use fast reshaping
    if opts.verbose
        fprintf('Grid is uniform - using fast reshaping\n');
        if nx > 1
            fprintf('  Longitude spacing: %.6f° (uniform ✓)\n', dx);
        end
        if ny > 1
            fprintf('  Latitude spacing: %.6f° (uniform ✓)\n', dy);
        end
    end
    use_hybrid_method = false;
else
    % Grid is non-uniform or irregular - use stg_to_stug hybrid method
    if opts.verbose
        fprintf('⚠️  Grid is NON-UNIFORM or irregular\n');
        if ~is_complete_grid
            fprintf('  Grid incomplete: expected %d points, got %d\n', nx*ny, n_points);
        else
            if nx > 1 && dx_std / abs(dx_mean) > opts.tolerance
                fprintf('  Lon spacing varies: mean=%.6f°, std=%.6f° (%.2f%%)\n', ...
                    dx_mean, dx_std, 100*dx_std/abs(dx_mean));
            end
            if ny > 1 && dy_std / abs(dy_mean) > opts.tolerance
                fprintf('  Lat spacing varies: mean=%.6f°, std=%.6f° (%.2f%%)\n', ...
                    dy_mean, dy_std, 100*dy_std/abs(dy_mean));
            end
        end
        fprintf('→ Using stg_to_stug with %s method for regridding\n', opts.method);
    end
    use_hybrid_method = true;
end

%% Process data based on grid type
if use_hybrid_method
    % Use stg_to_stug for non-uniform data
    stug_opts = {'method', opts.method, 'verbose', opts.verbose};

    if ~isempty(opts.resolution)
        stug_opts = [stug_opts, {'resolution', opts.resolution}];
    end

    % Add variance option if Xvs field exists
    if isfield(stg_data, 'Xvs') && ~isempty(stg_data.Xvs)
        stug_opts = [stug_opts, {'includeVariance', true}];
    end

    % Call stg_to_stug
    grid_data = stg_to_stug(stg_data, stug_opts{:});

    % Add metadata about processing method
    grid_data.metadata.source_format = 'STG_nonuniform';
    grid_data.metadata.regridding_method = opts.method;
    grid_data.metadata.reformatting_function = 'stg_to_stug';

else
    % Grid is uniform - use fast reshaping below
    % (Continue with existing reshape logic)

    %% Fast uniform grid reshaping

    % Grid vectors (ensure column vectors)
    grid_data.x = unique_lon(:);
    grid_data.y = unique_lat(:);
    grid_data.time = tME(:);

    % Create coordinate meshes
    [X, Y] = meshgrid(grid_data.x, grid_data.y);
    grid_data.Lon = X';  % Transpose to [nx, ny]
    grid_data.Lat = Y';

    if opts.verbose
        fprintf('Reshaping data from [%d×%d] to [%d×%d×%d]...\n', ...
                n_points, n_times, nx, ny, n_times);
    end

    % Pre-allocate
    grid_data.Z = NaN(nx, ny, n_times, 'single');

    % Build lookup for coordinate to index mapping
    [~, lon_idx] = ismember(lon_vals, unique_lon);
    [~, lat_idx] = ismember(lat_vals, unique_lat);

    % Reshape data
    for t = 1:n_times
        for p = 1:n_points
            i = lon_idx(p);
            j = lat_idx(p);
            grid_data.Z(i, j, t) = Xms(p, t);
        end
    end

    % Also reshape variance if provided
    if isfield(stg_data, 'Xvs') && ~isempty(stg_data.Xvs)
        if opts.verbose
            fprintf('Reshaping variance data...\n');
        end

        Xvs = stg_data.Xvs;
        grid_data.Zvar = NaN(nx, ny, n_times, 'single');

        for t = 1:n_times
            for p = 1:n_points
                i = lon_idx(p);
                j = lat_idx(p);
                grid_data.Zvar(i, j, t) = Xvs(p, t);
            end
        end
    end

    % Validate the reshaping
    n_original_valid = sum(~isnan(Xms(:)));
    n_reshaped_valid = sum(~isnan(grid_data.Z(:)));

    if n_original_valid ~= n_reshaped_valid
        warning(['Data count mismatch after reshaping!\n' ...
                 'Original valid points: %d\n' ...
                 'Reshaped valid points: %d\n' ...
                 'Some data may have been lost or duplicated.'], ...
                 n_original_valid, n_reshaped_valid);
    end

    % Store metadata
    grid_data.metadata = struct();
    grid_data.metadata.source_format = 'STG_uniform';
    grid_data.metadata.n_source_points = n_points;
    grid_data.metadata.n_source_times = n_times;
    grid_data.metadata.grid_size = [nx, ny, n_times];
    grid_data.metadata.spacing = [dx, dy];
    grid_data.metadata.reformatting_date = datetime('now');
    grid_data.metadata.tolerance_used = opts.tolerance;
    grid_data.metadata.n_valid_original = n_original_valid;
    grid_data.metadata.n_valid_reshaped = n_reshaped_valid;
    grid_data.metadata.reformatting_function = 'reformat_stg_to_stug (fast reshape)';

end  % End of uniform vs non-uniform processing

%% Add common metadata
grid_data.metadata.loaded_from_cache = false;
grid_data.metadata.model_name = opts.modelName;
grid_data.metadata.area_code = opts.areaCode;
grid_data.metadata.data_format = opts.dataFormat;
grid_data.metadata.year_range = [year_start, year_end];

%% Save to cache if requested
if opts.saveCache
    % Create cache directory if it doesn't exist
    if ~exist(opts.cacheDir, 'dir')
        mkdir(opts.cacheDir);
        if opts.verbose
            fprintf('Created cache directory: %s\n', opts.cacheDir);
        end
    end

    try
        save(cache_filepath, 'grid_data', '-v7.3');
        if opts.verbose
            fprintf('✓ Saved to cache: %s\n', cache_filename);
        end
        grid_data.metadata.cache_file = cache_filepath;
    catch ME
        if opts.verbose
            warning('Failed to save cache file: %s', ME.message);
        end
    end
end

%% Summary
if opts.verbose
    fprintf('\n=== Reformatting Complete ===\n');
    fprintf('Output grid: %d × %d × %d\n', ...
            length(grid_data.x), length(grid_data.y), length(grid_data.time));

    if isfield(grid_data.metadata, 'spacing')
        fprintf('Grid spacing: %.6f° × %.6f°\n', ...
                grid_data.metadata.spacing(1), grid_data.metadata.spacing(2));
    end

    n_valid = sum(~isnan(grid_data.Z(:)));
    n_total = numel(grid_data.Z);
    fprintf('Valid data points: %d / %d (%.1f%%)\n', ...
            n_valid, n_total, 100 * n_valid / n_total);
    fprintf('Structure is ready for neighbours_stug_* functions\n');

    if opts.saveCache && isfield(grid_data.metadata, 'cache_file')
        fprintf('Cached at: %s\n', grid_data.metadata.cache_file);
    end
end

end
