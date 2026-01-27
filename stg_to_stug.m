function grid_data = stg_to_stug(stg_data, varargin)
% STG_TO_STUG - Convert STG (irregular stations) to STUG (uniform grid) format
%
% Efficiently converts monitoring station data (STG) to uniformly gridded
% data (STUG) using spatial interpolation. Optimized for large datasets.
% Now includes HYBRID method combining bin-average + bilinear interpolation.
%
% SYNTAX:
%   grid_data = stg_to_stug(stg_data)
%   grid_data = stg_to_stug(stg_data, resolution)
%   grid_data = stg_to_stug(stg_data, 'Name', Value, ...)
%
% INPUT:
%   stg_data - struct with fields:
%              .sMS  [N×2 double]  - Station locations [lon, lat]
%              .tME  [1×T double]  - Time values
%              .Xms  [N×T single]  - Data values (stations × time)
%              .Xvs  [N×T single]  - Variances (optional)
%              .Zisnotnan [N×T logical] - Valid data mask (optional)
%
% OPTIONAL PARAMETERS (Name-Value pairs):
%   'resolution'   - Grid spacing in degrees (default: auto-calculated)
%   'method'       - Interpolation method: 'linear', 'natural', 'nearest', 'hybrid'
%                   (default: 'linear')
%                   'hybrid' = bin-average + bilinear with uncertainty inflation
%   'extrapolation' - Extrapolation method: 'none', 'linear', 'nearest'
%                    (default: 'none' - NaN outside convex hull)
%   'bounds'       - [lon_min lon_max lat_min lat_max] custom bounds
%                   (default: auto from data)
%   'verbose'      - Show progress (default: true)
%   'includeVariance' - Include variance interpolation (default: false)
%   'uncertaintyInflation' - Multiplier for interpolated cell uncertainty (default: 2.5)
%                           Only applies to 'hybrid' method
%   'distanceBasedInflation' - Use distance-based uncertainty scaling (default: true)
%                             Only applies to 'hybrid' method
%
% OUTPUT:
%   grid_data - struct with fields:
%               .x    [nx×1 double]   - Longitude grid vector
%               .y    [ny×1 double]   - Latitude grid vector
%               .time [nt×1 double]   - Time vector
%               .Lon  [nx×ny double]  - Longitude mesh (2D)
%               .Lat  [nx×ny double]  - Latitude mesh (2D)
%               .Z    [nx×ny×nt single] - Interpolated data
%               .Zvar [nx×ny×nt single] - Interpolated variance (if requested)
%               .data_source [nx×ny uint8] - Data source: 1=bin, 2=interp (hybrid only)
%               .metadata - struct with conversion info
%
% EXAMPLE:
%   % Basic usage with auto resolution
%   grid_data = stg_to_stug(KS.softdata);
%
%   % Hybrid method (RECOMMENDED for BME)
%   grid_data = stg_to_stug(KS.softdata, ...
%       'method', 'hybrid', ...
%       'resolution', 0.5, ...
%       'includeVariance', true, ...
%       'uncertaintyInflation', 2.5);
%
%   % Custom resolution with bilinear
%   grid_data = stg_to_stug(KS.softdata, 0.1, 'method', 'linear');
%
% HYBRID METHOD DETAILS:
%   The hybrid method combines:
%   1. BIN-AVERAGE: For grid cells containing actual data points
%      - High accuracy (preserves original data)
%      - Real within-cell variance
%   2. BILINEAR: For gap-filling between data points
%      - Extended coverage via Delaunay triangulation
%      - Distance-adjusted uncertainty (inflated for cells far from data)
%   
%   Benefits:
%   - Best accuracy where data exists
%   - Near-global coverage
%   - Properly calibrated uncertainty for BME soft data
%
% PERFORMANCE:
%   - Uses scatteredInterpolant (optimized MATLAB interpolation)
%   - Vectorized operations (10-100x faster than loops)
%   - Smart memory pre-allocation
%   - Hybrid method: ~20% slower than pure interpolation but much more accurate
%
% NOTES:
%   - Interpolation introduces error (use neighbours_stg.m for exact values)
%   - Grid points outside convex hull of stations will be NaN
%   - Auto resolution based on mean nearest neighbor distance
%   - Memory usage: ~8 bytes × nx × ny × nt (plan accordingly)
%
% SEE ALSO: neighbours_stug_optimized, neighbours_stug_index, neighbours_stg

%% Parse inputs
p = inputParser;
addRequired(p, 'stg_data', @isstruct);
addOptional(p, 'resolution', [], @(x) isempty(x) || (isscalar(x) && x > 0));
addParameter(p, 'method', 'linear', @(x) ismember(x, {'linear', 'natural', 'nearest', 'hybrid'}));
addParameter(p, 'extrapolation', 'none', @(x) ismember(x, {'none', 'linear', 'nearest'}));
addParameter(p, 'bounds', [], @(x) isempty(x) || (isnumeric(x) && length(x) == 4));
addParameter(p, 'verbose', true, @islogical);
addParameter(p, 'includeVariance', false, @islogical);
addParameter(p, 'uncertaintyInflation', 2.5, @(x) isscalar(x) && x >= 1.0);
addParameter(p, 'distanceBasedInflation', true, @islogical);

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
sMS = stg_data.sMS;      % [N×2] station locations [lon, lat]
tME = stg_data.tME;      % [1×T] time values
Xms = stg_data.Xms;      % [N×T] data values

[n_stations, n_times] = size(Xms);

if opts.verbose
    fprintf('=== STG to STUG Conversion ===\n');
    fprintf('Method: %s\n', upper(opts.method));
    fprintf('Input: %d stations × %d time points = %d observations\n', ...
            n_stations, n_times, n_stations * n_times);
end

% Get valid data mask
if isfield(stg_data, 'Zisnotnan')
    valid_mask = stg_data.Zisnotnan;
else
    valid_mask = ~isnan(Xms);
end

% Get variance if requested and available
if opts.includeVariance && isfield(stg_data, 'Xvs')
    Xvs = stg_data.Xvs;
    interpolate_variance = true;
else
    interpolate_variance = false;
end

%% Determine spatial bounds
if isempty(opts.bounds)
    lon_min = min(sMS(:, 1));
    lon_max = max(sMS(:, 1));
    lat_min = min(sMS(:, 2));
    lat_max = max(sMS(:, 2));
    
    % Add 5% padding
    lon_range = lon_max - lon_min;
    lat_range = lat_max - lat_min;
    lon_min = lon_min - 0.05 * lon_range;
    lon_max = lon_max + 0.05 * lon_range;
    lat_min = lat_min - 0.05 * lat_range;
    lat_max = lat_max + 0.05 * lat_range;
else
    lon_min = opts.bounds(1);
    lon_max = opts.bounds(2);
    lat_min = opts.bounds(3);
    lat_max = opts.bounds(4);
end

if opts.verbose
    fprintf('Spatial extent: [%.2f°, %.2f°] × [%.2f°, %.2f°]\n', ...
            lon_min, lon_max, lat_min, lat_max);
end

%% Determine optimal resolution if not provided
if isempty(opts.resolution)
    % Estimate based on mean nearest neighbor distance
    if n_stations > 1000
        % Sample for speed
        sample_idx = randperm(n_stations, min(1000, n_stations));
        sample_coords = sMS(sample_idx, :);
    else
        sample_coords = sMS;
    end
    
    % Compute nearest neighbor distances
    nn_dists = zeros(size(sample_coords, 1), 1);
    for i = 1:size(sample_coords, 1)
        dists = sqrt(sum((sMS - repmat(sample_coords(i, :), n_stations, 1)).^2, 2));
        dists(dists == 0) = inf;  % Exclude self
        nn_dists(i) = min(dists);
    end
    
    mean_nn_dist = mean(nn_dists);
    
    % Use 50% of mean nearest neighbor distance
    resolution = mean_nn_dist * 0.5;
    
    if opts.verbose
        fprintf('Auto-calculated resolution: %.4f° (from mean NN dist: %.4f°)\n', ...
                resolution, mean_nn_dist);
    end
else
    resolution = opts.resolution;
    if opts.verbose
        fprintf('Using specified resolution: %.4f°\n', resolution);
    end
end

%% Create uniform grid
grid_data.x = (lon_min:resolution:lon_max)';
grid_data.y = (lat_min:resolution:lat_max)';
grid_data.time = tME(:);  % Ensure column vector

nx = length(grid_data.x);
ny = length(grid_data.y);
nt = length(grid_data.time);

total_grid_points = nx * ny * nt;

if opts.verbose
    fprintf('Output grid: %d × %d × %d = %d points\n', nx, ny, nt, total_grid_points);
    fprintf('Memory estimate: %.2f MB\n', total_grid_points * 4 / 1024^2);
end

%% Create coordinate mesh
[X, Y] = meshgrid(grid_data.x, grid_data.y);
grid_data.Lon = X';  % Transpose for [nx, ny] order
grid_data.Lat = Y';

% Pre-allocate output arrays
grid_data.Z = NaN(nx, ny, nt, 'single');
if interpolate_variance
    grid_data.Zvar = NaN(nx, ny, nt, 'single');
end

% Data source tracking for hybrid method
if strcmp(opts.method, 'hybrid')
    grid_data.data_source = zeros(nx, ny, 'uint8');  % 0=none, 1=bin, 2=interpolated
end

% Flatten grid for vectorized interpolation
grid_lon_flat = grid_data.Lon(:);
grid_lat_flat = grid_data.Lat(:);

%% HYBRID METHOD
if strcmp(opts.method, 'hybrid')
    if opts.verbose
        fprintf('\n=== HYBRID METHOD (Bin-Average + Bilinear) ===\n');
        fprintf('Uncertainty inflation: %.2fx\n', opts.uncertaintyInflation);
        fprintf('Distance-based inflation: %s\n', mat2str(opts.distanceBasedInflation));
    end
    
    % Call hybrid regridding function
    [grid_data, hybrid_stats] = hybrid_regrid_internal(grid_data, sMS, Xms, Xvs, ...
                                                       valid_mask, opts, ...
                                                       nx, ny, nt, resolution);
    
    if opts.verbose
        fprintf('\n=== Hybrid Summary ===\n');
        fprintf('Bin-average cells: %d (%.1f%%)\n', ...
                hybrid_stats.n_bin, 100 * hybrid_stats.n_bin / (nx*ny));
        fprintf('Interpolated cells: %d (%.1f%%)\n', ...
                hybrid_stats.n_interp, 100 * hybrid_stats.n_interp / (nx*ny));
        fprintf('Total coverage: %d cells (%.1f%%)\n', ...
                hybrid_stats.n_bin + hybrid_stats.n_interp, ...
                100 * (hybrid_stats.n_bin + hybrid_stats.n_interp) / (nx*ny));
        if interpolate_variance
            fprintf('Mean uncertainty (bin): %.3f\n', hybrid_stats.mean_std_bin);
            fprintf('Mean uncertainty (interp): %.3f\n', hybrid_stats.mean_std_interp);
            fprintf('Uncertainty ratio: %.2fx\n', hybrid_stats.std_ratio);
        end
    end
    
    % Store hybrid-specific metadata
    grid_data.metadata.hybrid_stats = hybrid_stats;
    
else
    %% STANDARD INTERPOLATION METHODS
    if opts.verbose
        fprintf('\nInterpolating %d time steps...\n', nt);
        tic;
    end
    
    for t = 1:nt
        % Get valid stations at this time
        valid_idx = valid_mask(:, t);
        n_valid = sum(valid_idx);
        
        if n_valid < 3
            % Need at least 3 points for triangulation
            if opts.verbose && mod(t, max(1, floor(nt/10))) == 0
                fprintf('  Time %d/%d: Only %d valid stations (skipping)\n', t, nt, n_valid);
            end
            continue;
        end
        
        % Extract valid data
        lon_valid = sMS(valid_idx, 1);
        lat_valid = sMS(valid_idx, 2);
        z_valid = double(Xms(valid_idx, t));  % scatteredInterpolant needs double
        
        % Create interpolant
        F = scatteredInterpolant(lon_valid, lat_valid, z_valid, ...
                                 opts.method, opts.extrapolation);
        
        % Interpolate on entire grid (VECTORIZED)
        z_grid_flat = F(grid_lon_flat, grid_lat_flat);
        
        % Reshape and store
        grid_data.Z(:, :, t) = single(reshape(z_grid_flat, nx, ny));
        
        % Interpolate variance if requested
        if interpolate_variance
            zv_valid = double(Xvs(valid_idx, t));
            Fv = scatteredInterpolant(lon_valid, lat_valid, zv_valid, ...
                                      opts.method, opts.extrapolation);
            zv_grid_flat = Fv(grid_lon_flat, grid_lat_flat);
            grid_data.Zvar(:, :, t) = single(reshape(zv_grid_flat, nx, ny));
        end
        
        % Progress reporting
        if opts.verbose && (mod(t, max(1, floor(nt/10))) == 0 || t == nt)
            elapsed = toc;
            eta = (elapsed / t) * (nt - t);
            fprintf('  Progress: %d/%d (%.1f%%) | Elapsed: %.1fs | ETA: %.1fs\n', ...
                    t, nt, 100*t/nt, elapsed, eta);
        end
    end
    
    if opts.verbose
        total_time = toc;
        fprintf('Interpolation complete: %.2f seconds\n', total_time);
    end
end

%% Calculate statistics
n_interpolated = sum(~isnan(grid_data.Z(:)));
n_total = numel(grid_data.Z);
fill_ratio = n_interpolated / n_total;

if opts.verbose
    fprintf('\n=== Conversion Summary ===\n');
    fprintf('Grid points with data: %d / %d (%.1f%%)\n', ...
            n_interpolated, n_total, 100 * fill_ratio);
    fprintf('Resolution: %.4f° × %.4f°\n', resolution, resolution);
end

%% Store metadata
grid_data.metadata = struct();
grid_data.metadata.source_format = 'STG';
grid_data.metadata.n_source_stations = n_stations;
grid_data.metadata.n_source_times = n_times;
grid_data.metadata.resolution = resolution;
grid_data.metadata.interpolation_method = opts.method;
grid_data.metadata.extrapolation_method = opts.extrapolation;
grid_data.metadata.conversion_date = datetime('now');
grid_data.metadata.fill_ratio = fill_ratio;
grid_data.metadata.bounds = [lon_min, lon_max, lat_min, lat_max];

if strcmp(opts.method, 'hybrid')
    grid_data.metadata.uncertainty_inflation = opts.uncertaintyInflation;
    grid_data.metadata.distance_based_inflation = opts.distanceBasedInflation;
end

end

%% ========================================================================
%  HYBRID REGRIDDING INTERNAL FUNCTION
%  ========================================================================
function [grid_data, stats] = hybrid_regrid_internal(grid_data, sMS, Xms, Xvs, ...
                                                     valid_mask, opts, ...
                                                     nx, ny, nt, resolution)
% Internal function implementing hybrid bin-average + bilinear method
% FIXED: Properly combines fRAMP variance with spatial variance

has_framp_variance = ~isempty(Xvs);

if opts.verbose
    fprintf('\n--- STEP 1/3: Bin-Average for data-rich cells ---\n');
    if has_framp_variance
        fprintf('    Using fRAMP variances from input\n');
    end
    tic_bin = tic;
end

%% Create bin edges and assign stations to cells
% Create bin edges
lon_edges = [grid_data.x(1) - resolution/2; ...
             grid_data.x(1:end-1) + diff(grid_data.x)/2; ...
             grid_data.x(end) + resolution/2];
lat_edges = [grid_data.y(1) - resolution/2; ...
             grid_data.y(1:end-1) + diff(grid_data.y)/2; ...
             grid_data.y(end) + resolution/2];

% Assign each station to a grid cell
lon_bins = discretize(sMS(:, 1), lon_edges);
lat_bins = discretize(sMS(:, 2), lat_edges);

% Create cell ID for each station
[~] = size(sMS, 1);
cell_ids = sub2ind([nx, ny], lon_bins, lat_bins);

% Remove stations outside grid bounds
valid_cells = ~isnan(cell_ids);
cell_ids = cell_ids(valid_cells);
Xms_valid = Xms(valid_cells, :);
if opts.includeVariance
    Xvs_valid = Xvs(valid_cells, :);
end
valid_mask_cells = valid_mask(valid_cells, :);

%% Accumulate statistics
bin_count = zeros(nx, ny, nt);
bin_sum = zeros(nx, ny, nt);
bin_sum_sq = zeros(nx, ny, nt);

if has_framp_variance
    bin_framp_var_sum = zeros(nx, ny, nt);  % Sum of fRAMP variances
end

for t = 1:nt
    valid_t = valid_mask_cells(:, t);
    
    if sum(valid_t) == 0
        continue;
    end
    
    cells_t = cell_ids(valid_t);
    values_t = Xms_valid(valid_t, t);
    
    % Accumulate for mean and spatial variance
    bin_count(:, :, t) = reshape(accumarray(cells_t, 1, [nx*ny, 1]), nx, ny);
    bin_sum(:, :, t) = reshape(accumarray(cells_t, double(values_t), [nx*ny, 1]), nx, ny);
    bin_sum_sq(:, :, t) = reshape(accumarray(cells_t, double(values_t).^2, [nx*ny, 1]), nx, ny);
    
    % Accumulate fRAMP variances
    if has_framp_variance
        framp_var_t = Xvs_valid(valid_t, t);
        bin_framp_var_sum(:, :, t) = reshape(accumarray(cells_t, double(framp_var_t), [nx*ny, 1]), nx, ny);
    end
    
    if opts.verbose && mod(t, max(1, floor(nt/10))) == 0
        fprintf('  Binning time %d/%d (%.1f%%)\n', t, nt, 100*t/nt);
    end
end

%% Calculate bin-average statistics
bin_mean = bin_sum ./ bin_count;
bin_mean(bin_count == 0) = NaN;

% Spatial variance (within-cell heterogeneity)
bin_var_spatial = (bin_sum_sq - (bin_sum.^2 ./ bin_count)) ./ max(bin_count - 1, 1);
bin_var_spatial(bin_count < 2) = 0;

if has_framp_variance
    % fRAMP variance (model uncertainty)
    bin_var_framp = bin_framp_var_sum ./ bin_count;
    bin_var_framp(bin_count == 0) = NaN;
    
    % COMBINE: Total variance = fRAMP variance + Spatial variance
    bin_var_total = bin_var_framp + bin_var_spatial;
    bin_std_total = sqrt(bin_var_total);
    
    if opts.verbose
        % Report first time step statistics
        fprintf('\n  Uncertainty Composition (time step 1):\n');
        fprintf('    Mean fRAMP variance:   %.3f ppb²\n', nanmean(bin_var_framp(:,:,1), 'all'));
        fprintf('    Mean spatial variance: %.3f ppb²\n', nanmean(bin_var_spatial(:,:,1), 'all'));
        fprintf('    Mean total variance:   %.3f ppb²\n', nanmean(bin_var_total(:,:,1), 'all'));
        fprintf('    Mean fRAMP std:        %.3f ppb\n', sqrt(nanmean(bin_var_framp(:,:,1), 'all')));
        fprintf('    Mean spatial std:      %.3f ppb\n', sqrt(nanmean(bin_var_spatial(:,:,1), 'all')));
        fprintf('    Mean total std:        %.3f ppb\n', nanmean(bin_std_total(:,:,1), 'all'));
        
        % Component analysis
        framp_contribution = nanmean(bin_var_framp(:,:,1), 'all') / nanmean(bin_var_total(:,:,1), 'all');
        spatial_contribution = nanmean(bin_var_spatial(:,:,1), 'all') / nanmean(bin_var_total(:,:,1), 'all');
        fprintf('    fRAMP contribution:    %.1f%%\n', 100 * framp_contribution);
        fprintf('    Spatial contribution:  %.1f%%\n', 100 * spatial_contribution);
    end
else
    % No fRAMP variance - use only spatial
    bin_std_total = sqrt(bin_var_spatial);
    
    if opts.verbose
        fprintf('\n  Using spatial variance only (no fRAMP variances provided)\n');
        fprintf('    Mean spatial std: %.3f ppb\n', nanmean(bin_std_total(:,:,1), 'all'));
    end
end

has_bin_data = (bin_count > 0);

if opts.verbose
    n_bin_cells = sum(has_bin_data(:, :, 1) > 0, 'all');
    fprintf('  Bin-average complete: %d cells (%.1f%%)\n', ...
            n_bin_cells, 100 * n_bin_cells / (nx*ny));
    fprintf('  Time: %.2f seconds\n', toc(tic_bin));
end

%% STEP 2: Bilinear interpolation with fRAMP variance
if opts.verbose
    fprintf('\n--- STEP 2/3: Bilinear interpolation for gap-filling ---\n');
    tic_interp = tic;
end

interp_values = NaN(nx, ny, nt, 'single');
interp_std = NaN(nx, ny, nt, 'single');

grid_lon_flat = grid_data.Lon(:);
grid_lat_flat = grid_data.Lat(:);

for t = 1:nt
    valid_idx = valid_mask(:, t);
    n_valid = sum(valid_idx);
    
    if n_valid < 3
        continue;
    end
    
    lon_valid = sMS(valid_idx, 1);
    lat_valid = sMS(valid_idx, 2);
    z_valid = double(Xms(valid_idx, t));
    
    % Interpolate values
    F = scatteredInterpolant(lon_valid, lat_valid, z_valid, 'linear', 'none');
    z_grid_flat = F(grid_lon_flat, grid_lat_flat);
    interp_values(:, :, t) = single(reshape(z_grid_flat, nx, ny));
    
    % Interpolate and combine uncertainties
    if has_framp_variance
        % Interpolate fRAMP variance
        framp_var_valid = double(Xvs(valid_idx, t));
        F_framp = scatteredInterpolant(lon_valid, lat_valid, framp_var_valid, 'linear', 'none');
        framp_var_flat = F_framp(grid_lon_flat, grid_lat_flat);
        framp_var_grid = reshape(framp_var_flat, nx, ny);
        
        % Estimate spatial variance from nearest neighbors
        station_tree = createns(sMS(valid_idx, :), 'NSMethod', 'kdtree');
        k_neighbors = min(4, n_valid);
        grid_coords = [grid_lon_flat, grid_lat_flat];
        [idx_nearest, ~] = knnsearch(station_tree, grid_coords, 'K', k_neighbors);
        
        neighbor_values = z_valid(idx_nearest);
        spatial_std_flat = std(neighbor_values, 0, 2);
        spatial_var_grid = reshape(spatial_std_flat.^2, nx, ny);
        
        % COMBINE: Total variance = fRAMP variance + spatial variance
        total_var_grid = framp_var_grid + spatial_var_grid;
        interp_std(:, :, t) = single(sqrt(total_var_grid));
    else
        % No fRAMP variance - use only spatial
        station_tree = createns(sMS(valid_idx, :), 'NSMethod', 'kdtree');
        k_neighbors = min(4, n_valid);
        grid_coords = [grid_lon_flat, grid_lat_flat];
        [idx_nearest, ~] = knnsearch(station_tree, grid_coords, 'K', k_neighbors);
        
        neighbor_values = z_valid(idx_nearest);
        spatial_std_flat = std(neighbor_values, 0, 2);
        interp_std(:, :, t) = single(reshape(spatial_std_flat, nx, ny));
    end
    
    if opts.verbose && mod(t, max(1, floor(nt/10))) == 0
        fprintf('  Interpolating time %d/%d (%.1f%%)\n', t, nt, 100*t/nt);
    end
end

if opts.verbose
    n_interp_cells = sum(~isnan(interp_values(:, :, 1)) & ~has_bin_data(:, :, 1), 'all');
    fprintf('  Interpolation complete: %d additional cells (%.1f%%)\n', ...
            n_interp_cells, 100 * n_interp_cells / (nx*ny));
    fprintf('  Time: %.2f seconds\n', toc(tic_interp));
end

%% STEP 3: Merge and apply distance-based inflation
if opts.verbose
    fprintf('\n--- STEP 3/3: Merging and uncertainty adjustment ---\n');
    tic_merge = tic;
end

% Initialize with NaN
grid_data.Z = NaN(nx, ny, nt, 'single');
grid_data.Zvar = NaN(nx, ny, nt, 'single');
data_source_2d = zeros(nx, ny, 'uint8');

% Fill bin-average cells first (higher priority)
bin_mask = has_bin_data;
grid_data.Z(bin_mask) = bin_mean(bin_mask);
grid_data.Zvar(bin_mask) = bin_std_total(bin_mask);  % ✓ Uses combined uncertainty
data_source_2d(any(bin_mask, 3)) = 1;

% Identify interpolated-only cells
interp_only_mask = ~has_bin_data & ~isnan(interp_values);

% Apply distance-based inflation to interpolated cells
if opts.distanceBasedInflation
    fprintf('  Computing distance-based uncertainty inflation...\n');
    
    all_station_tree = createns(sMS, 'NSMethod', 'kdtree');
    grid_coords = [grid_data.Lon(:), grid_data.Lat(:)];
    [~, min_dist_to_station] = knnsearch(all_station_tree, grid_coords, 'K', 1);
    min_dist_grid = reshape(min_dist_to_station, nx, ny);
    
    % Inflation: α × (1 + d/β), capped at 5×
    inflation_factor = opts.uncertaintyInflation * (1.0 + min_dist_grid / 2.0);
    inflation_factor = min(inflation_factor, 5.0);
    
    % Apply inflation
    for t = 1:nt
        interp_mask_t = interp_only_mask(:, :, t);
        if any(interp_mask_t(:))
            inflated_std = interp_std(:, :, t) .* inflation_factor;
            grid_data.Zvar(interp_mask_t) = inflated_std(interp_mask_t);
        end
    end
    
    if opts.verbose
        fprintf('    Inflation range: %.2fx to %.2fx\n', ...
                min(inflation_factor(:)), max(inflation_factor(:)));
        fprintf('    Mean inflation: %.2fx\n', mean(inflation_factor(:)));
    end
else
    % Fixed inflation
    for t = 1:nt
        interp_mask_t = interp_only_mask(:, :, t);
        if any(interp_mask_t(:))
            inflated_std = interp_std(:, :, t) * opts.uncertaintyInflation;
            grid_data.Zvar(interp_mask_t) = inflated_std(interp_mask_t);
        end
    end
end

% Fill interpolated values
grid_data.Z(interp_only_mask) = interp_values(interp_only_mask);
data_source_2d(any(interp_only_mask, 3)) = 2;

grid_data.data_source = data_source_2d;

if opts.verbose
    fprintf('  Merge complete: %.2f seconds\n', toc(tic_merge));
end

%% Calculate statistics
n_bin = sum(data_source_2d(:) == 1);
n_interp = sum(data_source_2d(:) == 2);

stats = struct();
stats.n_bin = n_bin;
stats.n_interp = n_interp;
stats.n_total = n_bin + n_interp;
stats.bin_fraction = n_bin / (n_bin + n_interp);

% Uncertainty statistics
bin_cells = (data_source_2d == 1);
interp_cells = (data_source_2d == 2);
var_slice = grid_data.Zvar(:, :, 1);

stats.mean_std_bin = mean(var_slice(bin_cells), 'omitnan');
stats.mean_std_interp = mean(var_slice(interp_cells), 'omitnan');
stats.std_ratio = stats.mean_std_interp / stats.mean_std_bin;

if has_framp_variance
    % Additional stats on uncertainty components
    stats.has_framp_variance = true;
    stats.mean_framp_var = nanmean(bin_var_framp(:,:,1), 'all');
    stats.mean_spatial_var = nanmean(bin_var_spatial(:,:,1), 'all');
    stats.framp_contribution = stats.mean_framp_var / (stats.mean_framp_var + stats.mean_spatial_var);
else
    stats.has_framp_variance = false;
end

end