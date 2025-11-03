function [psub, zsub, dsub, nsub, index] = neighbours_stug_optimized(p0, grid_data, nmax, dmax)
% neighbours_stug_optimized - Optimized space/time neighbourhood selection for uniform grids
%
% Select a subset of space/time coordinates and values with the shortest
% space/time distance from coordinate p0. Optimized for uniformly gridded data.
%
% SYNTAX:
%
% [psub, zsub, dsub, nsub, index] = neighbours_stug_optimized(p0, grid_data, nmax, dmax);
%
% INPUT:
%
% p0         1 by 3 (or 6)  vector of coordinates [lon, lat, time] or
%                           [lon, lat, time, idx_x, idx_y, idx_t]
%                           If indices provided, they will be used; otherwise computed
% grid_data  struct or char Structure with grid data or path to NetCDF file
%            If struct, must contain:
%              .x        nx by 1   x-coordinates (can be lon or grid units)
%              .y        ny by 1   y-coordinates (can be lat or grid units)
%              .time     nt by 1   time coordinates
%              .Lon      nx by ny  longitude at each grid point (or nx×ny×nt)
%              .Lat      nx by ny  latitude at each grid point (or nx×ny×nt)
%              .Z        nx by ny by nt   data values (NaN for missing)
%            If char, treated as NetCDF file path
% nmax       scalar      maximum number of neighbors to return
% dmax       1 by 3      [max_spatial_dist, max_temporal_dist, spacetime_metric]
%                        space/time distance = spatial_dist + dmax(3)*temporal_dist
%
% OUTPUT:
%
% psub       m by 6      [lon, lat, time, idx_x, idx_y, idx_t] for m neighbors
% zsub       m by 1      data values at selected neighbors
% dsub       m by 2      [spatial_distance, temporal_distance] from p0
% nsub       scalar      number of neighbors returned (m)
% index      m by 1      linear indices into Z array

%% Input handling
if ischar(grid_data) || isstring(grid_data)
    % NetCDF file path provided
    data.x = ncread(grid_data, 'x');
    data.y = ncread(grid_data, 'y');
    data.time = ncread(grid_data, 'time');
    data.Lon = ncread(grid_data, 'Lon');
    data.Lat = ncread(grid_data, 'Lat');
    data.Z = ncread(grid_data, 'BENZ');
else
    data = grid_data;
end

% Extract target coordinates
lon0 = p0(1);
lat0 = p0(2);
t0 = p0(3);

% Get grid dimensions
nx = length(data.x);
ny = length(data.y);
nt = length(data.time);

% Compute or extract grid indices for p0
if length(p0) >= 6
    idx_x = p0(4);
    idx_y = p0(5);
    idx_t = p0(6);
else
    % Find nearest grid point to p0
    [~, idx_x] = min(abs(data.x - lon0));
    [~, idx_y] = min(abs(data.y - lat0));
    [~, idx_t] = min(abs(data.time - t0));
end

% Compute grid spacing
dx = median(diff(data.x));
dy = median(diff(data.y));
dt = median(diff(data.time));

% Handle edge case: empty data
if isempty(data.Z) || all(isnan(data.Z(:)))
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return
end

%% Convert dmax to grid units
rx_max = ceil(dmax(1) / abs(dx));
ry_max = ceil(dmax(1) / abs(dy));
rt_max = ceil(dmax(2) / abs(dt));

% Estimate candidate search volume
candidate_volume = (2*rx_max + 1) * (2*ry_max + 1) * (2*rt_max + 1);

% Estimate data sparsity (NaN ratio)
sample_size = min(1000, numel(data.Z));
sample_indices = randperm(numel(data.Z), sample_size);
estimated_nanratio = sum(isnan(data.Z(sample_indices))) / sample_size;

% Choose search strategy based on volume AND sparsity
% Shell expansion is inefficient for extremely sparse data (>90% NaN)
% because it wastes time searching empty shells
% Direct index search is better for sparse data or small volumes
use_shell_expansion = (candidate_volume > 1000) && ...
                      (nmax < 0.1 * candidate_volume) && ...
                      (estimated_nanratio < 0.9);  % NOT very sparse

%% Main search algorithm
if use_shell_expansion
    % Strategy A: Shell-based expansion (memory efficient for large grids)
    [candidates_ix, candidates_iy, candidates_it] = shell_based_search(...
        idx_x, idx_y, idx_t, nx, ny, nt, rx_max, ry_max, rt_max, ...
        data.Z, nmax, dx, dy, dt, dmax);
else
    % Strategy B: Direct index-based search (simpler for small grids)
    [candidates_ix, candidates_iy, candidates_it] = index_based_search(...
        idx_x, idx_y, idx_t, nx, ny, nt, rx_max, ry_max, rt_max, ...
        data.Z, dx, dy, dt, dmax);
end

% Handle case where no candidates found
if isempty(candidates_ix)
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return
end

%% Compute actual distances for candidates
n_candidates = length(candidates_ix);

% Extract coordinates for candidates
if ndims(data.Lon) == 3
    lon_candidates = zeros(n_candidates, 1);
    lat_candidates = zeros(n_candidates, 1);
    for i = 1:n_candidates
        lon_candidates(i) = data.Lon(candidates_ix(i), candidates_iy(i), candidates_it(i));
        lat_candidates(i) = data.Lat(candidates_ix(i), candidates_iy(i), candidates_it(i));
    end
else
    % 2D Lon/Lat arrays
    lon_candidates = zeros(n_candidates, 1);
    lat_candidates = zeros(n_candidates, 1);
    for i = 1:n_candidates
        lon_candidates(i) = data.Lon(candidates_ix(i), candidates_iy(i));
        lat_candidates(i) = data.Lat(candidates_ix(i), candidates_iy(i));
    end
end

time_candidates = data.time(candidates_it);

% Compute spatial and temporal distances
spatial_dist = sqrt((lon_candidates - lon0).^2 + (lat_candidates - lat0).^2);
temporal_dist = abs(time_candidates - t0);

% Apply dmax constraints
valid_mask = (spatial_dist <= dmax(1)) & (temporal_dist <= dmax(2));
valid_idx = find(valid_mask);

if isempty(valid_idx)
    psub = [];
    zsub = [];
    dsub = [];
    nsub = 0;
    index = [];
    return
end

% Filter to valid points
candidates_ix = candidates_ix(valid_idx);
candidates_iy = candidates_iy(valid_idx);
candidates_it = candidates_it(valid_idx);
lon_candidates = lon_candidates(valid_idx);
lat_candidates = lat_candidates(valid_idx);
time_candidates = time_candidates(valid_idx);
spatial_dist = spatial_dist(valid_idx);
temporal_dist = temporal_dist(valid_idx);

% Compute combined space-time distance
spacetime_dist = spatial_dist + dmax(3) * temporal_dist;

% Sort by space-time distance with deterministic tie-breaking
% For testing: use grid indices as secondary sort keys for consistent ordering
% This ensures reproducible results when multiple neighbors are equidistant
sort_matrix = [spacetime_dist, candidates_ix, candidates_iy, candidates_it];
[~, sort_idx] = sortrows(sort_matrix);
n_return = min(nmax, length(sort_idx));
select_idx = sort_idx(1:n_return);

%% Prepare outputs
% psub = [lon_candidates(select_idx), lat_candidates(select_idx), time_candidates(select_idx), ...
%         candidates_ix(select_idx), candidates_iy(select_idx), candidates_it(select_idx)];

psub = [lon_candidates(select_idx), lat_candidates(select_idx), time_candidates(select_idx)];

% Extract data values
zsub = zeros(n_return, 1);
index = zeros(n_return, 1);
for i = 1:n_return
    ix = candidates_ix(select_idx(i));
    iy = candidates_iy(select_idx(i));
    it = candidates_it(select_idx(i));
    zsub(i) = data.Z(ix, iy, it);
    index(i) = sub2ind([nx, ny, nt], ix, iy, it);
end

dsub = [spatial_dist(select_idx), temporal_dist(select_idx)];
nsub = n_return;

end

%% Helper function: Shell-based expansion search
function [ix_out, iy_out, it_out] = shell_based_search(...
    idx_x, idx_y, idx_t, nx, ny, nt, rx_max, ry_max, rt_max, ...
    Z, nmax, dx, dy, dt, dmax)
% Expands outward in shells of increasing grid-space distance

candidates_ix = [];
candidates_iy = [];
candidates_it = [];

% Maximum shell radius in grid units
max_radius = max([rx_max, ry_max, rt_max]);

for shell_r = 0:max_radius
    % Generate all grid points at current shell radius
    % Use Chebyshev distance (max of absolute differences)

    for di = -shell_r:shell_r
        for dj = -shell_r:shell_r
            for dk = -shell_r:shell_r
                % Only process points on shell boundary
                if max(abs([di, dj, dk])) ~= shell_r
                    continue
                end

                ix = idx_x + di;
                iy = idx_y + dj;
                it = idx_t + dk;

                % Check bounds
                if ix < 1 || ix > nx || iy < 1 || iy > ny || it < 1 || it > nt
                    continue
                end

                % Check if within max radii
                if abs(di) > rx_max || abs(dj) > ry_max || abs(dk) > rt_max
                    continue
                end

                % Check grid-space distance bounds (quick filter)
                spatial_grid_dist = sqrt((di*dx)^2 + (dj*dy)^2);
                temporal_grid_dist = abs(dk*dt);

                if spatial_grid_dist > dmax(1) || temporal_grid_dist > dmax(2)
                    continue
                end

                % Check if data exists (not NaN)
                if ~isnan(Z(ix, iy, it))
                    candidates_ix = [candidates_ix; ix];
                    candidates_iy = [candidates_iy; iy];
                    candidates_it = [candidates_it; it];
                end
            end
        end
    end

    % Early termination if we have enough candidates
    if length(candidates_ix) >= nmax * 2  % Get extra to allow for sorting
        break
    end
end

ix_out = candidates_ix;
iy_out = candidates_iy;
it_out = candidates_it;

end

%% Helper function: Direct index-based search
function [ix_out, iy_out, it_out] = index_based_search(...
    idx_x, idx_y, idx_t, nx, ny, nt, rx_max, ry_max, rt_max, ...
    Z, dx, dy, dt, dmax)
% Direct search through index ranges with coupled spatiotemporal filtering

candidates_ix = [];
candidates_iy = [];
candidates_it = [];

% Define bounded search ranges
it_min = max(1, idx_t - rt_max);
it_max = min(nt, idx_t + rt_max);

for it = it_min:it_max
    % Compute temporal distance and remaining spatial budget
    dt_grid = abs(it - idx_t);
    temporal_dist = dt_grid * abs(dt);

    % Skip if temporal distance alone exceeds limit
    if temporal_dist > dmax(2)
        continue
    end

    % Compute effective spatial search radius for this time slice
    % Account for space-time metric: spatial_budget reduces as temporal distance increases
    spatial_budget = dmax(1);  % Could be tightened based on dmax(3) if needed

    rx_effective = min(rx_max, ceil(spatial_budget / abs(dx)));
    ry_effective = min(ry_max, ceil(spatial_budget / abs(dy)));

    ix_min = max(1, idx_x - rx_effective);
    ix_max = min(nx, idx_x + rx_effective);
    iy_min = max(1, idx_y - ry_effective);
    iy_max = min(ny, idx_y + ry_effective);

    for ix = ix_min:ix_max
        for iy = iy_min:iy_max
            % Quick grid-space distance check
            spatial_grid_dist = sqrt(((ix-idx_x)*dx)^2 + ((iy-idx_y)*dy)^2);

            if spatial_grid_dist <= dmax(1)
                % Check if data exists (not NaN)
                if ~isnan(Z(ix, iy, it))
                    candidates_ix = [candidates_ix; ix];
                    candidates_iy = [candidates_iy; iy];
                    candidates_it = [candidates_it; it];
                end
            end
        end
    end
end

ix_out = candidates_ix;
iy_out = candidates_iy;
it_out = candidates_it;

end
