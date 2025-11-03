function grid_data = reformat_stg_to_stug(stg_data, varargin)
% REFORMAT_STG_TO_STUG - Reformat uniformly gridded data from STG to STUG structure
%
% Validates that input data is on a uniform grid and reformats it to STUG
% structure expected by neighbours_stug_optimized.m and neighbours_stug_index.m
%
% IMPORTANT: This function does NOT interpolate. It only reshapes data that
% is already on a uniform grid. If data is irregular, it will return an error.
%
% SYNTAX:
%   grid_data = reformat_stg_to_stug(stg_data)
%   grid_data = reformat_stg_to_stug(stg_data, 'Name', Value, ...)
%
% INPUT:
%   stg_data - struct with fields:
%              .sMS  [N×2 double]  - Grid point locations [lon, lat]
%                                   Must be on a UNIFORM grid!
%              .tME  [1×T double]  - Time values
%              .Xms  [N×T single]  - Data values (grid points × time)
%              .Xvs  [N×T single]  - Variances (optional)
%
% OPTIONAL PARAMETERS:
%   'tolerance'  - Tolerance for grid uniformity check (default: 1e-6)
%   'verbose'    - Show progress messages (default: true)
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
% EXAMPLE:
%   % Basic usage
%   grid_data = reformat_stg_to_stug(KS.softdata);
%
%   % Then use with STUG neighbor functions
%   [psub, zsub, dsub, nsub] = neighbours_stug_index(p0, grid_data, nmax, dmax);
%
% ERROR CONDITIONS:
%   - Throws error if grid spacing is not uniform
%   - Throws error if coordinates cannot form rectangular grid
%   - Throws error if data dimensions don't match
%
% SEE ALSO: neighbours_stug_optimized, neighbours_stug_index

%% Parse inputs
p = inputParser;
addRequired(p, 'stg_data', @isstruct);
addParameter(p, 'tolerance', 1e-6, @(x) isscalar(x) && x > 0);
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

[n_points, n_times] = size(Xms);

if opts.verbose
    fprintf('=== Reformatting STG to STUG Structure ===\n');
    fprintf('Input: %d grid points × %d time steps\n', n_points, n_times);
end

% Validate dimensions match
if size(sMS, 1) ~= n_points
    error('sMS has %d points but Xms has %d points. Dimensions must match.', ...
          size(sMS, 1), n_points);
end

%% Extract unique coordinates
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

% Validate that grid is complete
if nx * ny ~= n_points
    error(['Grid validation failed!\n' ...
           'Unique lon points: %d, Unique lat points: %d\n' ...
           'Expected grid size: %d × %d = %d points\n' ...
           'Actual points: %d\n' ...
           'Grid appears to be incomplete or irregular.'], ...
           nx, ny, nx, ny, nx * ny, n_points);
end

%% Check grid uniformity

% Check longitude spacing
if nx > 1
    dx_vec = diff(unique_lon);
    dx_mean = mean(dx_vec);
    dx_std = std(dx_vec);

    if dx_std / abs(dx_mean) > opts.tolerance
        error(['Grid is NOT uniformly spaced in longitude!\n' ...
               'Mean spacing: %.6f degrees\n' ...
               'Std deviation: %.6f degrees\n' ...
               'Relative variation: %.2f%% (tolerance: %.2f%%)\n' ...
               'This function requires uniform grid spacing.\n' ...
               'Use stg_to_stug.m for interpolation if you have irregular stations.'], ...
               dx_mean, dx_std, 100 * dx_std / abs(dx_mean), 100 * opts.tolerance);
    end

    dx = dx_mean;

    if opts.verbose
        fprintf('Longitude spacing: %.6f° (uniform ✓)\n', dx);
    end
else
    dx = NaN;
end

% Check latitude spacing
if ny > 1
    dy_vec = diff(unique_lat);
    dy_mean = mean(dy_vec);
    dy_std = std(dy_vec);

    if dy_std / abs(dy_mean) > opts.tolerance
        error(['Grid is NOT uniformly spaced in latitude!\n' ...
               'Mean spacing: %.6f degrees\n' ...
               'Std deviation: %.6f degrees\n' ...
               'Relative variation: %.2f%% (tolerance: %.2f%%)\n' ...
               'This function requires uniform grid spacing.\n' ...
               'Use stg_to_stug.m for interpolation if you have irregular stations.'], ...
               dy_mean, dy_std, 100 * dy_std / abs(dy_mean), 100 * opts.tolerance);
    end

    dy = dy_mean;

    if opts.verbose
        fprintf('Latitude spacing: %.6f° (uniform ✓)\n', dy);
    end
else
    dy = NaN;
end

%% Create grid structure

% Grid vectors (ensure column vectors)
grid_data.x = unique_lon(:);
grid_data.y = unique_lat(:);
grid_data.time = tME(:);

% Create coordinate meshes
[X, Y] = meshgrid(grid_data.x, grid_data.y);
grid_data.Lon = X';  % Transpose to [nx, ny]
grid_data.Lat = Y';

%% Reshape data from [N×T] to [nx×ny×nt]

if opts.verbose
    fprintf('Reshaping data from [%d×%d] to [%d×%d×%d]...\n', ...
            n_points, n_times, nx, ny, n_times);
end

% Pre-allocate
grid_data.Z = NaN(nx, ny, n_times, 'single');

% Build lookup for coordinate to index mapping
% For each point in sMS, find its (i,j) indices
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
if isfield(stg_data, 'Xvs')
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

%% Validate the reshaping

% Check that we didn't lose any data
n_original_valid = sum(~isnan(Xms(:)));
n_reshaped_valid = sum(~isnan(grid_data.Z(:)));

if n_original_valid ~= n_reshaped_valid
    warning(['Data count mismatch after reshaping!\n' ...
             'Original valid points: %d\n' ...
             'Reshaped valid points: %d\n' ...
             'Some data may have been lost or duplicated.'], ...
             n_original_valid, n_reshaped_valid);
end

%% Store metadata

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

%% Summary

if opts.verbose
    fprintf('\n=== Reformatting Complete ===\n');
    fprintf('Output grid: %d × %d × %d\n', nx, ny, n_times);
    fprintf('Grid spacing: %.6f° × %.6f°\n', dx, dy);
    fprintf('Valid data points: %d / %d (%.1f%%)\n', ...
            n_reshaped_valid, nx * ny * n_times, ...
            100 * n_reshaped_valid / (nx * ny * n_times));
    fprintf('Structure is ready for neighbours_stug_* functions\n');
end

end
