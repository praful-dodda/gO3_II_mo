
function [lambda1, lambda2] = getOverhangRAMPv6_updated(obs, model, resultsDir)
% GETOVERHANGRAMPV6 - Computes spatiotemporal correction values using local RAMPs 
% and a global fallback. Enforces monotonicity on lambda1 and includes technique
% tracking and optional diagnostic plotting.
%
% INPUTS:
%   obs        - Struct with observational data (must contain 'tME').
%   model      - Struct with model data (must contain 'sMS' and 'Z').
%   resultsDir - Directory for saving plots (optional).
%
% OUTPUTS:
%   lambda1    - [nPoints x nTime] mean corrections.
%   lambda2    - [nPoints x nTime] variance corrections.

% === Initialization ===
m = size(model.sMS, 1);              % Number of grid points
tME = size(obs.tME, 2);              % Number of time steps
lambda1 = nan(m, tME);
lambda2 = nan(m, tME);
techniqueUsed = zeros(m, tME);       % Method used: 1 = local, 2+ = adjusted, 99 = global fallback

% === Plotting control ===
plottingEnabled = true;
if nargin < 3 || isempty(resultsDir)
    plottingEnabled = false;
    resultsDir = '';
end

% === Constants ===
numPointsPerMonth = 100;            % Desired ramp size per time step
totalbins = 10;
neighborIncrement = 250;
GLOBAL_FALLBACK_CODE = 99;

% === Precompute model-observation pairs ===
modelobsPairs = getModelatObs(model, obs);
totstation = ceil(numPointsPerMonth); % Starting guess for local ramp

% === Main Time Loop ===
for t = 1:tME
    win = getTimeWindow(t, tME);

    % === Global RAMP Setup ===
    [global_decileBounds, global_curve_lambda1, global_curve_lambda2, ...
     global_mod, global_obs, global_binEdges] = computeGlobalRamp(modelobsPairs, win, totalbins, numPointsPerMonth);

    avgSlope_lambda1 = mean(diff(global_curve_lambda1) ./ diff(global_decileBounds), 'omitnan');
    avgSlope_lambda2 = mean(diff(global_curve_lambda2) ./ diff(global_decileBounds), 'omitnan');

    if plottingEnabled
        plotGlobalCamp(global_decileBounds, global_curve_lambda1, global_curve_lambda2, ...
                       global_mod, global_obs, global_binEdges, t, resultsDir);
    end

    plotIndices = randperm(m, min(5, m)); % Subset to plot

    % === Loop Over Grid Points ===
    parfor p = 1:m
        gridloc = model.sMS(p, :);
        currentMod = model.Z(p, t);

        if isnan(currentMod)
            continue;
        end

        % === EARLY EXIT: If outside global bounds, use global RAMP ===
        if currentMod < min(global_decileBounds(~isnan(global_decileBounds))) || ...
           currentMod > max(global_decileBounds(~isnan(global_decileBounds)))
            [lambda1(p,t), lambda2(p,t)] = globalExtrapolation(currentMod, ...
                global_decileBounds, global_curve_lambda1, global_curve_lambda2, ...
                avgSlope_lambda1, avgSlope_lambda2);
            techniqueUsed(p,t) = GLOBAL_FALLBACK_CODE;
            continue;
        end

        % === LOCAL RAMP ===
        [local_obs_initial, local_mod_initial, currNeighborCount] = getLocalObservations(...
            modelobsPairs, gridloc, win, numPointsPerMonth, totstation);

        [local_bounds, local_curve1, local_curve2, local_binEdges] = computeDecileCurves(local_mod_initial, local_obs_initial, totalbins);
        local_curve1 = enforce_monotonicity(local_curve1);

        if currentMod >= min(local_bounds(~isnan(local_bounds))) && currentMod <= max(local_bounds(~isnan(local_bounds)))
            [lambda1(p,t), lambda2(p,t)] = localInterpolation(local_bounds, local_curve1, local_curve2, currentMod);
            techniqueUsed(p,t) = 1;
            plotData = {local_obs_initial, local_mod_initial, local_bounds, local_curve1, local_curve2, local_binEdges};
        else
            [l1, l2, adjustedFlag, ~, adjCount, ...
             adj_bounds, adj_curve1, adj_curve2, adj_binEdges, ...
             adj_obs, adj_mod] = tryAdjustLocalRamp(...
                modelobsPairs, gridloc, win, currentMod, totalbins, currNeighborCount, neighborIncrement, totstation);

            if adjustedFlag
                lambda1(p,t) = l1;
                lambda2(p,t) = l2;
                techniqueUsed(p,t) = 1 + adjCount;
                plotData = {adj_obs, adj_mod, adj_bounds, adj_curve1, adj_curve2, adj_binEdges};
            else
                [lambda1(p,t), lambda2(p,t)] = globalExtrapolation(currentMod, ...
                    global_decileBounds, global_curve_lambda1, global_curve_lambda2, ...
                    avgSlope_lambda1, avgSlope_lambda2);
                techniqueUsed(p,t) = GLOBAL_FALLBACK_CODE;
                plotData = {adj_obs, adj_mod, adj_bounds, adj_curve1, adj_curve2, adj_binEdges};
            end
        end

        if plottingEnabled && any(p == plotIndices)
            plotLocalData(gridloc, plotData{:}, currentMod, lambda1(p,t), lambda2(p,t), p, t, resultsDir, totalbins);
        end
    end

    % === Technique Map Plot ===
    if plottingEnabled
        plotTechniqueMap(model.sMS, techniqueUsed(:, t), t, resultsDir);
    end
end
end

    %% Helper Functions (assuming definitions remain the same as previous version)

    function win = getTimeWindow(t, tME)
        % Returns the time window indices for current time t.
        if t == 1
            win = [1, 2];
        elseif t == tME
            win = [tME-1, tME];
        else
            win = [t-1, t, t+1];
        end
    end

    function [decileBounds, curve1, curve2, modVals, obsVals, binEdges] = computeGlobalRamp(modelobsPairs, win, totalbins)
        % Computes the global CAMP ramp using all observation-model pairs for the time window.
        global_obs_all = reshape(modelobsPairs.obsval(:, win), [], 1);
        global_mod_all = reshape(modelobsPairs.modelval(:, win), [], 1);
        valid_global = ~isnan(global_obs_all) & ~isnan(global_mod_all);
        obsVals = global_obs_all(valid_global);
        modVals = global_mod_all(valid_global);
        [decileBounds, curve1, curve2, binEdges] = computeDecileCurves(modVals, obsVals, totalbins);
        % ENFORCE MONOTONICITY HERE for global curve
        curve1 = enforce_monotonicity(curve1);
        [decileBounds, sortIdx] = sort(decileBounds);
         % Check if sortIdx is empty or all NaN before applying
         if ~isempty(sortIdx) && ~all(isnan(sortIdx))
              valid_curve1 = ~isnan(curve1);
              if any(valid_curve1)
                   curve1(valid_curve1) = curve1(valid_curve1(sortIdx)); % Apply sort only to non-NaN
              end
              valid_curve2 = ~isnan(curve2);
               if any(valid_curve2)
                    curve2(valid_curve2) = curve2(valid_curve2(sortIdx)); % Apply sort only to non-NaN
               end
         end
        % binEdges do not need sorting
    end

    function [decileBounds, curve1, curve2, binEdges] = computeDecileCurves(modVals, obsVals, totalbins)
        % Computes decile bounds, corresponding mean observations/variances, and bin edges.
        % Returns raw curve1 (monotonicity applied separately where needed).
        binEdges = quantest(modVals, 0:1/totalbins:1);
        decileBounds = NaN(totalbins,1);
        curve1 = NaN(totalbins,1);
        curve2 = NaN(totalbins,1);
        for i = 1:totalbins
            if i < totalbins
                idx = modVals >= binEdges(i) & modVals < binEdges(i+1);
            else
                % Handle potential empty last bin edge if modVals is empty
                if isempty(binEdges) || numel(binEdges) < i + 1
                    idx = false(size(modVals));
                else
                   idx = modVals >= binEdges(i) & modVals <= binEdges(i+1);
                end
            end
            if any(idx)
                decileBounds(i) = mean(modVals(idx), 'omitnan');
                curve1(i) = mean(obsVals(idx), 'omitnan');
                curve2(i) = var(obsVals(idx), 'omitnan');
            end
        end
         % Ensure non-NaN before sorting if necessary, although sorting happens after enforce_monotonicity
         valid_bounds = ~isnan(decileBounds);
         if ~any(valid_bounds) % Handle case where all bounds are NaN
             return;
         end
    end

    function [obsVals, modVals, usedCount] = getLocalObservations(modelobsPairs, gridloc, win, initCount, totstation)
        % Retrieves local observation-model pairs based on the nearest neighbors.
        station_count = initCount;
        required_points = totstation * numel(win);
        validPairsFound = false;
        max_stations = size(modelobsPairs.sMS, 1); % Get max stations available
        obsVals_temp = []; % Initialize temporary vars
        modVals_temp = [];
        validIdx = [];

        while ~validPairsFound && station_count <= max_stations % Check against max_stations
            distances = sqrt(sum((modelobsPairs.sMS - gridloc).^2, 2));
            [~, indices] = mink(distances, station_count);
            obsSel = modelobsPairs.obsval(indices, win);
            modSel = modelobsPairs.modelval(indices, win);
            obsVals_temp = obsSel(:); % Use temp variables inside loop
            modVals_temp = modSel(:);
            validIdx = ~isnan(obsVals_temp) & ~isnan(modVals_temp);
            if sum(validIdx) >= required_points
                validPairsFound = true;
                obsVals = obsVals_temp(validIdx); % Assign final values
                modVals = modVals_temp(validIdx);
            else
                 % Only increment if not already at max stations
                if station_count < max_stations
                    station_count = min(station_count + 10, max_stations); % Ensure not exceeding max
                else
                    % If already at max stations and still not enough points, break
                    obsVals = obsVals_temp(validIdx); % Use best available
                    modVals = modVals_temp(validIdx);
                    break;
                end
            end
        end
         % If loop finished (either found or max stations reached) without setting final vars
         if ~validPairsFound % Use data from last iteration if goal not met
             obsVals = obsVals_temp(validIdx);
             modVals = modVals_temp(validIdx);
         end
        usedCount = station_count; % Return the actual count used
    end

%{
    function [l1, l2] = localInterpolation(decileBounds, curve1, curve2, currentMod)
        % Performs linear interpolation based on local decile curves.
        % Assumes curve1 is already monotonic.
        valid_interp = ~isnan(decileBounds) & ~isnan(curve1);
        if sum(valid_interp) >= 2
            l1 = interp1(decileBounds(valid_interp), curve1(valid_interp), currentMod, 'linear', 'extrap');
        else % Handle case with fewer than 2 points
            l1 = mean(curve1,'omitnan');
            if isnan(l1) && any(valid_interp)
                l1 = curve1(valid_interp);
            elseif isempty(valid_interp) || ~any(valid_interp)
                 l1 = NaN; % No valid points
            end
        end
        valid_interp2 = ~isnan(decileBounds) & ~isnan(curve2);
         if sum(valid_interp2) >= 2
             l2 = interp1(decileBounds(valid_interp2), curve2(valid_interp2), currentMod, 'linear', 'extrap');
         else
             l2 = mean(curve2,'omitnan');
              if isnan(l2) && any(valid_interp2)
                 l2 = curve2(valid_interp2);
              elseif isempty(valid_interp2) || ~any(valid_interp2)
                 l2 = NaN; % No valid points
             end
         end
         if ~isnan(l2) && l2 < 0
            l2 = 0;
         end
    end
%}
    function [l1, l2] = localInterpolation(decileBounds, curve1, curve2, currentMod)
        % Performs linear interpolation (or extrapolation) for lambda1 and lambda2.
        % Applies fallback for lambda2: mean of curve2 if extrapolating or invalid.

        % --- λ₁: Mean Correction (interpolate or extrapolate) ---
        valid_interp = ~isnan(decileBounds) & ~isnan(curve1);
        if sum(valid_interp) >= 2
            l1 = interp1(decileBounds(valid_interp), curve1(valid_interp), currentMod, 'linear', 'extrap');
        else
            l1 = mean(curve1, 'omitnan');
        end

        % --- λ₂: Variance Correction ---
        valid_interp2 = ~isnan(decileBounds) & ~isnan(curve2);
        if sum(valid_interp2) >= 2
            l2_interp = interp1(decileBounds(valid_interp2), curve2(valid_interp2), currentMod, 'linear', 'extrap');

            % If extrapolation produces invalid value, fallback to mean
            if isnan(l2_interp) || l2_interp < 0
                l2 = mean(curve2(valid_interp2), 'omitnan');
            else
                l2 = l2_interp;
            end
        else
            % Fallback: use mean of all valid λ₂ bins
            l2 = mean(curve2(valid_interp2), 'omitnan');
        end

        % Final safeguard
        if isnan(l2) || l2 < 0
            l2 = 0.01; % minimum safe variance
        end
    end

    function [l1, l2, flag, newCount, adjCount, decileBounds, curve1, curve2, binEdges, obsVals, modVals] = tryAdjustLocalRamp(modelobsPairs, gridloc, win, currentMod, totalbins, initCount, inc, totstation)
        % Iteratively expands the neighbor search. Monotonicity is enforced inside computeDecileCurvesFromLocal.
        adjCount = 0;
        newCount = initCount;
        max_stations = size(modelobsPairs.sMS, 1);
        [decileBounds, curve1, curve2, binEdges, obsVals, modVals] = computeDecileCurvesFromLocal(modelobsPairs, gridloc, win, newCount, totstation, totalbins); % curve1 is monotonic here

        while ~(currentMod >= min(decileBounds(~isnan(decileBounds))) && currentMod <= max(decileBounds(~isnan(decileBounds)))) ...
                && (newCount < max_stations)
            if newCount < max_stations
                 newCount = min(max_stations, newCount + inc);
            else
                break;
            end
            adjCount = adjCount + 1;
            [decileBounds, curve1, curve2, binEdges, obsVals, modVals] = computeDecileCurvesFromLocal(modelobsPairs, gridloc, win, newCount, totstation, totalbins); % curve1 is monotonic here
        end

        if currentMod >= min(decileBounds(~isnan(decileBounds))) && currentMod <= max(decileBounds(~isnan(decileBounds)))
            [l1, l2] = localInterpolation(decileBounds, curve1, curve2, currentMod); % Use monotonic curve1
            flag = true;
        else
            l1 = NaN; l2 = NaN;
            flag = false;
        end
    end

    function [decileBounds, curve1, curve2, binEdges, obsVals, modVals] = computeDecileCurvesFromLocal(modelobsPairs, gridloc, win, station_count, totstation, totalbins)
        % Computes local decile curves AND returns data pairs based on a specified number of neighbors.
        % Enforces monotonicity on curve1 before returning.
        distances = sqrt(sum((modelobsPairs.sMS - gridloc).^2, 2));
        [~, indices] = mink(distances, station_count);
        obsSel = modelobsPairs.obsval(indices, win);
        modSel = modelobsPairs.modelval(indices, win);
        obsVals_temp = obsSel(:);
        modVals_temp = modSel(:);
        validIdx = ~isnan(obsVals_temp) & ~isnan(modVals_temp);
        obsVals = obsVals_temp(validIdx);
        modVals = modVals_temp(validIdx);
        [decileBounds, curve1, curve2, binEdges] = computeDecileCurves(modVals, obsVals, totalbins);

        % ***** ENFORCE MONOTONICITY HERE for local/adjusted curves *****
        curve1 = enforce_monotonicity(curve1);
        % ***************************************************************

        [decileBounds, sortIdx] = sort(decileBounds);
        % Check if sortIdx is empty or all NaN before applying
         if ~isempty(sortIdx) && ~all(isnan(sortIdx))
              % Ensure curve arrays are column vectors and apply sort only to non-NaN elements
               curve1 = curve1(:); curve2 = curve2(:);
               valid_c1 = ~isnan(curve1);
               valid_c2 = ~isnan(curve2);
               if any(valid_c1)
                    curve1_sorted = nan(size(curve1));
                    curve1_sorted(valid_c1) = curve1(valid_c1(sortIdx));
                    curve1 = curve1_sorted;
               end
               if any(valid_c2)
                    curve2_sorted = nan(size(curve2));
                    curve2_sorted(valid_c2) = curve2(valid_c2(sortIdx));
                    curve2 = curve2_sorted;
                end
         end
    end

    %{
    function [l1, l2] = globalExtrapolation(currentMod, globalBounds, globalCurve1, globalCurve2, avgSlope1, avgSlope2)
        % Extrapolates lambda values based on the global CAMP ramp curve.
         valid_bounds = ~isnan(globalBounds);
         if ~any(valid_bounds)
             l1 = NaN; l2 = NaN; return;
         end
         minB = min(globalBounds(valid_bounds)); % Min non-NaN bound
         maxB = max(globalBounds(valid_bounds)); % Max non-NaN bound

        if currentMod < minB
            firstValidIdx = find(globalBounds == minB, 1, 'first'); % Index of min bound
            pivot_bound = globalBounds(firstValidIdx);
            pivot_value1 = globalCurve1(firstValidIdx);
            pivot_value2 = globalCurve2(firstValidIdx);
        else % currentMod >= maxB
            lastValidIdx = find(globalBounds == maxB, 1, 'last'); % Index of max bound
            pivot_bound = globalBounds(lastValidIdx);
            pivot_value1 = globalCurve1(lastValidIdx);
            pivot_value2 = globalCurve2(lastValidIdx);
        end
        l1 = pivot_value1 + avgSlope1 * (currentMod - pivot_bound);
        l2 = pivot_value2 + avgSlope2 * (currentMod - pivot_bound);
        if ~isnan(l2) && l2 < 0
            l2 = 0;
        end
    end
    %}
    function [l1, l2] = globalExtrapolation(currentMod, globalBounds, globalCurve1, globalCurve2, avgSlope1, avgSlope2)
        % Extrapolates lambda1 and lambda2 based on global CAMP curve.
        % Falls back to safe mean-based variance if extrapolation fails.
    
        valid_bounds = ~isnan(globalBounds);
        if ~any(valid_bounds)
            l1 = NaN; l2 = NaN;
            return;
        end
    
        minB = min(globalBounds(valid_bounds));
        maxB = max(globalBounds(valid_bounds));
    
        % λ₁: extrapolate
        if currentMod < minB
            idx = find(globalBounds == minB, 1, 'first');
        else
            idx = find(globalBounds == maxB, 1, 'last');
        end
        pivot_bound = globalBounds(idx);
        pivot_value1 = globalCurve1(idx);
        pivot_value2 = globalCurve2(idx);
    
        l1 = pivot_value1 + avgSlope1 * (currentMod - pivot_bound);
        l2_raw = pivot_value2 + avgSlope2 * (currentMod - pivot_bound);
    
        % λ₂: fallback if invalid
        valid_var = ~isnan(globalCurve2);
        l2 = l2_raw;
        if isnan(l2) || l2 < 0
            l2 = mean(globalCurve2(valid_var), 'omitnan');
        end
        if isnan(l2) || l2 < 0
            l2 = 0.01;  % Final safeguard
        end
    end
    
    function plotGlobalCamp(globalBounds, globalCurve1, globalCurve2, global_mod, global_obs, global_binEdges, t, resultsDir)
        % Plots the global CAMP ramp curves with 1:1 line on lambda1 plot.
        fCamp = figure('Visible','off');
        totalbins = length(globalBounds);
        colors = lines(totalbins);

        subplot(2,1,1); % Lambda1 plot
        hold on;
        for i = 1:totalbins
            if ~isempty(global_binEdges) && numel(global_binEdges) >= i+1 % Check edges validity
                if i < totalbins
                    idx = global_mod >= global_binEdges(i) & global_mod < global_binEdges(i+1);
                else
                    idx = global_mod >= global_binEdges(i) & global_mod <= global_binEdges(i+1);
                end
                plot(global_mod(idx), global_obs(idx), '.', 'Color', colors(i,:));
            end
        end
        hCurve = plot(globalBounds, globalCurve1, '-pk', 'LineWidth',1.5, 'MarkerFaceColor','k');
        xlabel('Model Value'); ylabel('Obs Value');
        title(sprintf('Global CAMP Curve (λ₁) at Time %d', t));

        ax = gca;
        all_vals = [global_mod(:); global_obs(:); globalBounds(:); globalCurve1(:)]; % Collect all values
        finite_vals = all_vals(isfinite(all_vals)); % Use only finite values
        if ~isempty(finite_vals)
            lims = [min(finite_vals) max(finite_vals)];
            plot(ax, lims, lims, 'k--');
            axis(ax, [lims lims]); % Set axis limits
        else
             plot(ax, [0 1], [0 1], 'k--'); % Default if no finite values
        end
         uistack(hCurve, 'top');
        hold off;


        subplot(2,1,2); % Lambda2 plot
        hold on;
         for i = 1:totalbins
             if ~isempty(global_binEdges) && numel(global_binEdges) >= i+1 % Check edges validity
                 if i < totalbins
                     idx = global_mod >= global_binEdges(i) & global_mod < global_binEdges(i+1);
                 else
                     idx = global_mod >= global_binEdges(i) & global_mod <= global_binEdges(i+1);
                 end
                 % Optional: plot(global_mod(idx), global_obs(idx), '.', 'Color', colors(i,:));
             end
         end
        plot(globalBounds, globalCurve2, '-ok', 'LineWidth',1.5, 'MarkerFaceColor','k');
        xlabel('Model Value'); ylabel('Obs Value Variance');
        title(sprintf('Global CAMP Curve (λ₂) at Time %d', t));
        hold off;

        saveas(fCamp, fullfile(resultsDir, sprintf('AAcampPlot_time_%d.png', t)));
        close(fCamp);
    end

    function plotLocalData(gridloc, pairs_obs, pairs_mod, decileBounds, curve1, curve2, binEdges, currentMod, l1, l2, p, t, resultsDir, totalbins)
        % Creates detailed plots using provided data pairs, adds 1:1 line.
        fPlot = figure('Visible','off');
        subplot(2,1,1); % Lambda1 plot
        colors = lines(totalbins);
        hold on;
        for i = 1:totalbins
             if ~isempty(binEdges) && numel(binEdges) >= i+1 % Check edges validity
                 if i < totalbins
                    idx = pairs_mod >= binEdges(i) & pairs_mod < binEdges(i+1);
                 else
                    idx = pairs_mod >= binEdges(i) & pairs_mod <= binEdges(i+1);
                 end
                 plot(pairs_mod(idx), pairs_obs(idx), '.', 'Color', colors(i,:));
            end
        end
        hCurve = plot(decileBounds, curve1, '-pk', 'LineWidth',1.5, 'MarkerFaceColor','k');
        hPoint = plot(currentMod, l1, 'sr', 'MarkerSize',8, 'MarkerFaceColor','r');
        xlabel('Model Value'); ylabel('Obs Value');
        title(sprintf('λ₁ Correction (Model %d, Month %d)', p, t));

        ax = gca;
        all_vals = [pairs_mod(:); pairs_obs(:); decileBounds(:); curve1(:); currentMod; l1];
        finite_vals = all_vals(isfinite(all_vals));
         if ~isempty(finite_vals)
            lims = [min(finite_vals) max(finite_vals)];
            plot(ax, lims, lims, 'k--');
            axis(ax, [lims lims]); % Set axis limits
        else
             plot(ax, [0 1], [0 1], 'k--'); % Default
        end
         uistack(hCurve, 'top');
         uistack(hPoint, 'top');
        hold off;


        subplot(2,1,2); % Lambda2 plot
        hold on;
        for i = 1:totalbins
             if ~isnan(decileBounds(i)) && ~isnan(curve2(i))
                 plot(decileBounds(i), curve2(i), 'o', 'MarkerSize',8, 'Color', colors(i,:));
             end
        end
        plot(currentMod, l2, 'sr', 'MarkerSize',8, 'MarkerFaceColor','r');
        xlabel('Model Value'); ylabel('Obs Value Variance');
        title(sprintf('λ₂ Correction (Model %d, Month %d)', p, t));
        hold off;

        saveas(fPlot, fullfile(resultsDir, sprintf('AAlocalPlot_model_%d_month_%d.png', p, t)));
        close(fPlot);
    end

    function plotTechniqueMap(sMS, techniqueVals, t, resultsDir)
        % Plots a spatial map with technique coloring and descriptive colorbar.
        fMap = figure('Visible','off');
        scatter(sMS(:,1), sMS(:,2), 36, techniqueVals, 'filled'); % Use filled markers
        colorbar;
        maxTech = max(techniqueVals(:));
        if isempty(maxTech) || maxTech == 0 || isnan(maxTech)
             maxTech = 1; % Default if no points or only zeros/NaNs
        end
        maxValForCaxis = ceil(maxTech) + 1; % Ensure CAMP category fits
        % Create ticks and labels dynamically
         ticks = 1:maxValForCaxis;
         labels = cell(1, length(ticks));
         labels{1} = 'Local';
         if maxValForCaxis > 2 % If there's room for adjusted labels
            for k = 2:(maxValForCaxis - 1)
                labels{k} = sprintf('Adj %d', k-1);
            end
         end
         if length(labels) >= maxValForCaxis % Ensure index exists
             labels{maxValForCaxis} = 'CAMP';
         end

         % Use a colormap with enough distinct colors
         cmap = jet(length(ticks)); % Or parula, etc.
         colormap(cmap);

        hcb = colorbar('Ticks', ticks + 0.5*(ticks(2)-ticks(1)), 'TickLabels', labels,'Limits',[1 maxValForCaxis+1]); % Center labels

        caxis([1 maxValForCaxis + 1]); % Set limits to show all categories

        title(sprintf('Technique Map at Month %d', t));
        xlabel('Longitude'); ylabel('Latitude');
        saveas(fMap, fullfile(resultsDir, sprintf('AAtechniqueMap_month_%d.png', t)));
        close(fMap);
    end

    % Helper: Enforce Monotonicity (assuming this is available as a separate file or defined here)
    function monotonic_lambda = enforce_monotonicity(lambda)
         % Check if input lambda is empty or all NaN
         if isempty(lambda) || all(isnan(lambda(:))) % Check all elements if multi-dim
             monotonic_lambda = lambda; % Return as is
             return;
         end

        monotonic_lambda = lambda;
        totalbins_local = length(lambda);
        middle_bin = floor(totalbins_local / 2);

        % Find the first non-NaN value to use as a reference if the mean is NaN
         first_valid_idx = find(~isnan(lambda), 1, 'first');
         if isempty(first_valid_idx)
             % All are NaN, return original
             return;
         end
         mean_val = mean(lambda, 'omitnan');
         if isnan(mean_val) % Use first valid value if mean is NaN
              mean_val = lambda(first_valid_idx);
         end


        % Adjust from middle to left
        for binIN = middle_bin:-1:1
             if isnan(monotonic_lambda(binIN))
                 continue;
            end
            if binIN == middle_bin
                 if monotonic_lambda(binIN) > mean_val
                    monotonic_lambda(binIN) = mean_val;
                 end
            else
                % Find next non-NaN value to the right
                 next_val = NaN;
                 for k = (binIN + 1):totalbins_local
                     if ~isnan(monotonic_lambda(k))
                         next_val = monotonic_lambda(k);
                         break;
                     end
                 end
                 if ~isnan(next_val) && monotonic_lambda(binIN) > next_val
                     monotonic_lambda(binIN) = next_val;
                 end
            end
        end

        % Adjust from middle+1 to right
        for binIN = (middle_bin+1):totalbins_local
             if isnan(monotonic_lambda(binIN))
                  continue;
             end
            if binIN == (middle_bin+1)
                 if monotonic_lambda(binIN) < mean_val
                     monotonic_lambda(binIN) = mean_val;
                 end
            else
                 % Find previous non-NaN value to the left
                  prev_val = NaN;
                  for k = (binIN - 1):-1:1
                      if ~isnan(monotonic_lambda(k))
                          prev_val = monotonic_lambda(k);
                          break;
                      end
                  end
                  if ~isnan(prev_val) && monotonic_lambda(binIN) < prev_val
                     monotonic_lambda(binIN) = prev_val;
                  end
            end
        end
    end