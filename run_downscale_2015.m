function run_downscale_2015()
% run_downscale_2015 - Demo: downscale the 2015 BME ozone field to 0.25 deg
% with bilinear/bicubic/spline, validate (held-out nodes), and plot.
%
% Uses the 2015 best method 13000313-06 (Obs + M3fusion + OMI-MLS).
% Writes: downscale_2015_maps.png, downscale_2015_validation.png
%         downscale_2015_validation.csv

method   = '13000313-06';
outMaps  = 'downscale_2015_maps.png';
outVal   = 'downscale_2015_validation.png';
outCsv   = 'downscale_2015_validation.csv';
targetRes = 0.25;

%% 1. Assemble the 2015 cube (12 months on the 1-deg land lattice)
cube = assembleBMEcube(method, struct('years', 2015, 'verbose', true));
fprintf('Cube: %d cells x %d months\n', cube.nGrid, cube.nMonths);

% Annual-mean field (nGrid x 1) for the source map + a fresh cube to downscale
annCube = cube;
annCube.ozone = mean(cube.ozone, 2, 'omitnan');
annCube.time = 2015; annCube.year = 2015; annCube.month = 0;

%% 2. Downscale the FULL 12-month cube with all three methods + validate
methods = {'bilinear','bicubic','spline'};
out = downscaleEstimates(cube, struct('method', {methods}, ...
    'targetRes', targetRes, 'validate', true, 'verbose', true));

fprintf('\n=== Held-out-node validation (2015, %d months pooled) ===\n', cube.nMonths);
disp(out.validation);
writetable(out.validation, outCsv);
fprintf('Wrote %s\n', outCsv);

%% 3. Downscale the annual-mean field for clean maps
outAnn = downscaleEstimates(annCube, struct('method', {methods}, ...
    'targetRes', targetRes, 'validate', false, 'verbose', false));

%% ---- Plot 1: source + 3 downscaled annual-mean maps ------------------
cmin = min(annCube.ozone); cmax = max(annCube.ozone);
f1 = figure('Position', [80 80 1500 900], 'Color', 'w', 'Visible', 'off');
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
scatter(annCube.lon, annCube.lat, 6, annCube.ozone, 'filled');
local_mapfmt(sprintf('Source 1° (%d cells)', cube.nGrid), cmin, cmax);

for m = 1:3
    nexttile;
    v = outAnn.byMethod(methods{m}).val;
    scatter(outAnn.lon, outAnn.lat, 3, v, 'filled');
    local_mapfmt(sprintf('%s %.2f° (%d cells)', methods{m}, targetRes, ...
        outAnn.nTarget), cmin, cmax);
end
title(tl, sprintf('2015 annual-mean MDA8 O_3 downscaling  (method %s)', method), ...
    'FontWeight', 'bold');
cb = colorbar; cb.Layout.Tile = 'east'; cb.Label.String = 'O_3 (ppb)';
exportgraphics(f1, outMaps, 'Resolution', 150);
fprintf('Wrote %s\n', outMaps);

%% ---- Plot 2: validation bar charts -----------------------------------
V = out.validation;
f2 = figure('Position', [120 120 1300 400], 'Color', 'w', 'Visible', 'off');
tl2 = tiledlayout(1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
mets = {'RMSE','MAE','R2'}; units = {'ppb','ppb',''};
for k = 1:3
    nexttile;
    bar(categorical(V.Method), V.(mets{k}));
    ylabel(units{k}); title(mets{k}); grid on;
end
nexttile;
bar(categorical(V.Method), [V.OvershootFrac*100, V.NaNFrac*100]);
ylabel('%'); title('Overshoot / NaN'); legend({'overshoot','NaN'}, ...
    'Location', 'best'); grid on;
title(tl2, sprintf('2015 downscaling skill — held-out %d nodes/method (0.25°)', ...
    round(mean(V.nHoldout))), 'FontWeight', 'bold');
exportgraphics(f2, outVal, 'Resolution', 150);
fprintf('Wrote %s\n', outVal);

close(f1); close(f2);
fprintf('\nDone.\n');
end

% ========================================================================
function local_mapfmt(ttl, cmin, cmax)
axis equal tight; box on;
xlim([-180 180]); ylim([-60 85]);
caxis([cmin cmax]);
title(ttl); xlabel('lon'); ylabel('lat');
set(gca, 'Color', [0.94 0.94 0.94]);
end
