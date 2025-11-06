%% example_diagnose_vertical_lines.m
% Example script to diagnose vertical lines in standard deviation maps
%
% This script shows how to use visualizeBMEdiagnostic.m to investigate
% artifacts in BME results

%% Step 1: Find Your BME Result File
% List available BME result files
fprintf('=== Available BME Result Files ===\n');
BMEdir = '5BMEspatialPlots';
if exist(BMEdir, 'dir')
    files = dir(fullfile(BMEdir, 'BME*.mat'));
    if ~isempty(files)
        for i = 1:min(10, length(files))  % Show first 10
            fprintf('%d. %s\n', i, files(i).name);
        end
        if length(files) > 10
            fprintf('   ... and %d more files\n', length(files) - 10);
        end
    else
        fprintf('No BME result files found in %s\n', BMEdir);
        return;
    end
else
    fprintf('Directory %s not found. Run BME estimation first.\n', BMEdir);
    return;
end

%% Step 2: Select a File to Diagnose
% CHANGE THIS to your specific file
BMEfile = fullfile(BMEdir, files(1).name);  % Using first file as example
fprintf('\n=== Diagnosing File ===\n%s\n\n', BMEfile);

%% Step 3: Visualize Standard Deviation - Grid Only
% This is best for seeing vertical line artifacts
fprintf('>>> Creating diagnostic plot 1: STD - Grid Only <<<\n');
opts1 = struct();
opts1.metric = 'std';
opts1.display = 'grid';
opts1.colormap = 'jet';
opts1.markerSize = 20;

figure(1);
visualizeBMEdiagnostic(BMEfile, opts1);

%% Step 4: Visualize Standard Deviation - Both Grid and Obs
% Compare grid interpolation with actual observation locations
fprintf('\n>>> Creating diagnostic plot 2: STD - Grid + Observations <<<\n');
opts2 = struct();
opts2.metric = 'std';
opts2.display = 'both';
opts2.colormap = 'jet';
opts2.markerSize = 20;

figure(2);
visualizeBMEdiagnostic(BMEfile, opts2);

%% Step 5: Visualize Mean - Grid Only (for comparison)
% Check if vertical lines appear in mean estimates too
fprintf('\n>>> Creating diagnostic plot 3: Mean - Grid Only <<<\n');
opts3 = struct();
opts3.metric = 'mean';
opts3.display = 'grid';
opts3.colormap = 'jet';
opts3.markerSize = 20;

figure(3);
visualizeBMEdiagnostic(BMEfile, opts3);

%% Step 6: Variance Analysis
% Raw variance before sqrt (most sensitive to artifacts)
fprintf('\n>>> Creating diagnostic plot 4: Variance - Grid Only <<<\n');
opts4 = struct();
opts4.metric = 'variance';
opts4.display = 'grid';
opts4.colormap = 'jet';
opts4.markerSize = 20;

figure(4);
visualizeBMEdiagnostic(BMEfile, opts4);

%% Instructions for Diagnosis
fprintf('\n');
fprintf('===============================================\n');
fprintf('DIAGNOSTIC INTERPRETATION GUIDE\n');
fprintf('===============================================\n\n');

fprintf('WHAT TO LOOK FOR:\n');
fprintf('  1. Vertical Lines in STD maps:\n');
fprintf('     - Check if lines align with grid structure\n');
fprintf('     - Zoom in to see if they are interpolation artifacts\n');
fprintf('     - Compare grid-only vs grid+obs views\n\n');

fprintf('  2. Possible Causes:\n');
fprintf('     - Structured grid interpolation issues\n');
fprintf('     - Missing data patterns creating boundaries\n');
fprintf('     - Coordinate transformation artifacts\n');
fprintf('     - Numerical precision issues in covariance\n\n');

fprintf('  3. Compare Across Metrics:\n');
fprintf('     - Do vertical lines appear in MEAN too?\n');
fprintf('     - Are they stronger in VARIANCE than STD?\n');
fprintf('     - This helps identify if issue is in:\n');
fprintf('       * Estimation (mean affected)\n');
fprintf('       * Uncertainty (only variance/std affected)\n\n');

fprintf('NEXT STEPS:\n');
fprintf('  A. If vertical lines are in grid structure:\n');
fprintf('     - Check dataFormat: try switching stg <-> stug\n');
fprintf('     - Review grid generation in getTOARmapGrid.m\n');
fprintf('     - Check soft data grid uniformity\n\n');

fprintf('  B. If vertical lines align with data boundaries:\n');
fprintf('     - Check search radius (dmax parameter)\n');
fprintf('     - Review neighbor selection in kriging\n');
fprintf('     - Check for data gaps or missing values\n\n');

fprintf('  C. If only in STD but not MEAN:\n');
fprintf('     - Issue likely in covariance calculation\n');
fprintf('     - Check covmodel parameters\n');
fprintf('     - Review variance computation in kriging\n\n');

fprintf('USE DATA CURSOR:\n');
fprintf('  - Click on any point to see exact values\n');
fprintf('  - Inspect points along vertical lines\n');
fprintf('  - Check if values are realistic\n\n');

fprintf('ZOOM CONTROLS:\n');
fprintf('  - Use zoom tool to examine artifacts closely\n');
fprintf('  - Look for patterns in artifact spacing\n');
fprintf('  - Check artifact orientation (truly vertical?)\n\n');

fprintf('===============================================\n\n');

%% Optional: Create Custom Diagnostic Plot
fprintf('OPTIONAL: Create custom diagnostic plot\n');
fprintf('Edit the options below and uncomment to run:\n\n');

% % Custom example: High-res std with parula colormap
% opts_custom = struct();
% opts_custom.metric = 'std';
% opts_custom.display = 'grid';
% opts_custom.colormap = 'parula';
% opts_custom.markerSize = 15;
% opts_custom.clim = [0 10];  % Set specific color limits
%
% figure(5);
% visualizeBMEdiagnostic(BMEfile, opts_custom);
