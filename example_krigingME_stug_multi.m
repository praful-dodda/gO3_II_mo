%% Example: Using krigingME_stug_multi with Multiple Soft Datasets
%
% This script demonstrates how to use the new multi-dataset version of
% krigingME_stug that supports multiple soft data sources.
%
% Author: Claude
% Date: November 27, 2025

%% BACKWARD COMPATIBILITY - Single Soft Dataset

% The function is fully backward compatible with krigingME_stug.m
% If you have existing code, it will work without modification:

% Example 1: No soft data (hard data only)
% [zk, vk] = krigingME_stug_multi(ck, ch, cs, zh, zs, vs, covmodel, covparam, ...
%                                  nhmax, nsmax, dmax, order, options);

% Example 2: Single soft dataset using legacy vectors
% [zk, vk] = krigingME_stug_multi(ck, ch, cs, zh, zs, vs, covmodel, covparam, ...
%                                  nhmax, nsmax, dmax, order, options);

% Example 3: Single soft dataset using soft_data structure
% [zk, vk] = krigingME_stug_multi(ck, ch, [], zh, [], [], covmodel, covparam, ...
%                                  nhmax, nsmax, dmax, order, options, [], soft_data);

%% NEW FEATURE - Multiple Soft Datasets

% To use multiple soft datasets, provide them as a cell array:
%
% soft_data = {soft_data1, soft_data2, soft_data3};
%
% Each element should be a structure compatible with neighbours_stug_optimized:
%   .x        - x-coordinates (nx by 1)
%   .y        - y-coordinates (ny by 1)
%   .time     - time coordinates (nt by 1)
%   .Lon      - longitude at each grid point (nx by ny or nx by ny by nt)
%   .Lat      - latitude at each grid point (nx by ny or nx by ny by nt)
%   .Z        - data values (nx by ny by nt)
%   .Zv       - variance values (nx by ny by nt)

%% Example: Create Mock Data for Demonstration

% Estimation grid
nk = 100;
ck = rand(nk, 3) * 100;  % [lon, lat, time]

% Hard data (observations)
nh = 50;
ch = rand(nh, 3) * 100;
zh = 40 + 10 * randn(nh, 1);  % Ozone values

% Soft dataset 1: CTM Model 1 (e.g., MERRA2-GMI)
soft_data1 = createMockSoftData('MERRA2-GMI', [10 10 12], [0 100], [0 100], [0 12]);

% Soft dataset 2: CTM Model 2 (e.g., CAMS)
soft_data2 = createMockSoftData('CAMS', [10 10 12], [0 100], [0 100], [0 12]);

% Soft dataset 3: CTM Model 3 (e.g., AM4)
soft_data3 = createMockSoftData('AM4', [10 10 12], [0 100], [0 100], [0 12]);

% Package as cell array
soft_data_multi = {soft_data1, soft_data2, soft_data3};

%% Set up kriging parameters

% Covariance model
covmodel = 'exponentialC';  % Or your fitted model
covparam = [1000, 50, 0.1, 10];  % Spatial range, temporal range, sills

% Neighborhood parameters
nhmax = 100;  % Max hard data neighbors
nsmax = 200;  % Max soft data neighbors (TOTAL across all datasets)
dmax = [50, 2, 1];  % [max_spatial_dist, max_temporal_dist, space-time metric]

% Mean trend order
order = 0;  % Constant mean (for residuals)

% Options
options = [1];  % Display progress

%% USAGE 1: Multiple soft datasets via cell array

fprintf('\n=== EXAMPLE 1: Multiple Soft Datasets ===\n');

% Call with multiple soft datasets
[zk_multi, vk_multi] = krigingME_stug_multi(ck, ch, [], zh, [], [], ...
    covmodel, covparam, nhmax, nsmax, dmax, order, options, [], soft_data_multi);

fprintf('Completed estimation with %d soft datasets\n', length(soft_data_multi));
fprintf('Estimated %d points\n', sum(~isnan(zk_multi)));

%% USAGE 2: Single soft dataset (backward compatible)

fprintf('\n=== EXAMPLE 2: Single Soft Dataset (Backward Compatible) ===\n');

% Call with single soft dataset
[zk_single, vk_single] = krigingME_stug_multi(ck, ch, [], zh, [], [], ...
    covmodel, covparam, nhmax, nsmax, dmax, order, options, [], soft_data1);

fprintf('Completed estimation with single soft dataset\n');
fprintf('Estimated %d points\n', sum(~isnan(zk_single)));

%% USAGE 3: Hard data only (no soft data)

fprintf('\n=== EXAMPLE 3: Hard Data Only ===\n');

% Call with no soft data
[zk_hard, vk_hard] = krigingME_stug_multi(ck, ch, [], zh, [], [], ...
    covmodel, covparam, nhmax, 0, dmax, order, options);

fprintf('Completed estimation with hard data only\n');
fprintf('Estimated %d points\n', sum(~isnan(zk_hard)));

%% Compare Results

fprintf('\n=== COMPARISON ===\n');
fprintf('Mean estimate (multi-dataset): %.2f\n', nanmean(zk_multi));
fprintf('Mean estimate (single dataset): %.2f\n', nanmean(zk_single));
fprintf('Mean estimate (hard only): %.2f\n', nanmean(zk_hard));
fprintf('\nMean variance (multi-dataset): %.2f\n', nanmean(vk_multi));
fprintf('Mean variance (single dataset): %.2f\n', nanmean(vk_single));
fprintf('Mean variance (hard only): %.2f\n', nanmean(vk_hard));

%% Helper function to create mock soft data
function soft = createMockSoftData(name, dims, xrange, yrange, trange)
    % Create mock soft data structure for demonstration

    nx = dims(1);
    ny = dims(2);
    nt = dims(3);

    soft.x = linspace(xrange(1), xrange(2), nx)';
    soft.y = linspace(yrange(1), yrange(2), ny)';
    soft.time = linspace(trange(1), trange(2), nt)';

    [X, Y] = meshgrid(soft.x, soft.y);
    soft.Lon = X';
    soft.Lat = Y';

    % Create mock data with some spatial/temporal pattern
    soft.Z = zeros(nx, ny, nt);
    soft.Zv = zeros(nx, ny, nt);

    for it = 1:nt
        % Mock ozone pattern
        soft.Z(:,:,it) = 40 + 10*sin(2*pi*X/100) + 5*cos(2*pi*Y/100) + randn(size(X));
        % Mock variance (measurement uncertainty)
        soft.Zv(:,:,it) = 5 + 2*rand(size(X));
    end

    soft.name = name;

    fprintf('Created mock soft dataset: %s (%dx%dx%d grid)\n', name, nx, ny, nt);
end
