function grid_data = stg_to_stug(stg_data, varargin)
% STG_TO_STUG - Convert STG (irregular stations) to STUG (uniform grid) format
%
% Efficiently converts monitoring station data (STG) to uniformly gridded
% data (STUG) using spatial interpolation. Optimized for large datasets.
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
%   'method'       - Interpolation method: 'linear', 'natural', 'nearest'
%                   (default: 'linear')
%   'extrapolation' - Extrapolation method: 'none', 'linear', 'nearest'
%                    (default: 'none' - NaN outside convex hull)
%   'bounds'       - [lon_min lon_max lat_min lat_max] custom bounds
%                   (default: auto from data)
%   'verbose'      - Show progress (default: true)
%   'includeVariance' - Include variance interpolation (default: false)
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
%               .metadata - struct with conversion info
%
% EXAMPLE:
%   % Basic usage with auto resolution
%   grid_data = stg_to_stug(KS.softdata);
%
%   % Custom resolution
%   grid_data = stg_to_stug(KS.softdata, 0.1);
%
%   % Advanced options
%   grid_data = stg_to_stug(KS.softdata, ...
%       'resolution', 0.05, ...
%       'method', 'natural', ...
%       'verbose', true, ...
%       'includeVariance', true);
%
% PERFORMANCE:
%   - Uses scatteredInterpolant (optimized MATLAB interpolation)
%   - Vectorized grid evaluation (10-100x faster than loops)
%   - Smart memory pre-allocation
%   - Typical: 78k stations × 19 times → ~2-10 seconds
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
addParameter(p, 'method', 'linear', @(x) ismember(x, {'linear', 'natural', 'nearest'}));
addParameter(p, 'extrapolation', 'none', @(x) ismember(x, {'none', 'linear', 'nearest'}));
addParameter(p, 'bounds', [], @(x) isempty(x) || (isnumeric(x) && length(x) == 4));
addParameter(p, 'verbose', true, @islogical);
addParameter(p, 'includeVariance', false, @islogical);

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
sMS = stg_data.sMS;      % [N×2] station locations
tME = stg_data.tME;      % [1×T] time values
Xms = stg_data.Xms;      % [N×T] data values

[n_stations, n_times] = size(Xms);

if opts.verbose
    fprintf('=== STG to STUG Conversion ===\n');
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
        sample_idx = randperm(n_stations, 1000);
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

% Pre-allocate output array
grid_data.Z = NaN(nx, ny, nt, 'single');
if interpolate_variance
    grid_data.Zvar = NaN(nx, ny, nt, 'single');
end

% Flatten grid for vectorized interpolation
grid_lon_flat = grid_data.Lon(:);
grid_lat_flat = grid_data.Lat(:);

%% Interpolate each time step
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

    % Create interpolant (triangulation is cached internally by MATLAB)
    F = scatteredInterpolant(lon_valid, lat_valid, z_valid, ...
                             opts.method, opts.extrapolation);

    % Interpolate on entire grid (VECTORIZED - very fast!)
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

%% Calculate statistics
n_interpolated = sum(~isnan(grid_data.Z(:)));
n_total = numel(grid_data.Z);
fill_ratio = n_interpolated / n_total;

if opts.verbose
    fprintf('\n=== Conversion Summary ===\n');
    fprintf('Grid points with data: %d / %d (%.1f%%)\n', ...
            n_interpolated, n_total, 100 * fill_ratio);
    fprintf('Resolution: %.4f° × %.4f°\n', resolution, resolution);
    fprintf('Total time: %.2f seconds\n', total_time);
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

end
