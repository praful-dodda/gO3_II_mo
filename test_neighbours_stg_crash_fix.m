%% Test Script: Verify neighbours_stg.m Crash Fixes
%
% This script tests the fixes for the neighbours_stg.m crash that occurred
% with restrictive dmax values.
%
% Author: Claude
% Date: November 27, 2025

fprintf('\n========================================\n');
fprintf('  TESTING neighbours_stg.m CRASH FIXES\n');
fprintf('========================================\n');

%% Setup: Create Mock Data Structure

% Create a simple STG (space-time grid) data structure
nMS = 10;  % Number of monitoring stations
nME = 12;  % Number of monitoring events (e.g., months)

% Random station locations
data.sMS = rand(nMS, 2) * 100;  % [lon, lat] in 0-100 range

% Monthly time events (e.g., 2018.0 to 2018.917)
data.tME = linspace(2018.0, 2018.917, nME);

% Create mock data with some NaNs (sparse data)
Z = 40 + 10*randn(nMS, nME);
Z(1:3:end) = NaN;  % Add missing data

% Build required STG structure fields
data.Zisnotnan = ~isnan(Z);
data.nanratio = sum(~data.Zisnotnan(:)) / numel(Z);
data.index_stg_to_stv = cumsum(data.Zisnotnan(:));

% Convert to STV format
[p_stg, z_stg] = valstg2stv(Z, data.sMS, data.tME);
data.p = p_stg(~isnan(z_stg), :);
data.z = z_stg(~isnan(z_stg));

fprintf('Mock data created:\n');
fprintf('  Monitoring stations: %d\n', nMS);
fprintf('  Time events: %d\n', nME);
fprintf('  Valid data points: %d / %d (%.1f%% complete)\n', ...
    length(data.z), nMS*nME, 100*(1-data.nanratio));

%% Test Case 1: Normal Case (Should Work Before and After Fix)

fprintf('\n--- Test Case 1: Normal dmax (should always work) ---\n');

p0 = [50, 50, 2018.5];  % Estimation point in middle of domain
nmax = 20;
dmax = [100, 1, 1];  % Generous spatial/temporal limits

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax);
    fprintf('✓ SUCCESS: Found %d neighbors\n', nsub);
    fprintf('  Spatial distances: [%.2f, %.2f]\n', min(dsub(:,1)), max(dsub(:,1)));
    fprintf('  Temporal distances: [%.2f, %.2f]\n', min(dsub(:,2)), max(dsub(:,2)));
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 2: Very Restrictive Spatial dmax (Crash Scenario 1)

fprintf('\n--- Test Case 2: Very restrictive spatial dmax ---\n');
fprintf('  (Previously caused crash: Index exceeds array bounds)\n');

p0 = [0, 0, 2018.5];  % Estimation point far from data
nmax = 20;
dmax = [5, 1, 1];  % Very small spatial limit (likely no stations within 5 units)

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax);
    if nsub == 0
        fprintf('✓ SUCCESS: Returned empty (no neighbors within dmax)\n');
    else
        fprintf('✓ SUCCESS: Found %d neighbors despite restrictive dmax\n', nsub);
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 3: Very Large Space-Time Metric (Crash Scenario 2)

fprintf('\n--- Test Case 3: Very large space-time metric ---\n');
fprintf('  (Previously caused crash: Array indices must be positive integers)\n');

% Place estimation point near a station
p0 = [data.sMS(1,1), data.sMS(1,2), 2018.5];
nmax = 20;
dmax = [100, 1, 1000];  % Very large space-time metric!
% This means: spatial_dist + 1000*temporal_dist
% Even 0.01 time units = 10 spatial units equivalent
% If nearest station is 5 units away, temporal neighbors must be < 0.005 time units

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax);
    fprintf('✓ SUCCESS: Found %d neighbors\n', nsub);
    if nsub > 0
        fprintf('  Strategy: Relaxed to include at least 1 temporal neighbor\n');
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 4: Very Restrictive Temporal dmax (Crash Scenario 3)

fprintf('\n--- Test Case 4: Very restrictive temporal dmax ---\n');
fprintf('  (Previously caused crash with empty temporal neighbors)\n');

p0 = [50, 50, 2020.5];  % Estimation time far from data (data is in 2018)
nmax = 20;
dmax = [100, 0.1, 1];  % Very small temporal limit (0.1 years = ~1.2 months)

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax);
    if nsub == 0
        fprintf('✓ SUCCESS: Returned empty (no neighbors within temporal dmax)\n');
    else
        fprintf('✓ SUCCESS: Found %d neighbors\n', nsub);
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 5: Extreme Case - Point with No Nearby Data

fprintf('\n--- Test Case 5: Estimation point far from all data ---\n');

p0 = [-1000, -1000, 2025.0];  % Very far from all data
nmax = 20;
dmax = [10, 0.1, 1];  % Restrictive limits

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data, nmax, dmax);
    if nsub == 0
        fprintf('✓ SUCCESS: Correctly returned empty\n');
    else
        fprintf('! WARNING: Found %d neighbors (unexpected for this case)\n', nsub);
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 6: Edge Case - Single Station, Single Time

fprintf('\n--- Test Case 6: Minimal data (1 station, 1 time) ---\n');

data_minimal.sMS = [50, 50];
data_minimal.tME = 2018.0;
Z_minimal = 42;
data_minimal.Zisnotnan = true;
data_minimal.nanratio = 0;
data_minimal.index_stg_to_stv = 1;
[p_stg, z_stg] = valstg2stv(Z_minimal, data_minimal.sMS, data_minimal.tME);
data_minimal.p = p_stg;
data_minimal.z = z_stg;

p0 = [50, 50, 2018.0];  % Exactly at the data point
nmax = 10;
dmax = [100, 1, 1];

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data_minimal, nmax, dmax);
    fprintf('✓ SUCCESS: Found %d neighbor(s)\n', nsub);
    if nsub == 1 && zsub == 42
        fprintf('  Correctly returned the single data point (z = %.0f)\n', zsub);
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Test Case 7: Realistic TOAR Scenario

fprintf('\n--- Test Case 7: Realistic TOAR ozone scenario ---\n');

% Simulate TOAR-like data: sparse stations over large area
data_toar.sMS = rand(50, 2) * 360 - 180;  % Lon/lat from -180 to 180
data_toar.tME = 2015.0 + (0:71)/12;  % 6 years of monthly data (72 months)

Z_toar = 40 + 10*randn(50, 72);
Z_toar(rand(size(Z_toar)) < 0.3) = NaN;  % 30% missing data

data_toar.Zisnotnan = ~isnan(Z_toar);
data_toar.nanratio = sum(~data_toar.Zisnotnan(:)) / numel(Z_toar);
data_toar.index_stg_to_stv = cumsum(data_toar.Zisnotnan(:));
[p_stg, z_stg] = valstg2stv(Z_toar, data_toar.sMS, data_toar.tME);
data_toar.p = p_stg(~isnan(z_stg), :);
data_toar.z = z_stg(~isnan(z_stg));

% Estimation point in Europe
p0 = [10, 50, 2017.5];  % 10°E, 50°N, mid-2017
nmax = 100;
dmax = [50, 2, 1];  % 50 degrees spatial, 2 years temporal, metric=1

try
    [psub, zsub, dsub, nsub, index] = neighbours_stg(p0, data_toar, nmax, dmax);
    fprintf('✓ SUCCESS: Found %d neighbors\n', nsub);
    fprintf('  Data completeness: %.1f%%\n', 100*(1-data_toar.nanratio));
    if nsub > 0
        fprintf('  Spatial range: %.1f° - %.1f°\n', min(dsub(:,1)), max(dsub(:,1)));
        fprintf('  Temporal range: %.2f - %.2f years\n', min(dsub(:,2)), max(dsub(:,2)));
    end
catch ME
    fprintf('✗ FAILED: %s\n', ME.message);
end

%% Summary

fprintf('\n========================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('========================================\n');
fprintf('All test cases completed.\n');
fprintf('If all show "SUCCESS", the crash fixes are working correctly.\n');
fprintf('\nKey improvements:\n');
fprintf('  1. Handles empty spatial neighbors gracefully\n');
fprintf('  2. Handles restrictive space-time constraints\n');
fprintf('  3. Handles empty temporal neighbors gracefully\n');
fprintf('  4. Returns empty instead of crashing\n');
fprintf('  5. Relaxes constraint to include at least 1 neighbor when possible\n');
fprintf('========================================\n\n');