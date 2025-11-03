% example_reformat_usage.m
% Examples of using reformat_stg_to_stug for uniformly gridded data

%% Example 1: Basic reformatting
fprintf('=== Example 1: Basic Reformatting ===\n');

% Your data structure:
% KS.softdata with:
%   sMS: [78048×2] grid coordinates (already uniform!)
%   tME: [1×19] time values
%   Xms: [78048×19] data values

% Reformat to STUG structure
% grid_data = reformat_stg_to_stug(KS.softdata);

% Output will show:
%   Detected grid dimensions (e.g., 272×287)
%   Validates uniform spacing
%   Reshapes to [nx×ny×nt] format

%% Example 2: Complete workflow
fprintf('\n=== Example 2: Complete Workflow ===\n');

% Step 1: Reformat your uniform grid data
% grid_data = reformat_stg_to_stug(KS.softdata);

% Step 2: Use with neighbor search
% p0 = [-95.0, 30.0, 2017.5];  % Point of interest
% nmax = 50;
% dmax = [500.0, 365, 0.01];   % [spatial_km, temporal, weight]

% Step 3: Call STUG function
% [psub, zsub, dsub, nsub] = neighbours_stug_index(p0, grid_data, nmax, dmax);

%% Example 3: With custom tolerance
fprintf('\n=== Example 3: Custom Tolerance ===\n');

% If your grid has slight numerical variations but is essentially uniform:
% grid_data = reformat_stg_to_stug(KS.softdata, 'tolerance', 1e-4);

% Default tolerance: 1e-6 (0.0001%)
% Higher tolerance: 1e-4 (0.01%) - allows more variation
% Lower tolerance: 1e-8 (stricter uniformity check)

%% Example 4: Suppress progress messages
fprintf('\n=== Example 4: Quiet Mode ===\n');

% grid_data = reformat_stg_to_stug(KS.softdata, 'verbose', false);

%% Example 5: Check what grid dimensions you have
fprintf('\n=== Example 5: Determine Grid Dimensions ===\n');

% If you're unsure about your grid size:
% unique_lon = unique(KS.softdata.sMS(:, 1));
% unique_lat = unique(KS.softdata.sMS(:, 2));
%
% fprintf('Grid dimensions: %d (lon) × %d (lat) × %d (time)\n', ...
%         length(unique_lon), length(unique_lat), length(KS.softdata.tME));
% fprintf('Total points: %d\n', length(unique_lon) * length(unique_lat));
% fprintf('Your sMS has: %d points\n', size(KS.softdata.sMS, 1));
%
% if length(unique_lon) * length(unique_lat) == size(KS.softdata.sMS, 1)
%     fprintf('✓ Grid is complete and uniform!\n');
% else
%     fprintf('✗ Grid appears incomplete or irregular\n');
% end

%% Example 6: Validate grid uniformity before reformatting
fprintf('\n=== Example 6: Pre-validation ===\n');

% Check if your data is uniformly gridded:
% function is_uniform = check_grid_uniformity(sMS, tolerance)
%     unique_lon = unique(sMS(:, 1));
%     unique_lat = unique(sMS(:, 2));
%
%     % Check longitude spacing
%     if length(unique_lon) > 1
%         dx = diff(unique_lon);
%         lon_uniform = std(dx) / abs(mean(dx)) < tolerance;
%     else
%         lon_uniform = true;
%     end
%
%     % Check latitude spacing
%     if length(unique_lat) > 1
%         dy = diff(unique_lat);
%         lat_uniform = std(dy) / abs(mean(dy)) < tolerance;
%     else
%         lat_uniform = true;
%     end
%
%     is_uniform = lon_uniform && lat_uniform;
%
%     if is_uniform
%         fprintf('Grid is uniform (lon: %.6f°, lat: %.6f°)\n', ...
%                 mean(dx), mean(dy));
%     else
%         fprintf('Grid is NOT uniform\n');
%         if ~lon_uniform
%             fprintf('  Longitude spacing varies by %.2f%%\n', ...
%                     100 * std(dx) / abs(mean(dx)));
%         end
%         if ~lat_uniform
%             fprintf('  Latitude spacing varies by %.2f%%\n', ...
%                     100 * std(dy) / abs(mean(dy)));
%         end
%     end
% end
%
% is_uniform = check_grid_uniformity(KS.softdata.sMS, 1e-6);
% if is_uniform
%     grid_data = reformat_stg_to_stug(KS.softdata);
% else
%     error('Grid is not uniform. Cannot use reformat_stg_to_stug.');
% end

%% Example 7: Visualize the reformatted grid
fprintf('\n=== Example 7: Visualization ===\n');

% After reformatting:
% grid_data = reformat_stg_to_stug(KS.softdata);
%
% figure;
% subplot(1, 2, 1);
% % Original format (scattered)
% scatter(KS.softdata.sMS(:, 1), KS.softdata.sMS(:, 2), 10, ...
%         KS.softdata.Xms(:, 10), 'filled');
% colorbar;
% title('Original STG format (time index 10)');
% xlabel('Longitude'); ylabel('Latitude');
%
% subplot(1, 2, 2);
% % Reformatted grid
% imagesc(grid_data.x, grid_data.y, grid_data.Z(:, :, 10)');
% axis xy; colorbar;
% title('Reformatted STUG format (time index 10)');
% xlabel('Longitude'); ylabel('Latitude');

%% Example 8: Access reformatted data
fprintf('\n=== Example 8: Accessing Reformatted Data ===\n');

% After reformatting:
% grid_data = reformat_stg_to_stug(KS.softdata);
%
% % Access grid vectors
% lon_grid = grid_data.x;        % [nx×1] longitude values
% lat_grid = grid_data.y;        % [ny×1] latitude values
% time_grid = grid_data.time;    % [nt×1] time values
%
% % Access coordinate meshes
% lon_mesh = grid_data.Lon;      % [nx×ny] longitude mesh
% lat_mesh = grid_data.Lat;      % [nx×ny] latitude mesh
%
% % Access data
% data_3d = grid_data.Z;         % [nx×ny×nt] data array
%
% % Access specific point
% i = 100; j = 150; t = 10;
% value = grid_data.Z(i, j, t);
% location = [grid_data.x(i), grid_data.y(j), grid_data.time(t)];
%
% fprintf('Value at grid point (%d,%d,%d): %.4f\n', i, j, t, value);
% fprintf('Location: [%.4f°, %.4f°, %.2f]\n', location(1), location(2), location(3));

%% Example 9: Error handling
fprintf('\n=== Example 9: Error Handling ===\n');

% The function will error if:

% 1. Grid is not uniform
% bad_data.sMS = rand(1000, 2) * 100;  % Random points
% bad_data.tME = 1:10;
% bad_data.Xms = rand(1000, 10);
% try
%     grid_data = reformat_stg_to_stug(bad_data);
% catch ME
%     fprintf('Error caught: %s\n', ME.message);
% end

% 2. Dimensions don't match
% bad_data.sMS = [1:100; 1:100]';      % 100 points
% bad_data.tME = 1:10;
% bad_data.Xms = rand(200, 10);        % 200 points (mismatch!)
% try
%     grid_data = reformat_stg_to_stug(bad_data);
% catch ME
%     fprintf('Error caught: %s\n', ME.message);
% end

% 3. Grid is incomplete
% [X, Y] = meshgrid(1:10, 1:10);
% partial_data.sMS = [X(1:50), Y(1:50)];  % Only first 50 of 100 points
% partial_data.tME = 1:5;
% partial_data.Xms = rand(50, 5);
% try
%     grid_data = reformat_stg_to_stug(partial_data);
% catch ME
%     fprintf('Error caught: %s\n', ME.message);
% end

%% Comparison: reformat_stg_to_stug vs stg_to_stug

fprintf('\n=== Comparison of Two Functions ===\n');
fprintf('\nreformat_stg_to_stug:\n');
fprintf('  - For data ALREADY on uniform grid\n');
fprintf('  - Just reshapes, no interpolation\n');
fprintf('  - Fast (< 1 second)\n');
fprintf('  - No data loss or error\n');
fprintf('  - Use when: Grid is uniform, just in wrong format\n');

fprintf('\nstg_to_stug:\n');
fprintf('  - For IRREGULAR station data\n');
fprintf('  - Interpolates onto uniform grid\n');
fprintf('  - Slower (2-10 seconds)\n');
fprintf('  - Introduces interpolation error\n');
fprintf('  - Use when: Stations are irregular, need gridding\n');

%% Example 10: Batch process multiple datasets
fprintf('\n=== Example 10: Batch Processing ===\n');

% If you have multiple uniform grid datasets:
% datasets = {KS.softdata, other_uniform_data1, other_uniform_data2};
% grid_datasets = cell(size(datasets));
%
% for i = 1:length(datasets)
%     fprintf('Processing dataset %d/%d...\n', i, length(datasets));
%     grid_datasets{i} = reformat_stg_to_stug(datasets{i}, 'verbose', false);
% end
%
% fprintf('All datasets reformatted!\n');

%% Example 11: Validate against original data
fprintf('\n=== Example 11: Validation ===\n');

% After reformatting, verify data integrity:
% grid_data = reformat_stg_to_stug(KS.softdata);
%
% % Check metadata
% fprintf('Metadata:\n');
% disp(grid_data.metadata);
%
% % Verify no data loss
% if grid_data.metadata.n_valid_original == grid_data.metadata.n_valid_reshaped
%     fprintf('✓ All data preserved (no loss)\n');
% else
%     fprintf('⚠ Data count mismatch!\n');
%     fprintf('  Original: %d valid points\n', grid_data.metadata.n_valid_original);
%     fprintf('  Reshaped: %d valid points\n', grid_data.metadata.n_valid_reshaped);
% end
%
% % Spot check a few points
% for i = 1:min(10, size(KS.softdata.sMS, 1))
%     % Original location and value
%     orig_lon = KS.softdata.sMS(i, 1);
%     orig_lat = KS.softdata.sMS(i, 2);
%     orig_val = KS.softdata.Xms(i, 5);  % Time index 5
%
%     % Find in reformatted grid
%     [~, ix] = min(abs(grid_data.x - orig_lon));
%     [~, iy] = min(abs(grid_data.y - orig_lat));
%     reform_val = grid_data.Z(ix, iy, 5);
%
%     % Compare
%     if abs(orig_val - reform_val) < 1e-6
%         fprintf('Point %d: ✓ Match\n', i);
%     else
%         fprintf('Point %d: ✗ Mismatch (%.4f vs %.4f)\n', i, orig_val, reform_val);
%     end
% end
