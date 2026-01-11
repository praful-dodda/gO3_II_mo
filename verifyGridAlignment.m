function verifyGridAlignment(softDataCell, fusedData, varargin)
% VERIFYGRIDALIGNMENT Visual verification of grid alignment in fusion
%
% Creates diagnostic plots to verify that:
%   1. Union grid correctly captures all unique locations
%   2. Model data is properly mapped to union grid
%   3. Overlap regions are correctly identified
%
% SYNTAX:
%   verifyGridAlignment(softDataCell, fusedData)
%   verifyGridAlignment(softDataCell, fusedData, 'Name', Value, ...)
%
% INPUT:
%   softDataCell  - Cell array of original soft data structs
%   fusedData     - Output from fuseSoftData()
%
% OPTIONAL NAME-VALUE PAIRS:
%   'SpatialTolerance'  - Tolerance used in fusion (default: 0.001)
%   'TimeIndex'         - Which time step to visualize (default: 1)
%   'MaxPoints'         - Max points to plot for large grids (default: 5000)
%   'SaveFigures'       - Save figures to files (default: false)
%   'OutputDir'         - Directory for saved figures (default: '.')
%
% Author: Praful Dodda
% Date: November 2025

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'softDataCell', @iscell);
    addRequired(p, 'fusedData', @isstruct);
    addParameter(p, 'SpatialTolerance', 0.001, @isnumeric);
    addParameter(p, 'TimeIndex', 1, @isnumeric);
    addParameter(p, 'MaxPoints', 5000, @isnumeric);
    addParameter(p, 'SaveFigures', false, @islogical);
    addParameter(p, 'OutputDir', '.', @ischar);
    parse(p, softDataCell, fusedData, varargin{:});
    
    opts = p.Results;
    K = numel(softDataCell);
    t = opts.TimeIndex;
    
    % Colors for each model
    colors = lines(K + 1);
    
    fprintf('\n========================================\n');
    fprintf('GRID ALIGNMENT VERIFICATION\n');
    fprintf('========================================\n');
    
    %% Figure 1: Original Grids Overlay
    figure('Name', 'Grid Alignment - Original Grids', 'Position', [100, 100, 1200, 500]);
    
    subplot(1, 2, 1);
    hold on;
    legendEntries = cell(K, 1);
    
    for k = 1:K
        sd = softDataCell{k};
        nk = size(sd.sMS, 1);
        
        % Subsample if too many points
        if nk > opts.MaxPoints
            idx = randperm(nk, opts.MaxPoints);
        else
            idx = 1:nk;
        end
        
        scatter(sd.sMS(idx, 2), sd.sMS(idx, 1), 10, colors(k, :), 'filled', ...
            'MarkerFaceAlpha', 0.5);
        legendEntries{k} = sprintf('%s (n=%d)', sd.modelName, nk);
    end
    
    xlabel('Longitude');
    ylabel('Latitude');
    title('Original Model Grids');
    legend(legendEntries, 'Location', 'best');
    grid on;
    axis equal;
    hold off;
    
    % Subplot 2: Fused grid colored by coverage
    subplot(1, 2, 2);
    
    nFused = size(fusedData.sMS, 1);
    if nFused > opts.MaxPoints
        idx = randperm(nFused, opts.MaxPoints);
    else
        idx = 1:nFused;
    end
    
    if isfield(fusedData, 'nModelsAvailable')
        scatter(fusedData.sMS(idx, 2), fusedData.sMS(idx, 1), 10, ...
            fusedData.nModelsAvailable(idx), 'filled');
        colorbar;
        colormap(gca, parula(K));
        caxis([0.5, K + 0.5]);
        title(sprintf('Fused Grid - Color = # Models Available (n=%d)', nFused));
    else
        scatter(fusedData.sMS(idx, 2), fusedData.sMS(idx, 1), 10, 'k', 'filled', ...
            'MarkerFaceAlpha', 0.5);
        title(sprintf('Fused Grid (n=%d)', nFused));
    end
    
    xlabel('Longitude');
    ylabel('Latitude');
    grid on;
    axis equal;
    
    if opts.SaveFigures
        saveas(gcf, fullfile(opts.OutputDir, 'grid_alignment_overview.png'));
    end
    
    %% Figure 2: Zoom into overlap region (if exists)
    if isfield(fusedData, 'nModelsAvailable') && any(fusedData.nModelsAvailable > 1)
        
        % Find overlap region
        overlapIdx = fusedData.nModelsAvailable > 1;
        overlapCoords = fusedData.sMS(overlapIdx, :);
        
        if ~isempty(overlapCoords)
            % Get bounding box of overlap with some padding
            latRange = [min(overlapCoords(:,1)), max(overlapCoords(:,1))];
            lonRange = [min(overlapCoords(:,2)), max(overlapCoords(:,2))];
            latPad = 0.1 * diff(latRange);
            lonPad = 0.1 * diff(lonRange);
            
            figure('Name', 'Grid Alignment - Overlap Region', 'Position', [150, 150, 1200, 500]);
            
            subplot(1, 2, 1);
            hold on;
            
            for k = 1:K
                sd = softDataCell{k};
                
                % Filter to overlap region
                inRegion = sd.sMS(:,1) >= latRange(1) - latPad & ...
                           sd.sMS(:,1) <= latRange(2) + latPad & ...
                           sd.sMS(:,2) >= lonRange(1) - lonPad & ...
                           sd.sMS(:,2) <= lonRange(2) + lonPad;
                
                scatter(sd.sMS(inRegion, 2), sd.sMS(inRegion, 1), 30, colors(k, :), 'filled', ...
                    'MarkerFaceAlpha', 0.6);
            end
            
            xlim([lonRange(1) - lonPad, lonRange(2) + lonPad]);
            ylim([latRange(1) - latPad, latRange(2) + latPad]);
            xlabel('Longitude');
            ylabel('Latitude');
            title('Overlap Region - Original Grids');
            legend(cellfun(@(x) x.modelName, softDataCell, 'UniformOutput', false), 'Location', 'best');
            grid on;
            hold off;
            
            subplot(1, 2, 2);
            
            % Show fused points in overlap region colored by nModelsAvailable
            inRegion = fusedData.sMS(:,1) >= latRange(1) - latPad & ...
                       fusedData.sMS(:,1) <= latRange(2) + latPad & ...
                       fusedData.sMS(:,2) >= lonRange(1) - lonPad & ...
                       fusedData.sMS(:,2) <= lonRange(2) + lonPad;
            
            scatter(fusedData.sMS(inRegion, 2), fusedData.sMS(inRegion, 1), 30, ...
                fusedData.nModelsAvailable(inRegion), 'filled');
            colorbar;
            colormap(gca, parula(K));
            caxis([0.5, K + 0.5]);
            
            xlim([lonRange(1) - lonPad, lonRange(2) + lonPad]);
            ylim([latRange(1) - latPad, latRange(2) + latPad]);
            xlabel('Longitude');
            ylabel('Latitude');
            title('Overlap Region - Fused (color = # models)');
            grid on;
            
            if opts.SaveFigures
                saveas(gcf, fullfile(opts.OutputDir, 'grid_alignment_overlap.png'));
            end
            
            fprintf('\nOverlap region found:\n');
            fprintf('  Lat: [%.4f, %.4f]\n', latRange(1), latRange(2));
            fprintf('  Lon: [%.4f, %.4f]\n', lonRange(1), lonRange(2));
            fprintf('  Points with multiple models: %d\n', sum(overlapIdx));
        end
    else
        fprintf('\nNo overlap region detected (grids are disjoint).\n');
    end
    
    %% Figure 3: Value comparison at overlap points
    if isfield(fusedData, 'nModelsAvailable') && any(fusedData.nModelsAvailable == K)
        
        figure('Name', 'Grid Alignment - Value Comparison', 'Position', [200, 200, 1200, 800]);
        
        % For BMA: compare fused values to individual models
        if isfield(fusedData, 'weights')
            
            % Find points where all models contribute
            allModelsIdx = find(fusedData.nModelsAvailable == K);
            nCompare = min(length(allModelsIdx), 1000);  % Limit for plotting
            compareIdx = allModelsIdx(randperm(length(allModelsIdx), nCompare));
            
            subplot(2, 2, 1);
            hold on;
            for k = 1:K
                fieldName = matlab.lang.makeValidName(softDataCell{k}.modelName);
                if isfield(fusedData.weights, fieldName)
                    w = fusedData.weights.(fieldName);
                    histogram(w(compareIdx, t), 20, 'FaceAlpha', 0.5, 'DisplayName', softDataCell{k}.modelName);
                end
            end
            xlabel('Weight');
            ylabel('Count');
            title(sprintf('BMA Weights Distribution (t=%d)', t));
            legend('Location', 'best');
            hold off;
            
            subplot(2, 2, 2);
            % Scatter: Model 1 vs Model 2 values at overlap points
            % Need to reconstruct original values at fused locations
            % This requires re-mapping which is complex, so show fused vs simple average
            
            % Calculate simple average for comparison
            simpleAvg = zeros(nCompare, 1);
            for k = 1:K
                fieldName = matlab.lang.makeValidName(softDataCell{k}.modelName);
                w = fusedData.weights.(fieldName);
                % Approximate: use weights to back-calculate
            end
            
            % Instead, show fused Z distribution
            histogram(fusedData.Z(compareIdx, t), 30);
            xlabel('Fused Z (ppb)');
            ylabel('Count');
            title(sprintf('Fused Values Distribution (t=%d)', t));
            
            subplot(2, 2, 3);
            histogram(fusedData.Zv(compareIdx, t), 30);
            xlabel('Fused Variance');
            ylabel('Count');
            title(sprintf('Fused Variance Distribution (t=%d)', t));
            
            subplot(2, 2, 4);
            % Variance inflation: fused vs typical input
            inputVarMean = 0;
            for k = 1:K
                inputVarMean = inputVarMean + nanmean(softDataCell{k}.Zv(:, t));
            end
            inputVarMean = inputVarMean / K;
            
            varInflation = fusedData.Zv(compareIdx, t) / inputVarMean;
            histogram(varInflation, 30);
            xlabel('Variance Inflation Ratio');
            ylabel('Count');
            title('Fused/Input Variance Ratio');
            xline(1, 'r--', 'LineWidth', 2);
            
        elseif isfield(fusedData, 'modelSelected')
            % For Selection: show which model won where
            
            subplot(2, 2, 1);
            histogram(fusedData.modelSelected(:, t), 1:K+1);
            xticks(1:K);
            xticklabels(cellfun(@(x) x.modelName, softDataCell, 'UniformOutput', false));
            ylabel('Count');
            title(sprintf('Model Selection Counts (t=%d)', t));
            
            subplot(2, 2, 2);
            % Spatial map of selection
            scatter(fusedData.sMS(:, 2), fusedData.sMS(:, 1), 5, ...
                fusedData.modelSelected(:, t), 'filled');
            colorbar;
            colormap(gca, lines(K));
            caxis([0.5, K + 0.5]);
            xlabel('Longitude');
            ylabel('Latitude');
            title('Model Selected (spatial)');
            
            subplot(2, 2, [3, 4]);
            histogram(fusedData.Zv(:, t), 30);
            xlabel('Selected Variance');
            ylabel('Count');
            title('Variance Distribution (from selected models)');
        end
        
        if opts.SaveFigures
            saveas(gcf, fullfile(opts.OutputDir, 'grid_alignment_values.png'));
        end
    end
    
    %% Figure 4: Sorting verification
    figure('Name', 'Grid Alignment - Sorting Check', 'Position', [250, 250, 800, 600]);
    
    subplot(2, 2, 1);
    plot(fusedData.lat, 'b.');
    xlabel('Index');
    ylabel('Latitude');
    title('Latitude vs Index (should be non-decreasing)');
    
    subplot(2, 2, 2);
    plot(diff(fusedData.lat), 'r.');
    xlabel('Index');
    ylabel('\Delta Latitude');
    title('Latitude Differences (should be >= 0)');
    yline(0, 'k--');
    
    subplot(2, 2, 3);
    % Check if sorted properly
    latSorted = all(diff(fusedData.lat) >= -1e-10);  % Small tolerance for floating point
    
    % For proper (lat, lon) sorting, within same lat, lon should increase
    uniqueLats = unique(round(fusedData.lat, 6));
    lonSortedWithinLat = true;
    for i = 1:min(length(uniqueLats), 100)  % Check first 100 unique lats
        mask = abs(fusedData.lat - uniqueLats(i)) < 1e-6;
        if sum(mask) > 1
            lonsAtLat = fusedData.lon(mask);
            if ~issorted(lonsAtLat)
                lonSortedWithinLat = false;
                break;
            end
        end
    end
    
    text(0.5, 0.7, sprintf('Latitude sorted: %s', mat2str(latSorted)), ...
        'Units', 'normalized', 'FontSize', 14, 'HorizontalAlignment', 'center');
    text(0.5, 0.5, sprintf('Lon sorted within lat: %s', mat2str(lonSortedWithinLat)), ...
        'Units', 'normalized', 'FontSize', 14, 'HorizontalAlignment', 'center');
    text(0.5, 0.3, sprintf('Total points: %d', fusedData.nGrid), ...
        'Units', 'normalized', 'FontSize', 14, 'HorizontalAlignment', 'center');
    axis off;
    title('Sorting Summary');
    
    subplot(2, 2, 4);
    % Show first and last few coordinates
    nShow = min(10, fusedData.nGrid);
    coordTable = [fusedData.lat(1:nShow), fusedData.lon(1:nShow)];
    
    text(0.1, 0.95, 'First 10 coordinates:', 'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold');
    for i = 1:nShow
        text(0.1, 0.95 - i*0.08, sprintf('%d: (%.4f, %.4f)', i, coordTable(i,1), coordTable(i,2)), ...
            'Units', 'normalized', 'FontSize', 9, 'FontName', 'FixedWidth');
    end
    axis off;
    title('Coordinate Sample');
    
    if opts.SaveFigures
        saveas(gcf, fullfile(opts.OutputDir, 'grid_alignment_sorting.png'));
    end
    
    %% Print summary statistics
    fprintf('\n--- Alignment Summary ---\n');
    fprintf('Input models: %d\n', K);
    for k = 1:K
        fprintf('  %s: %d points\n', softDataCell{k}.modelName, size(softDataCell{k}.sMS, 1));
    end
    fprintf('Fused grid: %d points\n', fusedData.nGrid);
    
    totalInput = sum(cellfun(@(x) size(x.sMS, 1), softDataCell));
    fprintf('Total input points: %d\n', totalInput);
    fprintf('Reduction: %d points (%.1f%%)\n', totalInput - fusedData.nGrid, ...
        100*(totalInput - fusedData.nGrid)/totalInput);
    
    if isfield(fusedData, 'nModelsAvailable')
        fprintf('\nCoverage:\n');
        for n = 1:K
            cnt = sum(fusedData.nModelsAvailable == n);
            fprintf('  %d model(s): %d points (%.1f%%)\n', n, cnt, 100*cnt/fusedData.nGrid);
        end
    end
    
    fprintf('\nSorting: Lat=%s, Lon(within lat)=%s\n', mat2str(latSorted), mat2str(lonSortedWithinLat));
    fprintf('\n========================================\n\n');
end
